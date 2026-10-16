-- 0204 selling: Sales Person tree (docs/modules/02-selling.md §2.5, 00-setup A10).
-- ERPNext: erpnext/setup/doctype/sales_person/sales_person.json.
-- Employee is not built (HR). A disabled person cannot join a sales team; that check lands with Sales Team.
-- System Manager read is added because every tenant doctype grants it. The JSON omits that role.
-- Sales Manager has rwcd because Sales Master Manager is not seeded (02-selling §9).

create table if not exists public.sales_person (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations (id) on delete cascade,
  sales_person_name text not null check (length(trim(sales_person_name)) > 0),
  parent_id         uuid,
  is_group          boolean not null default false,
  enabled           boolean not null default true,
  commission_rate   numeric(21,9) not null default 0,
  path              extensions.ltree not null,
  created_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  updated_at        timestamptz not null default now(),
  updated_by        uuid,
  unique (org_id, id),
  foreign key (org_id, parent_id) references public.sales_person (org_id, id)
);

create unique index if not exists sales_person_name_uniq on public.sales_person (org_id, lower(sales_person_name));
create unique index if not exists sales_person_root_uniq on public.sales_person (org_id) where parent_id is null;
create index if not exists sales_person_parent_idx on public.sales_person (org_id, parent_id);
create index if not exists sales_person_path_idx on public.sales_person using gist (path);

create or replace function app.sales_person_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and old.parent_id is null then
    raise exception using errcode = 'P0001', message = 'sales_person_root: Sales Team cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.parent_id is null and new.sales_person_name is distinct from old.sales_person_name then
    raise exception using errcode = 'P0001', message = 'sales_person_root: Sales Team cannot be renamed';
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function app.sales_person_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.sales_person_name := trim(new.sales_person_name);
  if new.parent_id is null and new.sales_person_name <> 'Sales Team' then
    select id into new.parent_id from public.sales_person
    where org_id = new.org_id and parent_id is null;
  end if;
  return new;
end;
$$;

create or replace function app.seed_sales_persons(p_org uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.sales_person (org_id, sales_person_name, is_group)
  values (p_org, 'Sales Team', true)
  on conflict (org_id, lower(sales_person_name)) do nothing;
$$;

create or replace function app.organizations_seed_sales_persons()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_sales_persons(new.id);
  return null;
end;
$$;

revoke execute on function app.sales_person_guard(), app.sales_person_validate(), app.seed_sales_persons(uuid),
  app.organizations_seed_sales_persons() from public, anon, authenticated;

drop trigger if exists sales_person_guard on public.sales_person;
create trigger sales_person_guard before insert or update or delete on public.sales_person
  for each row execute function app.sales_person_guard();
drop trigger if exists sales_person_validate on public.sales_person;
create trigger sales_person_validate before insert or update on public.sales_person
  for each row execute function app.sales_person_validate();
drop trigger if exists tree_path on public.sales_person;
create trigger tree_path before insert or update on public.sales_person
  for each row execute function app.tree_maintain_path('Sales Person');
drop trigger if exists tree_path_descendants on public.sales_person;
create trigger tree_path_descendants after update on public.sales_person
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.sales_person;
create trigger touch_updated before update on public.sales_person
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_sales_persons on public.organizations;
create trigger organizations_seed_sales_persons after insert on public.organizations
  for each row execute function app.organizations_seed_sales_persons();

select app.seed_sales_persons(o.id) from public.organizations o;

alter table public.sales_person enable row level security;
alter table public.sales_person force row level security;
drop policy if exists sales_person_select on public.sales_person;
create policy sales_person_select on public.sales_person for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Person', 'read'))::uuid[]));
drop policy if exists sales_person_insert on public.sales_person;
create policy sales_person_insert on public.sales_person for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Sales Person', 'create'))::uuid[]));
drop policy if exists sales_person_update on public.sales_person;
create policy sales_person_update on public.sales_person for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Person', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Sales Person', 'write'))::uuid[]));
drop policy if exists sales_person_delete on public.sales_person;
create policy sales_person_delete on public.sales_person for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Person', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Sales Person', 'sales_person', 'selling', true, 'sales_person_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Sales Manager', 'Sales Person', true, true, true, true),
  ('Sales User', 'Sales Person', true, false, false, false),
  ('System Manager', 'Sales Person', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
