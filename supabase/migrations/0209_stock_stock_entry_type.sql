-- 0209 stock: Stock Entry Type (docs/modules/04-stock.md §2.7, 00-setup A6).
-- ERPNext: erpnext/stock/doctype/stock_entry_type/stock_entry_type.json, stock_entry_type.py.
-- Standard rows cannot be renamed or deleted. Extra ERPNext types stay out of the seed.
-- Purpose equals the name, so add_to_transit stays editable on the standard Material Transfer row.

create table if not exists public.stock_entry_type (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations (id) on delete cascade,
  name           text not null check (length(trim(name)) > 0),
  purpose        text not null,
  is_standard    boolean not null default false,
  add_to_transit boolean not null default false,
  created_at     timestamptz not null default now(),
  created_by     uuid default auth.uid(),
  updated_at     timestamptz not null default now(),
  updated_by     uuid,
  unique (org_id, id),
  check (purpose = name)
);

create unique index if not exists stock_entry_type_name_uniq on public.stock_entry_type (org_id, lower(name));

create or replace function app.stock_entry_type_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and old.is_standard then
    raise exception using errcode = 'P0001', message = 'stock_entry_type_standard: a standard Stock Entry Type cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.is_standard and (new.name is distinct from old.name or new.purpose is distinct from old.purpose) then
    raise exception using errcode = 'P0001', message = 'stock_entry_type_standard: a standard Stock Entry Type cannot be renamed';
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function app.stock_entry_type_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := trim(new.name);
  if new.purpose is null or length(trim(new.purpose)) = 0 then
    new.purpose := new.name;
  else
    new.purpose := trim(new.purpose);
  end if;
  if new.purpose is distinct from new.name then
    raise exception using errcode = 'P0001', message = 'stock_entry_type_purpose: Purpose must match the name';
  end if;
  return new;
end;
$$;

create or replace function app.seed_stock_entry_types(p_org uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.stock_entry_type (org_id, name, purpose, is_standard)
  select p_org, n, n, true
  from unnest(array[
    'Material Issue', 'Material Receipt', 'Material Transfer', 'Manufacture', 'Repack',
    'Material Transfer for Manufacture', 'Material Consumption for Manufacture', 'Send to Subcontractor'
  ]) as n
  on conflict (org_id, lower(name)) do nothing;
$$;

create or replace function app.organizations_seed_stock_entry_types()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_stock_entry_types(new.id);
  return null;
end;
$$;

revoke execute on function app.stock_entry_type_guard(), app.stock_entry_type_validate(),
  app.seed_stock_entry_types(uuid), app.organizations_seed_stock_entry_types()
from public, anon, authenticated;

drop trigger if exists stock_entry_type_guard on public.stock_entry_type;
create trigger stock_entry_type_guard before insert or update or delete on public.stock_entry_type
  for each row execute function app.stock_entry_type_guard();
drop trigger if exists stock_entry_type_validate on public.stock_entry_type;
create trigger stock_entry_type_validate before insert or update on public.stock_entry_type
  for each row execute function app.stock_entry_type_validate();
drop trigger if exists touch_updated on public.stock_entry_type;
create trigger touch_updated before update on public.stock_entry_type
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_stock_entry_types on public.organizations;
create trigger organizations_seed_stock_entry_types after insert on public.organizations
  for each row execute function app.organizations_seed_stock_entry_types();

select app.seed_stock_entry_types(o.id) from public.organizations o;

alter table public.stock_entry_type enable row level security;
alter table public.stock_entry_type force row level security;
drop policy if exists stock_entry_type_select on public.stock_entry_type;
create policy stock_entry_type_select on public.stock_entry_type for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry Type', 'read'))::uuid[]));
drop policy if exists stock_entry_type_insert on public.stock_entry_type;
create policy stock_entry_type_insert on public.stock_entry_type for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry Type', 'create'))::uuid[]));
drop policy if exists stock_entry_type_update on public.stock_entry_type;
create policy stock_entry_type_update on public.stock_entry_type for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry Type', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry Type', 'write'))::uuid[]));
drop policy if exists stock_entry_type_delete on public.stock_entry_type;
create policy stock_entry_type_delete on public.stock_entry_type for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry Type', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Stock Entry Type', 'stock_entry_type', 'stock', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Stock Entry Type', true, true, true, true),
  ('Stock Manager', 'Stock Entry Type', true, true, true, true),
  ('Manufacturing Manager', 'Stock Entry Type', true, true, true, true),
  ('Stock User', 'Stock Entry Type', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
