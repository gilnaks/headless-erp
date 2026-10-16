-- 0202 stock: Brand (docs/modules/04-stock.md §2.4).
-- ERPNext: erpnext/setup/doctype/brand/brand.json.
-- brand_defaults lands with Item Default, once Account and Warehouse exist.
-- System Manager read is added because every tenant doctype grants it. The JSON omits
-- that role and lists Website Manager select, which is not seeded.

create table if not exists public.brand (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations (id) on delete cascade,
  brand       text not null check (length(trim(brand)) > 0),
  description text,
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid(),
  updated_at  timestamptz not null default now(),
  updated_by  uuid,
  unique (org_id, id)
);

create unique index if not exists brand_name_uniq on public.brand (org_id, lower(brand));

create or replace function app.brand_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.brand := trim(new.brand);
  return new;
end;
$$;

revoke execute on function app.brand_validate() from public, anon, authenticated;

drop trigger if exists brand_validate on public.brand;
create trigger brand_validate before insert or update on public.brand
  for each row execute function app.brand_validate();
drop trigger if exists touch_updated on public.brand;
create trigger touch_updated before update on public.brand
  for each row execute function app.touch_updated();

alter table public.brand enable row level security;
alter table public.brand force row level security;
drop policy if exists brand_select on public.brand;
create policy brand_select on public.brand for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Brand', 'read'))::uuid[]));
drop policy if exists brand_insert on public.brand;
create policy brand_insert on public.brand for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Brand', 'create'))::uuid[]));
drop policy if exists brand_update on public.brand;
create policy brand_update on public.brand for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Brand', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Brand', 'write'))::uuid[]));
drop policy if exists brand_delete on public.brand;
create policy brand_delete on public.brand for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Brand', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Brand', 'brand', 'stock', 'brand')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Item Manager', 'Brand', true, true, true, true),
  ('Stock User', 'Brand', true, false, false, false),
  ('Sales User', 'Brand', true, false, false, false),
  ('Purchase User', 'Brand', true, false, false, false),
  ('Accounts User', 'Brand', true, false, false, false),
  ('System Manager', 'Brand', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
