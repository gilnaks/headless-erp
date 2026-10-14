-- 0008 framework: generic document save/delete (frappe Document.save / delete_doc, default behaviour only).
-- `app.save_doc` and `app.delete_doc` are SECURITY INVOKER: the table's RLS policies (has_perm, company_allowed,
-- user permissions) authorize every write, so these functions never widen what the caller could do through
-- PostgREST. They add what PostgREST cannot: header + child rows in one transaction, system-column stripping,
-- docstatus guards (submitted rows only change `allow_on_submit` fields, cancelled rows are read-only) and
-- stable child row ids so later documents can link to them (so_detail, pr_detail, ...).
-- submit_doc / cancel_doc / amend_doc arrive with the first submittable doctype (P3).

alter table public.doctype_meta add column if not exists child_field text;

comment on column public.doctype_meta.child_field is
  'For child doctypes: key of the row array in the parent payload (ERPNext Table fieldname, e.g. items).';

create or replace function app.doc_system_columns()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array[
    'id', 'org_id', 'created_at', 'created_by', 'updated_at', 'updated_by', 'docstatus', 'path',
    'amended_from', 'submitted_at', 'submitted_by', 'cancelled_at', 'cancelled_by'
  ];
$$;

-- Writable columns of `p_table` that appear in at least one of `p_keys`.
create or replace function app.doc_writable_columns(p_table text, p_keys text[], p_exclude text[] default '{}')
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(c.column_name::text order by c.ordinal_position), '{}')
    from information_schema.columns c
   where c.table_schema = 'public'
     and c.table_name = p_table
     and c.is_generated = 'NEVER'
     and c.column_name::text <> all (app.doc_system_columns() || p_exclude)
     and c.column_name::text = any (p_keys);
$$;

-- Subset of `p` with only `p_keys`, so jsonb_populate_record never casts ignored (possibly malformed) keys.
create or replace function app.jsonb_pick(p jsonb, p_keys text[])
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) from jsonb_each(p) e where e.key = any (p_keys);
$$;

create or replace function app.save_doc_children(p_meta public.doctype_meta, p_org uuid, p_parent uuid, p_payload jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_child public.doctype_meta;
  v_rows jsonb;
  v_row jsonb;
  v_idx int;
  v_keys text[];
  v_cols text[];
  v_row_cols text[];
  v_ids uuid[];
  v_row_id uuid;
  v_found uuid;
begin
  for v_child in
    select * from public.doctype_meta
     where is_child and parent_doctype = p_meta.doctype and child_field is not null and p_payload ? child_field
  loop
    v_rows := coalesce(p_payload -> v_child.child_field, '[]'::jsonb);
    if jsonb_typeof(v_rows) <> 'array' then
      raise exception using errcode = 'P0001', message = format('invalid_child_rows: %s must be a list', v_child.child_field);
    end if;

    select coalesce(array_agg(distinct k), '{}') into v_keys
      from jsonb_array_elements(v_rows) r, jsonb_object_keys(r) k;
    v_cols := app.doc_writable_columns(v_child.table_name, v_keys, array['parent_id', 'idx']);

    select coalesce(array_agg((r ->> 'id')::uuid), '{}') into v_ids
      from jsonb_array_elements(v_rows) r
     where r ? 'id' and r ->> 'id' ~* '^[0-9a-f-]{36}$';

    execute format('delete from public.%I where parent_id = $1 and id <> all ($2)', v_child.table_name)
      using p_parent, v_ids;

    v_idx := 0;
    for v_row in select r from jsonb_array_elements(v_rows) r loop
      v_idx := v_idx + 1;
      if jsonb_typeof(v_row) <> 'object' then
        raise exception using errcode = 'P0001', message = format('invalid_child_rows: %s row %s must be an object', v_child.child_field, v_idx);
      end if;
      v_row_id := case when v_row ->> 'id' ~* '^[0-9a-f-]{36}$' then (v_row ->> 'id')::uuid end;
      -- only keys present in this row, so omitted fields keep their column defaults
      v_row_cols := array(select c from unnest(v_cols) c where v_row ? c);
      v_found := null;

      if v_row_id is not null then
        execute format(
          'update public.%1$I t set idx = $3%2$s from jsonb_populate_record(null::public.%1$I, $4) r
            where t.id = $1 and t.parent_id = $2 returning t.id',
          v_child.table_name,
          (select coalesce(string_agg(format(', %1$I = r.%1$I', c), ''), '') from unnest(v_row_cols) c)
        ) into v_found using v_row_id, p_parent, v_idx, app.jsonb_pick(v_row, v_row_cols);
      end if;

      if v_found is null then
        execute format(
          'insert into public.%1$I (org_id, parent_id, idx%2$s) select $1, $2, $3%3$s from jsonb_populate_record(null::public.%1$I, $4) r',
          v_child.table_name,
          (select coalesce(string_agg(format(', %I', c), ''), '') from unnest(v_row_cols) c),
          (select coalesce(string_agg(format(', r.%I', c), ''), '') from unnest(v_row_cols) c)
        ) using p_org, p_parent, v_idx, app.jsonb_pick(v_row, v_row_cols);
      end if;
    end loop;
  end loop;
end;
$$;

create or replace function app.save_doc(p_doctype text, p_payload jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_id uuid := case when p_payload ->> 'id' ~* '^[0-9a-f-]{36}$' then (p_payload ->> 'id')::uuid end;
  v_org uuid;
  v_docstatus smallint;
  v_exclude text[] := '{}';
  v_cols text[];
  v_locked text[];
  v_rows int;
  v_name text;
begin
  select * into v_meta from public.doctype_meta where doctype = p_doctype and not is_child;
  if not found then
    raise exception using errcode = 'P0001', message = format('doctype_unknown: %s is not a document type', coalesce(p_doctype, 'null'));
  end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception using errcode = 'P0001', message = 'invalid_payload: expected an object';
  end if;

  if v_meta.is_submittable then
    v_exclude := array['name'];
  end if;
  v_cols := app.doc_writable_columns(
    v_meta.table_name, array(select jsonb_object_keys(p_payload)),
    v_exclude || array(select child_field from public.doctype_meta where parent_doctype = v_meta.doctype and child_field is not null)
  );

  if v_id is null then
    v_org := case when p_payload ->> 'org_id' ~* '^[0-9a-f-]{36}$' then (p_payload ->> 'org_id')::uuid end;
    if v_org is null then
      raise exception using errcode = 'P0001', message = 'org_required: organization is required';
    end if;
    execute format(
      'insert into public.%1$I (org_id%2$s) select $1%3$s from jsonb_populate_record(null::public.%1$I, $2) r returning id',
      v_meta.table_name,
      (select coalesce(string_agg(format(', %I', c), ''), '') from unnest(v_cols) c),
      (select coalesce(string_agg(format(', r.%I', c), ''), '') from unnest(v_cols) c)
    ) into v_id using v_org, app.jsonb_pick(p_payload, v_cols);
    v_docstatus := 0;
  else
    execute format(
      'select org_id, %s from public.%I where id = $1',
      case when v_meta.is_submittable then 'docstatus' else '0::smallint' end, v_meta.table_name
    ) into v_org, v_docstatus using v_id;
    if v_org is null then
      raise exception using errcode = 'P0001', message = format('not_found: %s not found', p_doctype);
    end if;
    if v_docstatus = 2 then
      raise exception using errcode = 'P0001', message = format('cancelled_readonly: Cancelled %s cannot be changed', p_doctype);
    end if;

    if v_docstatus = 1 then
      -- frappe validate_update_after_submit: only allow_on_submit fields may change
      execute format(
        'select array_agg(n.key order by n.key)
           from jsonb_each(to_jsonb(jsonb_populate_record(null::public.%1$I, $2))) n
           join jsonb_each((select to_jsonb(t) from public.%1$I t where t.id = $1)) o on o.key = n.key
          where n.key = any ($3) and n.key <> all ($4) and n.value is distinct from o.value',
        v_meta.table_name
      ) into v_locked using v_id, app.jsonb_pick(p_payload, v_cols), v_cols, v_meta.allow_on_submit;
      if v_locked is not null then
        raise exception using errcode = 'P0001',
          message = format('update_after_submit: Not allowed to change %s after submission', array_to_string(v_locked, ', '));
      end if;
      v_cols := array(select c from unnest(v_cols) c where c = any (v_meta.allow_on_submit));
    end if;

    if cardinality(v_cols) > 0 then
      execute format(
        'update public.%1$I t set %2$s from jsonb_populate_record(null::public.%1$I, $2) r where t.id = $1',
        v_meta.table_name,
        (select string_agg(format('%1$I = r.%1$I', c), ', ') from unnest(v_cols) c)
      ) using v_id, app.jsonb_pick(p_payload, v_cols);
      get diagnostics v_rows = row_count;
      if v_rows = 0 then
        raise exception using errcode = '42501', message = format('permission_denied: not permitted to change this %s', p_doctype);
      end if;
    end if;
  end if;

  if v_docstatus = 0 then
    perform app.save_doc_children(v_meta, v_org, v_id, p_payload);
  end if;

  execute format('select to_jsonb(t) ->> ''name'' from public.%I t where t.id = $1', v_meta.table_name)
    into v_name using v_id;
  return jsonb_build_object('id', v_id, 'name', v_name);
end;
$$;

create or replace function app.delete_doc(p_doctype text, p_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_exists boolean;
  v_docstatus smallint;
  v_rows int;
begin
  select * into v_meta from public.doctype_meta where doctype = p_doctype and not is_child;
  if not found then
    raise exception using errcode = 'P0001', message = format('doctype_unknown: %s is not a document type', coalesce(p_doctype, 'null'));
  end if;

  execute format(
    'select true, %s from public.%I where id = $1',
    case when v_meta.is_submittable then 'docstatus' else '0::smallint' end, v_meta.table_name
  ) into v_exists, v_docstatus using p_id;
  if v_exists is null then
    raise exception using errcode = 'P0001', message = format('not_found: %s not found', p_doctype);
  end if;
  if v_docstatus <> 0 then
    raise exception using errcode = 'P0001',
      message = format('delete_submitted: Submitted or cancelled %s cannot be deleted', p_doctype);
  end if;

  execute format('delete from public.%I where id = $1', v_meta.table_name) using p_id;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception using errcode = '42501', message = format('permission_denied: not permitted to delete this %s', p_doctype);
  end if;
end;
$$;

revoke execute on function
  app.doc_system_columns(), app.doc_writable_columns(text, text[], text[]), app.jsonb_pick(jsonb, text[]),
  app.save_doc_children(public.doctype_meta, uuid, uuid, jsonb), app.save_doc(text, jsonb), app.delete_doc(text, uuid)
from public, anon, authenticated;
grant execute on function
  app.doc_system_columns(), app.doc_writable_columns(text, text[], text[]), app.jsonb_pick(jsonb, text[]),
  app.save_doc_children(public.doctype_meta, uuid, uuid, jsonb), app.save_doc(text, jsonb), app.delete_doc(text, uuid)
to authenticated;

create or replace function public.save_doc(p_doctype text, p_payload jsonb)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.save_doc(p_doctype, p_payload);
$$;

create or replace function public.delete_doc(p_doctype text, p_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.delete_doc(p_doctype, p_id);
$$;

revoke execute on function public.save_doc(text, jsonb), public.delete_doc(text, uuid) from public, anon;
grant execute on function public.save_doc(text, jsonb), public.delete_doc(text, uuid) to authenticated;
