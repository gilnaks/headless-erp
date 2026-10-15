-- 0200 stock: UOM, UOM Category, UOM Conversion Factor (docs/modules/04-stock.md §2.3, 00-setup A19).
-- ERPNext sources: erpnext/setup/doctype/uom/uom.json,
-- erpnext/stock/doctype/uom_category/uom_category.json,
-- erpnext/setup/doctype/uom_conversion_factor/uom_conversion_factor.json,
-- erpnext/setup/setup_wizard/data/uom_data.json.
-- System Manager read is added on UOM and UOM Category (their JSON omits that role;
-- Desk User select is not seeded). Conversion Factor keeps System Manager rwcd from its JSON.
-- Curated subset by default; public.import_uoms copies the rest of the global templates.

create table if not exists public.uom_category (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations (id) on delete cascade,
  category_name text not null check (length(trim(category_name)) > 0),
  created_at    timestamptz not null default now(),
  created_by    uuid default auth.uid(),
  updated_at    timestamptz not null default now(),
  updated_by    uuid,
  unique (org_id, id)
);

create unique index if not exists uom_category_name_uniq on public.uom_category (org_id, lower(category_name));

create table if not exists public.uom (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references public.organizations (id) on delete cascade,
  uom_name             text not null check (length(trim(uom_name)) > 0),
  must_be_whole_number boolean not null default false,
  enabled              boolean not null default true,
  symbol               text,
  common_code          text,
  description          text,
  category_id          uuid,
  created_at           timestamptz not null default now(),
  created_by           uuid default auth.uid(),
  updated_at           timestamptz not null default now(),
  updated_by           uuid,
  unique (org_id, id),
  foreign key (org_id, category_id) references public.uom_category (org_id, id)
);

create unique index if not exists uom_name_uniq on public.uom (org_id, lower(uom_name));

create table if not exists public.uom_conversion_factor (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  category   text,
  from_uom   text not null,
  to_uom     text not null,
  value      numeric(21,9) not null,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (org_id, id),
  unique (org_id, from_uom, to_uom)
);

create or replace function app.uom_names_curated()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array[
    'Nos', 'Unit', 'Box', 'Kg', 'Gram', 'Litre', 'Meter', 'Hour', 'Day', 'Set', 'Pair', 'Dozen',
    'Millilitre', 'Centimeter', 'Millimeter', 'Minute', 'Week', 'Tonne', 'Pound', 'Square Meter', 'Cubic Meter'
  ];
$$;

create or replace function app.uom_category_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.category_name := trim(new.category_name);
  return new;
end;
$$;

create or replace function app.uom_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.uom_name := trim(new.uom_name);
  return new;
end;
$$;

-- p_all copies every template row. Otherwise only the curated subset (A19).
create or replace function app.copy_uoms(p_org uuid, p_all boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_names text[];
begin
  if p_all then
    select array_agg(uom_name) into v_names from public.uom_template;
  else
    v_names := app.uom_names_curated();
  end if;

  insert into public.uom_category (org_id, category_name)
  select distinct p_org, t.category
  from public.uom_template t
  where t.uom_name = any (v_names) and t.category is not null
  on conflict (org_id, lower(category_name)) do nothing;

  insert into public.uom (org_id, uom_name, must_be_whole_number, category_id)
  select p_org, t.uom_name, t.must_be_whole_number, c.id
  from public.uom_template t
  left join public.uom_category c on c.org_id = p_org and lower(c.category_name) = lower(t.category)
  where t.uom_name = any (v_names)
  on conflict (org_id, lower(uom_name)) do nothing;

  insert into public.uom_conversion_factor (org_id, category, from_uom, to_uom, value)
  select p_org, c.category, c.from_uom, c.to_uom, c.value
  from public.uom_conversion_template c
  where exists (select 1 from public.uom u where u.org_id = p_org and u.uom_name = c.from_uom)
    and exists (select 1 from public.uom u where u.org_id = p_org and u.uom_name = c.to_uom)
  on conflict (org_id, from_uom, to_uom) do nothing;
end;
$$;

create or replace function app.seed_uoms(p_org uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select app.copy_uoms(p_org, false);
$$;

create or replace function app.import_uoms(p_org uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app.has_perm(p_org, 'UOM', 'create') then
    raise exception using errcode = '42501', message = 'not_permitted: UOM create';
  end if;
  perform app.copy_uoms(p_org, true);
  return (select count(*)::int from public.uom where org_id = p_org);
end;
$$;

create or replace function app.organizations_seed_uoms()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_uoms(new.id);
  return null;
end;
$$;

revoke execute on function
  app.uom_names_curated(), app.uom_category_validate(), app.uom_validate(),
  app.copy_uoms(uuid, boolean), app.seed_uoms(uuid), app.import_uoms(uuid), app.organizations_seed_uoms()
from public, anon, authenticated;

drop trigger if exists uom_category_validate on public.uom_category;
create trigger uom_category_validate before insert or update on public.uom_category
  for each row execute function app.uom_category_validate();
drop trigger if exists touch_updated on public.uom_category;
create trigger touch_updated before update on public.uom_category
  for each row execute function app.touch_updated();

drop trigger if exists uom_validate on public.uom;
create trigger uom_validate before insert or update on public.uom
  for each row execute function app.uom_validate();
drop trigger if exists touch_updated on public.uom;
create trigger touch_updated before update on public.uom
  for each row execute function app.touch_updated();

drop trigger if exists touch_updated on public.uom_conversion_factor;
create trigger touch_updated before update on public.uom_conversion_factor
  for each row execute function app.touch_updated();

drop trigger if exists organizations_seed_uoms on public.organizations;
create trigger organizations_seed_uoms after insert on public.organizations
  for each row execute function app.organizations_seed_uoms();

select app.seed_uoms(o.id) from public.organizations o;

alter table public.uom_category enable row level security;
alter table public.uom_category force row level security;
alter table public.uom enable row level security;
alter table public.uom force row level security;
alter table public.uom_conversion_factor enable row level security;
alter table public.uom_conversion_factor force row level security;

drop policy if exists uom_category_select on public.uom_category;
create policy uom_category_select on public.uom_category for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM Category', 'read'))::uuid[]));
drop policy if exists uom_category_insert on public.uom_category;
create policy uom_category_insert on public.uom_category for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('UOM Category', 'create'))::uuid[]));
drop policy if exists uom_category_update on public.uom_category;
create policy uom_category_update on public.uom_category for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM Category', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('UOM Category', 'write'))::uuid[]));
drop policy if exists uom_category_delete on public.uom_category;
create policy uom_category_delete on public.uom_category for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM Category', 'delete'))::uuid[]));

drop policy if exists uom_select on public.uom;
create policy uom_select on public.uom for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM', 'read'))::uuid[]));
drop policy if exists uom_insert on public.uom;
create policy uom_insert on public.uom for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('UOM', 'create'))::uuid[]));
drop policy if exists uom_update on public.uom;
create policy uom_update on public.uom for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('UOM', 'write'))::uuid[]));
drop policy if exists uom_delete on public.uom;
create policy uom_delete on public.uom for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM', 'delete'))::uuid[]));

drop policy if exists uom_conversion_factor_select on public.uom_conversion_factor;
create policy uom_conversion_factor_select on public.uom_conversion_factor for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM Conversion Factor', 'read'))::uuid[]));
drop policy if exists uom_conversion_factor_insert on public.uom_conversion_factor;
create policy uom_conversion_factor_insert on public.uom_conversion_factor for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('UOM Conversion Factor', 'create'))::uuid[]));
drop policy if exists uom_conversion_factor_update on public.uom_conversion_factor;
create policy uom_conversion_factor_update on public.uom_conversion_factor for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM Conversion Factor', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('UOM Conversion Factor', 'write'))::uuid[]));
drop policy if exists uom_conversion_factor_delete on public.uom_conversion_factor;
create policy uom_conversion_factor_delete on public.uom_conversion_factor for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('UOM Conversion Factor', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('UOM Category', 'uom_category', 'stock', 'category_name'),
       ('UOM', 'uom', 'stock', 'uom_name'),
       ('UOM Conversion Factor', 'uom_conversion_factor', 'stock', 'from_uom')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Item Manager', 'UOM', true, true, true, true),
  ('Stock Manager', 'UOM', true, false, false, false),
  ('Stock User', 'UOM', true, false, false, false),
  ('Sales User', 'UOM', true, false, false, false),
  ('Sales Manager', 'UOM', true, false, false, false),
  ('System Manager', 'UOM', true, false, false, false),
  ('Item Manager', 'UOM Category', true, true, true, true),
  ('Stock Manager', 'UOM Category', true, false, false, false),
  ('Stock User', 'UOM Category', true, false, false, false),
  ('Sales User', 'UOM Category', true, false, false, false),
  ('Sales Manager', 'UOM Category', true, false, false, false),
  ('System Manager', 'UOM Category', true, false, false, false),
  ('Item Manager', 'UOM Conversion Factor', true, true, true, true),
  ('Stock Manager', 'UOM Conversion Factor', true, false, false, false),
  ('Stock User', 'UOM Conversion Factor', true, false, false, false),
  ('Sales User', 'UOM Conversion Factor', true, false, false, false),
  ('Sales Manager', 'UOM Conversion Factor', true, false, false, false),
  ('System Manager', 'UOM Conversion Factor', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

create or replace function public.import_uoms(p_org uuid)
returns integer
language sql
security invoker
set search_path = ''
as $$
  select app.import_uoms(p_org);
$$;

revoke execute on function public.import_uoms(uuid) from public, anon;
grant execute on function public.import_uoms(uuid) to authenticated;
