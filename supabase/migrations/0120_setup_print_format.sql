-- 0120 setup: Print Format registry -> public.print_format (docs/modules/00-setup.md §2.12).
-- ERPNext source: erpnext/setup/install.py (set_default_print_formats: one default format per doctype).
-- Frappe source (ported from memory, the frappe repo is not cloned): frappe/printing/doctype/print_format
-- (doc_type, standard, default_print_format per DocType, disabled).
-- Deviations: formats are server-rendered templates picked by `template_key` (src/print/registry.ts); no Print Format
-- Builder, Jinja/HTML/CSS or raw printing. Every printable doctype gets "<Doctype> Standard" (the generic `record`
-- template) per organization, seeded as the default.

create table if not exists public.print_format (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  name         text not null check (length(trim(name)) > 0),
  doc_type     text not null references public.doctype_meta (doctype) on update cascade on delete cascade,
  template_key text not null default 'record' check (template_key ~ '^[a-z][a-z0-9-]*$'),
  is_standard  boolean not null default false,
  is_default   boolean not null default false,
  options      jsonb not null default '{}' check (jsonb_typeof(options) = 'object'),
  disabled     boolean not null default false,
  created_at   timestamptz not null default now(),
  created_by   uuid default auth.uid(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid,
  unique (org_id, id)
);

create unique index if not exists print_format_name_uniq on public.print_format (org_id, lower(name));
create unique index if not exists print_format_default_uniq on public.print_format (org_id, doc_type) where is_default;
create index if not exists print_format_doc_type_idx on public.print_format (doc_type);

-- Doctypes that print: organization records that are neither child tables nor singles (members are printed from the
-- Users page, not as records).
create or replace function app.is_printable(p_doctype text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.doctype_meta m
      join information_schema.columns c on c.table_schema = 'public' and c.table_name = m.table_name and c.column_name = 'org_id'
     where m.doctype = p_doctype and not m.is_child and not m.is_single and m.doctype not in ('User', 'Print Format')
  );
$$;

-- Clears the previous default of the doctype (definer: independent of the caller's row visibility and of the
-- standard-format lock below).
create or replace function app.print_format_clear_default(p_org uuid, p_doc_type text, p_keep uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.print_format p set is_default = false
   where p.org_id = p_org and p.doc_type = p_doc_type and p.is_default and p.id <> p_keep
     and (auth.uid() is null or app.has_perm(p_org, 'Print Format', 'write'));
$$;

-- Frappe: standard formats are read-only except their default/disabled flags; one default per doctype
-- (DocType.default_print_format); a disabled format cannot be the default. API roles cannot create standard rows.
-- Invoker on purpose: `current_user` tells API callers from the seeding functions.
create or replace function app.print_format_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_api boolean := current_user in ('authenticated', 'anon');
begin
  new.name := trim(new.name);

  if tg_op = 'INSERT' and new.is_standard and v_api then
    raise exception 'print_format_standard: Standard Print Formats are created by the system' using errcode = 'P0001';
  end if;
  if tg_op = 'UPDATE' and v_api and (old.is_standard or new.is_standard) and (
       new.is_standard is distinct from old.is_standard or new.name is distinct from old.name
       or new.doc_type is distinct from old.doc_type or new.template_key is distinct from old.template_key
       or new.options is distinct from old.options) then
    raise exception 'print_format_standard: Standard Print Format cannot be updated; only Default and Disabled can change'
      using errcode = 'P0001';
  end if;

  if not app.is_printable(new.doc_type) then
    raise exception 'print_format_doc_type: % cannot be printed', new.doc_type using errcode = 'P0001';
  end if;

  if pg_trigger_depth() > 1 then
    return new;
  end if;

  if new.disabled and new.is_default then
    raise exception 'print_format_disabled_default: A disabled Print Format cannot be the default' using errcode = 'P0001';
  end if;
  if new.is_default then
    perform app.print_format_clear_default(new.org_id, new.doc_type, new.id);
  end if;
  return new;
end;
$$;

create or replace function app.print_format_protect_standard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.is_standard and current_user in ('authenticated', 'anon') then
    raise exception 'print_format_standard: Standard Print Format cannot be deleted' using errcode = 'P0001';
  end if;
  return old;
end;
$$;

revoke execute on function app.print_format_validate(), app.print_format_protect_standard() from public, anon, authenticated;
revoke execute on function app.is_printable(text), app.print_format_clear_default(uuid, text, uuid) from public, anon;
grant execute on function app.is_printable(text), app.print_format_clear_default(uuid, text, uuid) to authenticated;

drop trigger if exists print_format_validate on public.print_format;
create trigger print_format_validate
  before insert or update on public.print_format
  for each row execute function app.print_format_validate();

drop trigger if exists print_format_protect_standard on public.print_format;
create trigger print_format_protect_standard
  before delete on public.print_format
  for each row execute function app.print_format_protect_standard();

drop trigger if exists touch_updated on public.print_format;
create trigger touch_updated
  before update on public.print_format
  for each row execute function app.touch_updated();

------------------------------------------------------------------------------------------------------------------------
-- Standard formats (set_default_print_formats): "<Doctype> Standard", default when the doctype has none.
------------------------------------------------------------------------------------------------------------------------

create or replace function app.seed_print_formats(p_org uuid, p_doctype text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.print_format (org_id, name, doc_type, template_key, is_standard, is_default)
  select p_org, m.doctype || ' Standard', m.doctype, 'record', true,
         not exists (select 1 from public.print_format d where d.org_id = p_org and d.doc_type = m.doctype and d.is_default)
    from public.doctype_meta m
   where (p_doctype is null or m.doctype = p_doctype) and app.is_printable(m.doctype)
     and not exists (select 1 from public.print_format p where p.org_id = p_org and p.doc_type = m.doctype and p.is_standard)
  on conflict do nothing;
end;
$$;

create or replace function app.organizations_seed_print_formats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_print_formats(new.id);
  return null;
end;
$$;

-- Doctypes registered by later migrations get their standard format in every organization.
create or replace function app.doctype_meta_seed_print_formats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
begin
  for v_org in select o.id from public.organizations o loop
    perform app.seed_print_formats(v_org, new.doctype);
  end loop;
  return null;
end;
$$;

revoke execute on function app.seed_print_formats(uuid, text), app.organizations_seed_print_formats(),
  app.doctype_meta_seed_print_formats() from public, anon, authenticated;

drop trigger if exists organizations_seed_print_formats on public.organizations;
create trigger organizations_seed_print_formats
  after insert on public.organizations
  for each row execute function app.organizations_seed_print_formats();

drop trigger if exists doctype_meta_seed_print_formats on public.doctype_meta;
create trigger doctype_meta_seed_print_formats
  after insert on public.doctype_meta
  for each row execute function app.doctype_meta_seed_print_formats();

------------------------------------------------------------------------------------------------------------------------
-- RLS
------------------------------------------------------------------------------------------------------------------------

alter table public.print_format enable row level security;
alter table public.print_format force row level security;

drop policy if exists print_format_select on public.print_format;
create policy print_format_select on public.print_format for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Print Format', 'read'))::uuid[]));
drop policy if exists print_format_insert on public.print_format;
create policy print_format_insert on public.print_format for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Print Format', 'create'))::uuid[]));
drop policy if exists print_format_update on public.print_format;
create policy print_format_update on public.print_format for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Print Format', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Print Format', 'write'))::uuid[]));
drop policy if exists print_format_delete on public.print_format;
create policy print_format_delete on public.print_format for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Print Format', 'delete'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry, permissions (Frappe print_format.json: System Manager rwcd, every role reads), backfill
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Print Format', 'print_format', 'setup', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
select r.name, 'Print Format', true, r.name = 'System Manager', r.name = 'System Manager', r.name = 'System Manager'
  from public.role_template r
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

select app.seed_print_formats(o.id) from public.organizations o;
