-- 0242 framework: submit, cancel, and amend (docs/architecture/03-posting-engine.md).
-- Authorization is app.has_perm. A doctype hooks in with app.on_submit__<table>(uuid) and
-- app.on_cancel__<table>(uuid). Ledger reversal runs only when app.reverse_gl_entries exists.

create or replace function app.submit_doc(p_doctype text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_org uuid;
  v_status int;
  v_name text;
  v_company uuid;
  v_posting date;
  v_series text;
  v_hook text;
begin
  if p_id is null then
    raise exception using errcode = 'P0001', message = 'not_found: document id is required';
  end if;
  select * into v_meta from public.doctype_meta where doctype = p_doctype and not is_child;
  if not found or not v_meta.is_submittable then
    raise exception using errcode = 'P0001', message = format('not_submittable: %s cannot be submitted', coalesce(p_doctype, 'null'));
  end if;

  execute format('select org_id, docstatus, name from public.%I where id = $1', v_meta.table_name)
    into v_org, v_status, v_name using p_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = format('not_found: %s not found', p_doctype);
  end if;
  if not app.has_perm(v_org, p_doctype, 'submit') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if v_status <> 0 then
    raise exception using errcode = 'P0001', message = format('not_draft: %s is not a draft', p_doctype);
  end if;

  if v_name like 'DRAFT-%' and exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = v_meta.table_name and column_name = 'naming_series'
  ) then
    execute format('select company_id, posting_date, naming_series from public.%I where id = $1', v_meta.table_name)
      into v_company, v_posting, v_series using p_id;
    v_name := app.next_name(v_org, v_company, coalesce(nullif(v_series, ''), v_meta.naming_series_default), v_posting);
    execute format('update public.%I set name = $2 where id = $1', v_meta.table_name) using p_id, v_name;
  end if;

  v_hook := 'on_submit__' || v_meta.table_name;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'app' and p.proname = v_hook
  ) then
    execute format('select app.%I($1)', v_hook) using p_id;
  end if;

  execute format('update public.%I set docstatus = 1 where id = $1 and docstatus = 0', v_meta.table_name) using p_id;
  execute format('select name from public.%I where id = $1', v_meta.table_name) into v_name using p_id;
  return jsonb_build_object('id', p_id, 'name', v_name);
end;
$$;

create or replace function app.cancel_doc(p_doctype text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_org uuid;
  v_status int;
  v_name text;
  v_hook text;
begin
  if p_id is null then
    raise exception using errcode = 'P0001', message = 'not_found: document id is required';
  end if;
  select * into v_meta from public.doctype_meta where doctype = p_doctype and not is_child;
  if not found or not v_meta.is_submittable then
    raise exception using errcode = 'P0001', message = format('not_submittable: %s cannot be cancelled', coalesce(p_doctype, 'null'));
  end if;

  execute format('select org_id, docstatus, name from public.%I where id = $1', v_meta.table_name)
    into v_org, v_status, v_name using p_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = format('not_found: %s not found', p_doctype);
  end if;
  if not app.has_perm(v_org, p_doctype, 'cancel') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if v_status <> 1 then
    raise exception using errcode = 'P0001', message = format('not_submitted: Only a submitted %s can be cancelled', p_doctype);
  end if;

  v_hook := 'on_cancel__' || v_meta.table_name;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'app' and p.proname = v_hook
  ) then
    execute format('select app.%I($1)', v_hook) using p_id;
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'app' and p.proname = 'reverse_gl_entries'
  ) then
    execute 'select app.reverse_gl_entries($1, $2)' using p_doctype, p_id;
  end if;

  execute format('update public.%I set docstatus = 2 where id = $1', v_meta.table_name) using p_id;
  return jsonb_build_object('id', p_id, 'name', v_name);
end;
$$;

create or replace function app.amend_doc(p_doctype text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_org uuid;
  v_status int;
  v_name text;
  v_new_name text;
  v_new uuid;
  v_n int := 1;
  v_taken boolean;
  v_child public.doctype_meta;
  v_cols text;
  v_rcols text;
begin
  if p_id is null then
    raise exception using errcode = 'P0001', message = 'not_found: document id is required';
  end if;
  select * into v_meta from public.doctype_meta where doctype = p_doctype and not is_child;
  if not found or not v_meta.is_submittable then
    raise exception using errcode = 'P0001', message = format('not_submittable: %s cannot be amended', coalesce(p_doctype, 'null'));
  end if;

  execute format('select org_id, docstatus, name from public.%I where id = $1', v_meta.table_name)
    into v_org, v_status, v_name using p_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = format('not_found: %s not found', p_doctype);
  end if;
  if not app.has_perm(v_org, p_doctype, 'amend') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if v_status <> 2 then
    raise exception using errcode = 'P0001', message = format('not_cancelled: Only a cancelled %s can be amended', p_doctype);
  end if;

  loop
    v_new_name := v_name || '-' || v_n;
    execute format('select exists (select 1 from public.%I where org_id = $1 and name = $2)', v_meta.table_name)
      into v_taken using v_org, v_new_name;
    exit when not v_taken;
    v_n := v_n + 1;
    if v_n > 50 then
      raise exception using errcode = 'P0001', message = 'amend_name: could not assign a name to the amended document';
    end if;
  end loop;

  v_new := gen_random_uuid();
  execute format(
    'insert into public.%1$I
     select (jsonb_populate_record(
       null::public.%1$I,
       (to_jsonb(t) - ''id'' - ''docstatus'' - ''amended_from'' - ''created_at'' - ''created_by''
                     - ''updated_at'' - ''updated_by'')
       || jsonb_build_object(
            ''id'', $3::uuid, ''name'', $2::text, ''docstatus'', 0, ''amended_from'', $1::uuid,
            ''created_at'', now(), ''created_by'', auth.uid(), ''updated_at'', now(), ''updated_by'', auth.uid()
          )
     )).*
     from public.%1$I t where t.id = $1',
    v_meta.table_name
  ) using p_id, v_new_name, v_new;

  for v_child in
    select * from public.doctype_meta
     where is_child and parent_doctype = v_meta.doctype and child_field is not null
  loop
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('r.%I', c.column_name), ', ' order by c.ordinal_position)
      into v_cols, v_rcols
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_child.table_name
       and c.column_name <> 'id' and c.is_generated = 'NEVER';

    execute format(
      'insert into public.%1$I (%2$s)
       select %3$s
         from public.%1$I c,
              lateral jsonb_populate_record(
                null::public.%1$I,
                (to_jsonb(c) - ''id'') || jsonb_build_object(''parent_id'', $2::uuid, ''org_id'', $3::uuid)
              ) r
        where c.parent_id = $1',
      v_child.table_name, v_cols, v_rcols
    ) using p_id, v_new, v_org;
  end loop;

  execute format('select name from public.%I where id = $1', v_meta.table_name) into v_new_name using v_new;
  return jsonb_build_object('id', v_new, 'name', v_new_name);
end;
$$;

revoke all on function app.submit_doc(text, uuid) from public, anon, authenticated;
revoke all on function app.cancel_doc(text, uuid) from public, anon, authenticated;
revoke all on function app.amend_doc(text, uuid) from public, anon, authenticated;
grant execute on function app.submit_doc(text, uuid) to authenticated;
grant execute on function app.cancel_doc(text, uuid) to authenticated;
grant execute on function app.amend_doc(text, uuid) to authenticated;

create or replace function public.submit_doc(p_doctype text, p_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.submit_doc(p_doctype, p_id);
$$;

create or replace function public.cancel_doc(p_doctype text, p_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.cancel_doc(p_doctype, p_id);
$$;

create or replace function public.amend_doc(p_doctype text, p_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.amend_doc(p_doctype, p_id);
$$;

revoke all on function public.submit_doc(text, uuid) from public, anon, authenticated;
revoke all on function public.cancel_doc(text, uuid) from public, anon, authenticated;
revoke all on function public.amend_doc(text, uuid) from public, anon, authenticated;
grant execute on function public.submit_doc(text, uuid) to authenticated;
grant execute on function public.cancel_doc(text, uuid) to authenticated;
grant execute on function public.amend_doc(text, uuid) to authenticated;
