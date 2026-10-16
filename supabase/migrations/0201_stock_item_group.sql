-- 0201 stock: Item Group tree (docs/modules/04-stock.md §2.1, 00-setup A5).
-- ERPNext: erpnext/setup/doctype/item_group/item_group.json.
-- Defaults and item-tax rows wait for Account and Item Tax Template.
-- A leaf that an item uses cannot become a group; that check lands with Item.
-- System Manager read is added because every tenant doctype grants it. The JSON omits
-- that role and lists Desk User select, which is not seeded.

create table if not exists public.item_group (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  item_group_name  text not null check (length(trim(item_group_name)) > 0),
  parent_id        uuid,
  is_group         boolean not null default false,
  path             extensions.ltree not null,
  created_at       timestamptz not null default now(),
  created_by       uuid default auth.uid(),
  updated_at       timestamptz not null default now(),
  updated_by       uuid,
  unique (org_id, id),
  foreign key (org_id, parent_id) references public.item_group (org_id, id)
);

create unique index if not exists item_group_name_uniq on public.item_group (org_id, lower(item_group_name));
create unique index if not exists item_group_root_uniq on public.item_group (org_id) where parent_id is null;
create index if not exists item_group_parent_idx on public.item_group (org_id, parent_id);
create index if not exists item_group_path_idx on public.item_group using gist (path);

create or replace function app.item_group_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and old.parent_id is null then
    raise exception using errcode = 'P0001', message = 'item_group_root: All Item Groups cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.parent_id is null and new.item_group_name is distinct from old.item_group_name then
    raise exception using errcode = 'P0001', message = 'item_group_root: All Item Groups cannot be renamed';
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function app.item_group_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.item_group_name := trim(new.item_group_name);
  if new.parent_id is null and new.item_group_name <> 'All Item Groups' then
    select id into new.parent_id from public.item_group
    where org_id = new.org_id and parent_id is null;
  end if;
  return new;
end;
$$;

create or replace function app.seed_item_groups(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_root uuid;
begin
  insert into public.item_group (org_id, item_group_name, is_group)
  values (p_org, 'All Item Groups', true)
  on conflict (org_id, lower(item_group_name)) do nothing
  returning id into v_root;
  if v_root is null then
    select id into v_root from public.item_group where org_id = p_org and parent_id is null;
  end if;
  insert into public.item_group (org_id, item_group_name, is_group, parent_id)
  select p_org, n, false, v_root
  from unnest(array['Products', 'Raw Material', 'Services', 'Sub Assemblies', 'Consumable']) as n
  on conflict (org_id, lower(item_group_name)) do nothing;
end;
$$;

create or replace function app.organizations_seed_item_groups()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_item_groups(new.id);
  return null;
end;
$$;

revoke execute on function app.item_group_guard(), app.item_group_validate(), app.seed_item_groups(uuid),
  app.organizations_seed_item_groups() from public, anon, authenticated;

drop trigger if exists item_group_guard on public.item_group;
create trigger item_group_guard before insert or update or delete on public.item_group
  for each row execute function app.item_group_guard();
drop trigger if exists item_group_validate on public.item_group;
create trigger item_group_validate before insert or update on public.item_group
  for each row execute function app.item_group_validate();
drop trigger if exists tree_path on public.item_group;
create trigger tree_path before insert or update on public.item_group
  for each row execute function app.tree_maintain_path('Item Group');
drop trigger if exists tree_path_descendants on public.item_group;
create trigger tree_path_descendants after update on public.item_group
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.item_group;
create trigger touch_updated before update on public.item_group
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_item_groups on public.organizations;
create trigger organizations_seed_item_groups after insert on public.organizations
  for each row execute function app.organizations_seed_item_groups();

select app.seed_item_groups(o.id) from public.organizations o;

alter table public.item_group enable row level security;
alter table public.item_group force row level security;
drop policy if exists item_group_select on public.item_group;
create policy item_group_select on public.item_group for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Group', 'read'))::uuid[]));
drop policy if exists item_group_insert on public.item_group;
create policy item_group_insert on public.item_group for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item Group', 'create'))::uuid[]));
drop policy if exists item_group_update on public.item_group;
create policy item_group_update on public.item_group for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]));
drop policy if exists item_group_delete on public.item_group;
create policy item_group_delete on public.item_group for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Group', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Item Group', 'item_group', 'stock', true, 'item_group_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Item Manager', 'Item Group', true, true, true, true),
  ('Stock User', 'Item Group', true, false, false, false),
  ('Stock Manager', 'Item Group', true, false, false, false),
  ('Sales User', 'Item Group', true, false, false, false),
  ('Purchase User', 'Item Group', true, false, false, false),
  ('Accounts User', 'Item Group', true, false, false, false),
  ('System Manager', 'Item Group', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
