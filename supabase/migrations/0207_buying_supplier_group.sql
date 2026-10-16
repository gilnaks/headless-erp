-- 0207 buying: Supplier Group tree (docs/modules/03-buying.md §2.2, 00-setup A9).
-- ERPNext: erpnext/setup/doctype/supplier_group/supplier_group.json.
-- Payment terms and party accounts are added when those tables exist.
-- A leaf selected on a supplier cannot become a group; that check lands with Supplier.
-- System Manager read is added because every tenant doctype grants it. The JSON omits that role.
-- Purchase Manager has rwcd because Purchase Master Manager is not seeded (03-buying §9).

create table if not exists public.supplier_group (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations (id) on delete cascade,
  supplier_group_name text not null check (length(trim(supplier_group_name)) > 0),
  parent_id           uuid,
  is_group            boolean not null default false,
  path                extensions.ltree not null,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid,
  unique (org_id, id),
  foreign key (org_id, parent_id) references public.supplier_group (org_id, id)
);

create unique index if not exists supplier_group_name_uniq on public.supplier_group (org_id, lower(supplier_group_name));
create unique index if not exists supplier_group_root_uniq on public.supplier_group (org_id) where parent_id is null;
create index if not exists supplier_group_parent_idx on public.supplier_group (org_id, parent_id);
create index if not exists supplier_group_path_idx on public.supplier_group using gist (path);

create or replace function app.supplier_group_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and old.parent_id is null then
    raise exception using errcode = 'P0001', message = 'supplier_group_root: All Supplier Groups cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.parent_id is null and new.supplier_group_name is distinct from old.supplier_group_name then
    raise exception using errcode = 'P0001', message = 'supplier_group_root: All Supplier Groups cannot be renamed';
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function app.supplier_group_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.supplier_group_name := trim(new.supplier_group_name);
  if new.parent_id is null and new.supplier_group_name <> 'All Supplier Groups' then
    select id into new.parent_id from public.supplier_group
    where org_id = new.org_id and parent_id is null;
  end if;
  return new;
end;
$$;

create or replace function app.seed_supplier_groups(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_root uuid;
begin
  insert into public.supplier_group (org_id, supplier_group_name, is_group)
  values (p_org, 'All Supplier Groups', true)
  on conflict (org_id, lower(supplier_group_name)) do nothing
  returning id into v_root;
  if v_root is null then
    select id into v_root from public.supplier_group where org_id = p_org and parent_id is null;
  end if;
  insert into public.supplier_group (org_id, supplier_group_name, is_group, parent_id)
  select p_org, n, false, v_root
  from unnest(array['Services', 'Local', 'Raw Material', 'Electrical', 'Hardware', 'Pharmaceutical', 'Distributor']) as n
  on conflict (org_id, lower(supplier_group_name)) do nothing;
end;
$$;

create or replace function app.organizations_seed_supplier_groups()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_supplier_groups(new.id);
  return null;
end;
$$;

revoke execute on function app.supplier_group_guard(), app.supplier_group_validate(), app.seed_supplier_groups(uuid),
  app.organizations_seed_supplier_groups() from public, anon, authenticated;

drop trigger if exists supplier_group_guard on public.supplier_group;
create trigger supplier_group_guard before insert or update or delete on public.supplier_group
  for each row execute function app.supplier_group_guard();
drop trigger if exists supplier_group_validate on public.supplier_group;
create trigger supplier_group_validate before insert or update on public.supplier_group
  for each row execute function app.supplier_group_validate();
drop trigger if exists tree_path on public.supplier_group;
create trigger tree_path before insert or update on public.supplier_group
  for each row execute function app.tree_maintain_path('Supplier Group');
drop trigger if exists tree_path_descendants on public.supplier_group;
create trigger tree_path_descendants after update on public.supplier_group
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.supplier_group;
create trigger touch_updated before update on public.supplier_group
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_supplier_groups on public.organizations;
create trigger organizations_seed_supplier_groups after insert on public.organizations
  for each row execute function app.organizations_seed_supplier_groups();

select app.seed_supplier_groups(o.id) from public.organizations o;

alter table public.supplier_group enable row level security;
alter table public.supplier_group force row level security;
drop policy if exists supplier_group_select on public.supplier_group;
create policy supplier_group_select on public.supplier_group for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier Group', 'read'))::uuid[]));
drop policy if exists supplier_group_insert on public.supplier_group;
create policy supplier_group_insert on public.supplier_group for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Supplier Group', 'create'))::uuid[]));
drop policy if exists supplier_group_update on public.supplier_group;
create policy supplier_group_update on public.supplier_group for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Supplier Group', 'write'))::uuid[]));
drop policy if exists supplier_group_delete on public.supplier_group;
create policy supplier_group_delete on public.supplier_group for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier Group', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Supplier Group', 'supplier_group', 'buying', true, 'supplier_group_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Purchase Manager', 'Supplier Group', true, true, true, true),
  ('Purchase User', 'Supplier Group', true, false, false, false),
  ('Accounts User', 'Supplier Group', true, false, false, false),
  ('System Manager', 'Supplier Group', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
