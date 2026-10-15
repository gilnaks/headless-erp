-- 0127 framework: HTML allow-list in Postgres, and one-round-trip link search.
-- HTML rules match src/lib/html/sanitize.ts (the cases in sanitize.test.ts are the spec).
-- search_link is security invoker so table RLS still hides other organizations' rows.
-- The doctype name is never interpolated; only doctype_meta.table_name / title_field are, and only if they are plain identifiers.

alter table public.doctype_meta add column if not exists html_columns text[] not null default '{}';

comment on column public.doctype_meta.html_columns is
  'Text columns sanitized by app.sanitize_html inside app.save_doc and by a before-write trigger.';

------------------------------------------------------------------------------------------------------------------------
-- Allow-list sanitizer
------------------------------------------------------------------------------------------------------------------------

create or replace function app.html_filter_style(p_style text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(string_agg(s.name || ':' || s.value, ';' order by s.ord), '')
  from (
    select row_number() over () as ord,
           lower(btrim(split_part(part, ':', 1))) as name,
           btrim(substr(part, position(':' in part) + 1)) as value
    from unnest(string_to_array(coalesce(p_style, ''), ';')) as part
    where position(':' in part) > 0
  ) s
  where s.name = any (array[
    'color', 'background-color', 'text-align', 'vertical-align', 'font-size', 'font-weight', 'font-style',
    'font-family', 'line-height', 'text-decoration', 'text-transform', 'letter-spacing', 'width', 'height',
    'max-width', 'min-width', 'margin', 'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
    'padding', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left', 'border', 'border-top',
    'border-right', 'border-bottom', 'border-left', 'border-collapse', 'display', 'float'
  ])
    and s.value <> ''
    and s.value !~* '(url|expression|javascript)\s*[(:]';
$$;

create or replace function app.html_attr_allowed(p_tag text, p_attr text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select lower(p_attr) = any (array['style', 'class', 'align', 'width', 'height'])
    or (p_tag = 'a' and lower(p_attr) = any (array['href', 'title', 'target', 'rel']))
    or (p_tag = 'img' and lower(p_attr) = any (array['src', 'alt', 'title']))
    or (p_tag in ('td', 'th') and lower(p_attr) = any (array['colspan', 'rowspan', 'valign']))
    or (p_tag = 'th' and lower(p_attr) = 'scope')
    or (p_tag = 'col' and lower(p_attr) = 'span');
$$;

create or replace function app.html_url_ok(p_tag text, p_attr text, p_value text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when btrim(p_value) ~ '^//' then false
    when position(':' in btrim(p_value)) = 0 then true
    when lower(split_part(btrim(p_value), ':', 1)) in ('http', 'https', 'mailto', 'tel') then true
    when p_tag = 'img' and p_attr = 'src' and lower(split_part(btrim(p_value), ':', 1)) = 'data' then true
    else false
  end;
$$;

-- Rebuild one tag. Returns the original text when every attribute is already allowed, so clean HTML is unchanged.
create or replace function app.html_clean_tag(p_raw text, p_name text, p_self boolean)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  body text;
  attr text[];
  kept text[] := '{}';
  changed boolean := false;
  aname text;
  aval text;
  filtered text;
begin
  body := regexp_replace(p_raw, '^<\s*' || p_name || '\s*', '', 'i');
  body := regexp_replace(body, '/?\s*>$', '');
  for attr in
    select regexp_matches(body, '([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s/>]+)))?', 'g')
  loop
    aname := lower(attr[1]);
    aval := coalesce(attr[2], attr[3], attr[4]);
    if aname like 'on%' or not app.html_attr_allowed(p_name, aname) then
      changed := true;
      continue;
    end if;
    if aname in ('href', 'src') and not app.html_url_ok(p_name, aname, aval) then
      changed := true;
      continue;
    end if;
    if aname = 'style' then
      filtered := app.html_filter_style(aval);
      if filtered is null then
        changed := true;
        continue;
      end if;
      if filtered is distinct from aval then
        changed := true;
      end if;
      kept := kept || format('%s="%s"', aname, replace(filtered, '"', '&quot;'));
      continue;
    end if;
    if aval is null then
      kept := kept || aname;
    else
      kept := kept || format('%s="%s"', aname, replace(aval, '"', '&quot;'));
    end if;
  end loop;
  if not changed then
    return p_raw;
  end if;
  if cardinality(kept) = 0 then
    return case when p_self then '<' || p_name || ' />' else '<' || p_name || '>' end;
  end if;
  return '<' || p_name || ' ' || array_to_string(kept, ' ') || case when p_self then ' />' else '>' end;
end;
$fn$;

create or replace function app.sanitize_html(p_html text)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  allowed text[] := array[
    'div', 'span', 'p', 'br', 'hr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'b', 'strong', 'i', 'em', 'u', 's',
    'small', 'sub', 'sup', 'blockquote', 'ul', 'ol', 'li', 'a', 'img', 'table', 'thead', 'tbody', 'tfoot',
    'tr', 'th', 'td', 'colgroup', 'col'
  ];
  void_tags text[] := array['br', 'hr', 'img', 'col'];
  i int := 1;
  n int;
  out text := '';
  rel int;
  gt int;
  raw text;
  lower_name text;
  self_close boolean;
  depth int;
  scan int;
  chunk text;
begin
  if p_html is null then
    return null;
  end if;
  n := length(p_html);
  while i <= n loop
    rel := position('<' in substr(p_html, i));
    if rel = 0 then
      out := out || substr(p_html, i);
      exit;
    end if;
    out := out || substr(p_html, i, rel - 1);
    i := i + rel - 1;
    if substr(p_html, i, 4) = '<!--' then
      rel := position('-->' in substr(p_html, i + 4));
      if rel = 0 then
        exit;
      end if;
      i := i + 4 + rel + 2;
      continue;
    end if;
    gt := position('>' in substr(p_html, i));
    if gt = 0 then
      exit;
    end if;
    raw := substr(p_html, i, gt);
    if left(raw, 2) = '</' then
      lower_name := lower((regexp_match(raw, '^</\s*([A-Za-z0-9]+)'))[1]);
      if lower_name = any (allowed) then
        out := out || raw;
      end if;
      i := i + gt;
      continue;
    end if;
    lower_name := lower((regexp_match(raw, '^<\s*([A-Za-z0-9]+)'))[1]);
    self_close := raw ~ '/\s*>$' or lower_name = any (void_tags);
    if lower_name is null or not (lower_name = any (allowed)) then
      i := i + gt;
      if lower_name is not null and not self_close then
        depth := 1;
        while depth > 0 and i <= n loop
          rel := position('<' in substr(p_html, i));
          if rel = 0 then
            i := n + 1;
            exit;
          end if;
          i := i + rel - 1;
          gt := position('>' in substr(p_html, i));
          if gt = 0 then
            i := n + 1;
            exit;
          end if;
          chunk := lower(substr(p_html, i, gt));
          if chunk ~ ('^</\s*' || lower_name || '[\s>]') then
            depth := depth - 1;
          elsif chunk ~ ('^<\s*' || lower_name || '[\s/>]') and chunk !~ '/\s*>$' then
            depth := depth + 1;
          end if;
          i := i + gt;
        end loop;
      end if;
      continue;
    end if;
    out := out || app.html_clean_tag(raw, lower_name, self_close);
    i := i + gt;
  end loop;
  return out;
end;
$fn$;

create or replace function app.sanitize_doc_payload(p_doctype text, p_payload jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $fn$
declare
  v_cols text[];
  v_col text;
  v_child record;
  v_rows jsonb;
  v_i int;
begin
  if jsonb_typeof(p_payload) is distinct from 'object' then
    return p_payload;
  end if;
  select html_columns into v_cols from public.doctype_meta where doctype = p_doctype;
  if v_cols is not null then
    foreach v_col in array v_cols loop
      if jsonb_typeof(p_payload -> v_col) = 'string' then
        p_payload := jsonb_set(p_payload, array[v_col], to_jsonb(app.sanitize_html(p_payload ->> v_col)));
      end if;
    end loop;
  end if;
  for v_child in
    select doctype, child_field from public.doctype_meta
    where parent_doctype = p_doctype and child_field is not null and cardinality(html_columns) > 0
  loop
    if jsonb_typeof(p_payload -> v_child.child_field) = 'array' then
      v_rows := '[]'::jsonb;
      for v_i in 0 .. jsonb_array_length(p_payload -> v_child.child_field) - 1 loop
        v_rows := v_rows || jsonb_build_array(
          app.sanitize_doc_payload(v_child.doctype, (p_payload -> v_child.child_field) -> v_i)
        );
      end loop;
      p_payload := jsonb_set(p_payload, array[v_child.child_field], v_rows);
    end if;
  end loop;
  return p_payload;
end;
$fn$;

------------------------------------------------------------------------------------------------------------------------
-- save_doc sanitizes HTML columns before the write (direct rpc cannot skip this)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.save_doc(p_doctype text, p_payload jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_id uuid;
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
  p_payload := app.sanitize_doc_payload(p_doctype, p_payload);
  v_id := case when p_payload ->> 'id' ~* '^[0-9a-f-]{36}$' then (p_payload ->> 'id')::uuid end;

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

------------------------------------------------------------------------------------------------------------------------
-- Before-write triggers: a direct insert cannot store raw HTML either
------------------------------------------------------------------------------------------------------------------------

create or replace function app.sanitize_letter_head_html()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.content := app.sanitize_html(new.content);
  new.footer := app.sanitize_html(new.footer);
  return new;
end;
$$;

create or replace function app.sanitize_email_template_html()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.response_html := app.sanitize_html(new.response_html);
  return new;
end;
$$;

create or replace function app.sanitize_email_account_html()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.signature := app.sanitize_html(new.signature);
  new.footer := app.sanitize_html(new.footer);
  return new;
end;
$$;

-- Name sorts before the existing *_validate triggers, so HTML is cleaned and then trimmed.
drop trigger if exists letter_head_sanitize on public.letter_head;
create trigger letter_head_sanitize
  before insert or update on public.letter_head
  for each row execute function app.sanitize_letter_head_html();

drop trigger if exists email_template_sanitize on public.email_template;
create trigger email_template_sanitize
  before insert or update on public.email_template
  for each row execute function app.sanitize_email_template_html();

drop trigger if exists email_account_sanitize on public.email_account;
create trigger email_account_sanitize
  before insert or update on public.email_account
  for each row execute function app.sanitize_email_account_html();

update public.doctype_meta set html_columns = '{content,footer}' where doctype = 'Letter Head';
update public.doctype_meta set html_columns = '{response_html}' where doctype = 'Email Template';
update public.doctype_meta set html_columns = '{signature,footer}' where doctype = 'Email Account';

update public.letter_head set content = app.sanitize_html(content) where content is not null;
update public.letter_head set footer = app.sanitize_html(footer) where footer is not null;
update public.email_template set response_html = app.sanitize_html(response_html) where response_html is not null;
update public.email_account set signature = app.sanitize_html(signature) where signature is not null;
update public.email_account set footer = app.sanitize_html(footer) where footer is not null;

------------------------------------------------------------------------------------------------------------------------
-- Link search: one statement, RLS of the target table applies (security invoker)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.search_link(p_org uuid, p_doctype text, p_q text default '', p_ids uuid[] default '{}')
returns table (id uuid, label text)
language plpgsql
stable
security invoker
set search_path = ''
as $fn$
declare
  v_table text;
  v_title text;
  v_q text;
begin
  if p_org is null or p_doctype is null or btrim(p_doctype) = '' then
    return;
  end if;

  if p_doctype = 'User' then
    v_q := replace(replace(replace(btrim(coalesce(p_q, '')), '\', '\\'), '%', '\%'), '_', '\_');
    return query
    select picked.user_id,
           case
             when picked.full_name is not null and length(btrim(picked.full_name)) > 0
               then picked.full_name || ' (' || picked.email || ')'
             else picked.email
           end
    from (
      select d.user_id, d.email, d.full_name, 0 as ord
      from public.org_member_directory(p_org) d
      where d.user_id = any (coalesce(p_ids, '{}'))
      union all
      (
        select d.user_id, d.email, d.full_name, 1
        from public.org_member_directory(p_org) d
        where not (d.user_id = any (coalesce(p_ids, '{}')))
          and (
            d.email ilike '%' || v_q || '%' escape '\'
            or coalesce(d.full_name, '') ilike '%' || v_q || '%' escape '\'
          )
        order by 3 nulls last, 2
        limit 20
      )
    ) picked
    order by picked.ord, picked.full_name nulls last, picked.email;
    return;
  end if;

  select m.table_name, coalesce(nullif(m.title_field, ''), 'name')
    into v_table, v_title
  from public.doctype_meta m
  where m.doctype = p_doctype and not m.is_child;

  if not found or v_table !~ '^[a-z][a-z0-9_]*$' or v_title !~ '^[a-z][a-z0-9_]*$' then
    return;
  end if;

  v_q := replace(replace(replace(btrim(coalesce(p_q, '')), '\', '\\'), '%', '\%'), '_', '\_');

  return query execute format(
    $q$
      select id, label from (
        (select id, %2$I::text as label, 0 as ord
           from public.%1$I
          where org_id = $1 and id = any (coalesce($2, '{}')))
        union all
        (select id, %2$I::text, 1
           from public.%1$I
          where org_id = $1
            and not (id = any (coalesce($2, '{}')))
            and %2$I::text ilike '%%' || $3 || '%%' escape '\'
          order by 2
          limit 20)
      ) found
      order by ord, label
    $q$, v_table, v_title)
  using p_org, p_ids, v_q;
end;
$fn$;

create or replace function public.search_link(p_org uuid, p_doctype text, p_q text default '', p_ids uuid[] default '{}')
returns table (id uuid, label text)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app.search_link(p_org, p_doctype, p_q, p_ids);
$$;

create or replace function public.sanitize_html(p_html text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select app.sanitize_html(p_html);
$$;

revoke execute on function
  app.html_filter_style(text), app.html_attr_allowed(text, text), app.html_url_ok(text, text, text),
  app.html_clean_tag(text, text, boolean), app.sanitize_html(text), app.sanitize_doc_payload(text, jsonb),
  app.sanitize_letter_head_html(), app.sanitize_email_template_html(), app.sanitize_email_account_html(),
  app.search_link(uuid, text, text, uuid[])
from public, anon, authenticated;

grant execute on function
  app.html_filter_style(text), app.html_attr_allowed(text, text), app.html_url_ok(text, text, text),
  app.html_clean_tag(text, text, boolean), app.sanitize_html(text), app.sanitize_doc_payload(text, jsonb),
  app.sanitize_letter_head_html(), app.sanitize_email_template_html(), app.sanitize_email_account_html(),
  app.search_link(uuid, text, text, uuid[])
to authenticated;

revoke execute on function public.search_link(uuid, text, text, uuid[]), public.sanitize_html(text) from public, anon;
grant execute on function public.search_link(uuid, text, text, uuid[]), public.sanitize_html(text) to authenticated;
