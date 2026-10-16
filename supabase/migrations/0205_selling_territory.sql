-- 0205 selling: Territory tree (docs/modules/02-selling.md §2.4, 00-setup A7).
-- ERPNext: erpnext/setup/doctype/territory/territory.json.
-- Target Detail rows are not built.
-- System Manager read is added because every tenant doctype grants it. The JSON omits that role.
-- Sales Manager has rwcd because Sales Master Manager is not seeded (02-selling §9).

create table if not exists public.territory (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references public.organizations (id) on delete cascade,
  territory_name       text not null check (length(trim(territory_name)) > 0),
  parent_id            uuid,
  is_group             boolean not null default false,
  territory_manager_id uuid,
  path                 extensions.ltree not null,
  created_at           timestamptz not null default now(),
  created_by           uuid default auth.uid(),
  updated_at           timestamptz not null default now(),
  updated_by           uuid,
  unique (org_id, id),
  foreign key (org_id, parent_id) references public.territory (org_id, id),
  foreign key (org_id, territory_manager_id) references public.sales_person (org_id, id)
);

create unique index if not exists territory_name_uniq on public.territory (org_id, lower(territory_name));
create unique index if not exists territory_root_uniq on public.territory (org_id) where parent_id is null;
create index if not exists territory_parent_idx on public.territory (org_id, parent_id);
create index if not exists territory_manager_idx on public.territory (org_id, territory_manager_id);
create index if not exists territory_path_idx on public.territory using gist (path);

create or replace function app.territory_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and old.parent_id is null then
    raise exception using errcode = 'P0001', message = 'territory_root: All Territories cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.parent_id is null and new.territory_name is distinct from old.territory_name then
    raise exception using errcode = 'P0001', message = 'territory_root: All Territories cannot be renamed';
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function app.territory_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.territory_name := trim(new.territory_name);
  if new.parent_id is null and new.territory_name <> 'All Territories' then
    select id into new.parent_id from public.territory
    where org_id = new.org_id and parent_id is null;
  end if;
  return new;
end;
$$;

create or replace function app.seed_territories(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_root uuid;
  v_country text;
begin
  insert into public.territory (org_id, territory_name, is_group)
  values (p_org, 'All Territories', true)
  on conflict (org_id, lower(territory_name)) do nothing
  returning id into v_root;
  if v_root is null then
    select id into v_root from public.territory where org_id = p_org and parent_id is null;
  end if;

  select replace(country, '''', '') into v_country from public.organizations where id = p_org;
  if v_country is not null and length(trim(v_country)) > 0 and lower(trim(v_country)) <> 'all territories' then
    insert into public.territory (org_id, territory_name, is_group, parent_id)
    values (p_org, trim(v_country), false, v_root)
    on conflict (org_id, lower(territory_name)) do nothing;
  end if;

  insert into public.territory (org_id, territory_name, is_group, parent_id)
  values (p_org, 'Rest Of The World', false, v_root)
  on conflict (org_id, lower(territory_name)) do nothing;
end;
$$;

create or replace function app.organizations_seed_territories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_territories(new.id);
  return null;
end;
$$;

revoke execute on function app.territory_guard(), app.territory_validate(), app.seed_territories(uuid),
  app.organizations_seed_territories() from public, anon, authenticated;

drop trigger if exists territory_guard on public.territory;
create trigger territory_guard before insert or update or delete on public.territory
  for each row execute function app.territory_guard();
drop trigger if exists territory_validate on public.territory;
create trigger territory_validate before insert or update on public.territory
  for each row execute function app.territory_validate();
drop trigger if exists tree_path on public.territory;
create trigger tree_path before insert or update on public.territory
  for each row execute function app.tree_maintain_path('Territory');
drop trigger if exists tree_path_descendants on public.territory;
create trigger tree_path_descendants after update on public.territory
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.territory;
create trigger touch_updated before update on public.territory
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_territories on public.organizations;
create trigger organizations_seed_territories after insert on public.organizations
  for each row execute function app.organizations_seed_territories();

select app.seed_territories(o.id) from public.organizations o;

alter table public.territory enable row level security;
alter table public.territory force row level security;
drop policy if exists territory_select on public.territory;
create policy territory_select on public.territory for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Territory', 'read'))::uuid[]));
drop policy if exists territory_insert on public.territory;
create policy territory_insert on public.territory for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Territory', 'create'))::uuid[]));
drop policy if exists territory_update on public.territory;
create policy territory_update on public.territory for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Territory', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Territory', 'write'))::uuid[]));
drop policy if exists territory_delete on public.territory;
create policy territory_delete on public.territory for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Territory', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Territory', 'territory', 'selling', true, 'territory_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Sales Manager', 'Territory', true, true, true, true),
  ('Sales User', 'Territory', true, false, false, false),
  ('Stock User', 'Territory', true, false, false, false),
  ('Accounts User', 'Territory', true, false, false, false),
  ('System Manager', 'Territory', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
