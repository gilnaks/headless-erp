-- 0112 setup: Department -> public.department, a tree (docs/modules/00-setup.md §2.3).
-- ERPNext sources: erpnext/setup/doctype/department/department.json, department.py (autoname, validate,
-- before_rename, get_children), setup/doctype/company/company.py (create_default_departments, on_trash).

create table if not exists public.department (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations (id) on delete cascade,
  department_name text not null check (length(trim(department_name)) > 0),
  name            text not null,
  parent_id       uuid,
  company_id      uuid,
  is_group        boolean not null default false,
  disabled        boolean not null default false,
  path            extensions.ltree not null,
  created_at      timestamptz not null default now(),
  created_by      uuid default auth.uid(),
  updated_at      timestamptz not null default now(),
  updated_by      uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, parent_id) references public.department (org_id, id),
  -- company.py on_trash deletes the company's departments.
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade
);

create unique index if not exists department_root_uniq on public.department (org_id) where parent_id is null;
create index if not exists department_parent_idx on public.department (org_id, parent_id);
create index if not exists department_company_idx on public.department (org_id, company_id);
create index if not exists department_path_idx on public.department using gist (path);

-- The root ("All Departments", no company) is seeded per organization and cannot be changed or deleted through the
-- API. Security invoker: current_user tells API callers from seeds and cascades.
create or replace function app.department_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' then
    if old.parent_id is null then
      raise exception using errcode = 'P0001', message = 'department_root: The root department cannot be deleted';
    end if;
    return old;
  end if;
  if tg_op = 'INSERT' and new.company_id is null then
    raise exception using errcode = 'P0001', message = 'company_required: Company is mandatory';
  end if;
  if tg_op = 'UPDATE' and old.parent_id is null
     and (new.department_name is distinct from old.department_name or new.parent_id is not null
          or new.company_id is not null or not new.is_group or new.disabled) then
    raise exception using errcode = 'P0001', message = 'department_root: The root department cannot be changed';
  end if;
  return new;
end;
$$;

-- autoname / before_rename: "<department_name> - <abbr>" for company departments; validate: an empty parent becomes
-- the root. Security definer so the root and the company abbreviation are found regardless of user permissions.
create or replace function app.department_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_abbr text;
begin
  if tg_op = 'UPDATE' and old.parent_id is null then
    return new;
  end if;

  new.department_name := trim(new.department_name);

  if new.parent_id is null and (tg_op = 'INSERT' or old.parent_id is not null) then
    select d.id into new.parent_id from public.department d where d.org_id = new.org_id and d.parent_id is null;
  end if;

  if new.parent_id is not null and new.company_id is null then
    raise exception using errcode = 'P0001', message = 'company_required: Company is mandatory';
  end if;

  if new.company_id is null then
    new.name := new.department_name;
  else
    select c.abbr into v_abbr from public.companies c where c.id = new.company_id and c.org_id = new.org_id;
    new.name := new.department_name || ' - ' || coalesce(v_abbr, '');
  end if;
  return new;
end;
$$;

create or replace function app.seed_department_root(p_org uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select d.id into v_id from public.department d where d.org_id = p_org and d.parent_id is null;
  if v_id is null then
    insert into public.department (org_id, department_name, is_group)
    values (p_org, 'All Departments', true)
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- company.py create_default_departments.
create or replace function app.seed_departments(p_company uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_root uuid;
begin
  select c.org_id into v_org from public.companies c where c.id = p_company;
  if v_org is null then
    return;
  end if;
  v_root := app.seed_department_root(v_org);

  insert into public.department (org_id, department_name, parent_id, company_id)
  select v_org, d, v_root, p_company
    from unnest(array[
      'Accounts', 'Marketing', 'Sales', 'Purchase', 'Operations', 'Production', 'Dispatch', 'Customer Service',
      'Human Resources', 'Management', 'Quality Management', 'Research & Development', 'Legal'
    ]) with ordinality as t (d, n)
   order by n
  on conflict (org_id, name) do nothing;
end;
$$;

create or replace function app.organizations_seed_department_root()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_department_root(new.id);
  return null;
end;
$$;

create or replace function app.companies_seed_departments()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_departments(new.id);
  return null;
end;
$$;

-- Department names carry the company abbreviation; re-derive them when it changes.
create or replace function app.companies_rename_departments()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.abbr is distinct from old.abbr then
    update public.department d set name = d.name where d.company_id = new.id;
  end if;
  return null;
end;
$$;

revoke execute on function
  app.department_guard(), app.department_validate(), app.seed_department_root(uuid), app.seed_departments(uuid),
  app.organizations_seed_department_root(), app.companies_seed_departments(), app.companies_rename_departments()
from public, anon, authenticated;

-- Trigger order is alphabetical: department_guard, then department_validate sets parent_id before tree_path derives
-- the path.
drop trigger if exists department_guard on public.department;
create trigger department_guard
  before insert or update or delete on public.department
  for each row execute function app.department_guard();

drop trigger if exists department_validate on public.department;
create trigger department_validate
  before insert or update on public.department
  for each row execute function app.department_validate();

drop trigger if exists tree_path on public.department;
create trigger tree_path
  before insert or update on public.department
  for each row execute function app.tree_maintain_path('Department');

drop trigger if exists tree_path_descendants on public.department;
create trigger tree_path_descendants
  after update on public.department
  for each row execute function app.tree_update_descendants();

drop trigger if exists touch_updated on public.department;
create trigger touch_updated
  before update on public.department
  for each row execute function app.touch_updated();

drop trigger if exists organizations_seed_department_root on public.organizations;
create trigger organizations_seed_department_root
  after insert on public.organizations
  for each row execute function app.organizations_seed_department_root();

drop trigger if exists companies_seed_departments on public.companies;
create trigger companies_seed_departments
  after insert on public.companies
  for each row execute function app.companies_seed_departments();

drop trigger if exists companies_rename_departments on public.companies;
create trigger companies_rename_departments
  after update on public.companies
  for each row execute function app.companies_rename_departments();

select app.seed_department_root(o.id) from public.organizations o;
select app.seed_departments(c.id) from public.companies c;

------------------------------------------------------------------------------------------------------------------------
-- RLS
------------------------------------------------------------------------------------------------------------------------

alter table public.department enable row level security;
alter table public.department force row level security;

drop policy if exists department_select on public.department;
create policy department_select on public.department for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Department', 'read'))::uuid[]));
drop policy if exists department_insert on public.department;
create policy department_insert on public.department for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Department', 'create'))::uuid[]));
drop policy if exists department_update on public.department;
create policy department_update on public.department for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Department', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Department', 'write'))::uuid[]));
drop policy if exists department_delete on public.department;
create policy department_delete on public.department for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Department', 'delete'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (JSON: HR roles and Employee out of scope -> System Manager rwcd; Accounts User,
-- Projects Manager and Projects User read)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Department', 'department', 'setup', true, 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Department', true, true, true, true),
       ('Accounts User', 'Department', true, false, false, false),
       ('Projects Manager', 'Department', true, false, false, false),
       ('Projects User', 'Department', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
