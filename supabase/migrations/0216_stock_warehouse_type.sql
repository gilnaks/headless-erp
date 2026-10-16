-- 0216 stock: Warehouse Type (docs/modules/04-stock.md §2.5, 00-setup A16).
-- ERPNext: erpnext/stock/doctype/warehouse_type, erpnext/setup/setup_wizard/operations/install_fixtures.py.

create table if not exists public.warehouse_type (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations (id) on delete cascade,
  name           text not null check (length(trim(name)) > 0),
  created_at     timestamptz not null default now(),
  created_by     uuid default auth.uid(),
  updated_at     timestamptz not null default now(),
  updated_by     uuid,
  unique (org_id, id)
);

create unique index if not exists warehouse_type_name_uniq on public.warehouse_type (org_id, lower(name));

create or replace function app.warehouse_type_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := trim(new.name);
  return new;
end;
$$;

create or replace function app.seed_warehouse_types(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.warehouse_type (org_id, name)
  values (p_org, 'Transit')
  on conflict (org_id, lower(name)) do nothing;
end;
$$;

create or replace function app.organizations_seed_warehouse_types()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_warehouse_types(new.id);
  return null;
end;
$$;

revoke execute on function
  app.warehouse_type_validate(), app.seed_warehouse_types(uuid), app.organizations_seed_warehouse_types()
from public, anon, authenticated;

drop trigger if exists warehouse_type_validate on public.warehouse_type;
create trigger warehouse_type_validate before insert or update on public.warehouse_type
  for each row execute function app.warehouse_type_validate();
drop trigger if exists touch_updated on public.warehouse_type;
create trigger touch_updated before update on public.warehouse_type
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_warehouse_types on public.organizations;
create trigger organizations_seed_warehouse_types after insert on public.organizations
  for each row execute function app.organizations_seed_warehouse_types();

select app.seed_warehouse_types(o.id) from public.organizations o;

alter table public.warehouse_type enable row level security;
alter table public.warehouse_type force row level security;

drop policy if exists warehouse_type_select on public.warehouse_type;
create policy warehouse_type_select on public.warehouse_type for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Warehouse Type', 'read'))::uuid[]));
drop policy if exists warehouse_type_insert on public.warehouse_type;
create policy warehouse_type_insert on public.warehouse_type for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Warehouse Type', 'create'))::uuid[]));
drop policy if exists warehouse_type_update on public.warehouse_type;
create policy warehouse_type_update on public.warehouse_type for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Warehouse Type', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Warehouse Type', 'write'))::uuid[]));
drop policy if exists warehouse_type_delete on public.warehouse_type;
create policy warehouse_type_delete on public.warehouse_type for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Warehouse Type', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Warehouse Type', 'warehouse_type', 'stock', 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Warehouse Type', true, false, false, false),
  ('Item Manager', 'Warehouse Type', true, true, true, true),
  ('Stock User', 'Warehouse Type', true, false, false, false),
  ('Stock Manager', 'Warehouse Type', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
