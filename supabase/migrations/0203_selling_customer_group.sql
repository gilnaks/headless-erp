-- 0203 selling: Customer Group tree (docs/modules/02-selling.md §2.3, 00-setup A8).
-- ERPNext: erpnext/setup/doctype/customer_group/customer_group.json.
-- Price list, payment terms, party accounts and credit limits are added when those tables exist.
-- A leaf selected on a customer cannot become a group; that check lands with Customer.
-- System Manager read is added because every tenant doctype grants it. The JSON omits that role.
-- Sales Manager has rwcd because Sales Master Manager is not seeded (02-selling §9).

create table if not exists public.customer_group (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations (id) on delete cascade,
  customer_group_name text not null check (length(trim(customer_group_name)) > 0),
  parent_id           uuid,
  is_group            boolean not null default false,
  path                extensions.ltree not null,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid,
  unique (org_id, id),
  foreign key (org_id, parent_id) references public.customer_group (org_id, id)
);

create unique index if not exists customer_group_name_uniq on public.customer_group (org_id, lower(customer_group_name));
create unique index if not exists customer_group_root_uniq on public.customer_group (org_id) where parent_id is null;
create index if not exists customer_group_parent_idx on public.customer_group (org_id, parent_id);
create index if not exists customer_group_path_idx on public.customer_group using gist (path);

create or replace function app.customer_group_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and old.parent_id is null then
    raise exception using errcode = 'P0001', message = 'customer_group_root: All Customer Groups cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.parent_id is null and new.customer_group_name is distinct from old.customer_group_name then
    raise exception using errcode = 'P0001', message = 'customer_group_root: All Customer Groups cannot be renamed';
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function app.customer_group_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.customer_group_name := trim(new.customer_group_name);
  if new.parent_id is null and new.customer_group_name <> 'All Customer Groups' then
    select id into new.parent_id from public.customer_group
    where org_id = new.org_id and parent_id is null;
  end if;
  return new;
end;
$$;

create or replace function app.seed_customer_groups(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_root uuid;
begin
  insert into public.customer_group (org_id, customer_group_name, is_group)
  values (p_org, 'All Customer Groups', true)
  on conflict (org_id, lower(customer_group_name)) do nothing
  returning id into v_root;
  if v_root is null then
    select id into v_root from public.customer_group where org_id = p_org and parent_id is null;
  end if;
  insert into public.customer_group (org_id, customer_group_name, is_group, parent_id)
  select p_org, n, false, v_root
  from unnest(array['Individual', 'Commercial', 'Non Profit', 'Government']) as n
  on conflict (org_id, lower(customer_group_name)) do nothing;
end;
$$;

create or replace function app.organizations_seed_customer_groups()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_customer_groups(new.id);
  return null;
end;
$$;

revoke execute on function app.customer_group_guard(), app.customer_group_validate(), app.seed_customer_groups(uuid),
  app.organizations_seed_customer_groups() from public, anon, authenticated;

drop trigger if exists customer_group_guard on public.customer_group;
create trigger customer_group_guard before insert or update or delete on public.customer_group
  for each row execute function app.customer_group_guard();
drop trigger if exists customer_group_validate on public.customer_group;
create trigger customer_group_validate before insert or update on public.customer_group
  for each row execute function app.customer_group_validate();
drop trigger if exists tree_path on public.customer_group;
create trigger tree_path before insert or update on public.customer_group
  for each row execute function app.tree_maintain_path('Customer Group');
drop trigger if exists tree_path_descendants on public.customer_group;
create trigger tree_path_descendants after update on public.customer_group
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.customer_group;
create trigger touch_updated before update on public.customer_group
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_customer_groups on public.organizations;
create trigger organizations_seed_customer_groups after insert on public.organizations
  for each row execute function app.organizations_seed_customer_groups();

select app.seed_customer_groups(o.id) from public.organizations o;

alter table public.customer_group enable row level security;
alter table public.customer_group force row level security;
drop policy if exists customer_group_select on public.customer_group;
create policy customer_group_select on public.customer_group for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer Group', 'read'))::uuid[]));
drop policy if exists customer_group_insert on public.customer_group;
create policy customer_group_insert on public.customer_group for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Customer Group', 'create'))::uuid[]));
drop policy if exists customer_group_update on public.customer_group;
create policy customer_group_update on public.customer_group for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]));
drop policy if exists customer_group_delete on public.customer_group;
create policy customer_group_delete on public.customer_group for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer Group', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Customer Group', 'customer_group', 'selling', true, 'customer_group_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Sales Manager', 'Customer Group', true, true, true, true),
  ('Sales User', 'Customer Group', true, false, false, false),
  ('Accounts User', 'Customer Group', true, false, false, false),
  ('System Manager', 'Customer Group', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
