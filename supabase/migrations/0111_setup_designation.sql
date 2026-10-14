-- 0111 setup: Designation -> public.designation (docs/modules/00-setup.md §2.4).
-- ERPNext sources: erpnext/setup/doctype/designation/designation.json (naming field:designation_name),
-- setup/setup_wizard/data/designation.txt (31 presets), setup_wizard/operations/install_fixtures.py (install).

create table if not exists public.designation (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  designation_name text not null check (length(trim(designation_name)) > 0),
  description      text,
  created_at       timestamptz not null default now(),
  created_by       uuid default auth.uid(),
  updated_at       timestamptz not null default now(),
  updated_by       uuid,
  unique (org_id, id)
);

create unique index if not exists designation_name_uniq on public.designation (org_id, lower(designation_name));

create or replace function app.designation_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.designation_name := trim(new.designation_name);
  return new;
end;
$$;

-- install_fixtures.install: the setup wizard loads designation.txt once per site; here once per organization.
create or replace function app.seed_designations(p_org uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.designation (org_id, designation_name)
  select p_org, d
    from unnest(array[
      'Accountant', 'Administrative Assistant', 'Administrative Officer', 'Analyst', 'Associate', 'Business Analyst',
      'Business Development Manager', 'Consultant', 'Chief Executive Officer', 'Chief Financial Officer',
      'Chief Operating Officer', 'Chief Technology Officer', 'Customer Service Representative', 'Designer', 'Engineer',
      'Executive Assistant', 'Finance Manager', 'HR Manager', 'Head of Marketing and Sales', 'Manager',
      'Managing Director', 'Marketing Manager', 'Marketing Specialist', 'President', 'Product Manager',
      'Project Manager', 'Researcher', 'Sales Representative', 'Secretary', 'Software Developer', 'Vice President'
    ]) as d
  on conflict (org_id, lower(designation_name)) do nothing;
$$;

create or replace function app.organizations_seed_designations()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_designations(new.id);
  return null;
end;
$$;

revoke execute on function app.designation_validate(), app.seed_designations(uuid), app.organizations_seed_designations()
from public, anon, authenticated;

drop trigger if exists designation_validate on public.designation;
create trigger designation_validate
  before insert or update on public.designation
  for each row execute function app.designation_validate();

drop trigger if exists touch_updated on public.designation;
create trigger touch_updated
  before update on public.designation
  for each row execute function app.touch_updated();

drop trigger if exists organizations_seed_designations on public.organizations;
create trigger organizations_seed_designations
  after insert on public.organizations
  for each row execute function app.organizations_seed_designations();

select app.seed_designations(o.id) from public.organizations o;

------------------------------------------------------------------------------------------------------------------------
-- RLS
------------------------------------------------------------------------------------------------------------------------

alter table public.designation enable row level security;
alter table public.designation force row level security;

drop policy if exists designation_select on public.designation;
create policy designation_select on public.designation for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Designation', 'read'))::uuid[]));
drop policy if exists designation_insert on public.designation;
create policy designation_insert on public.designation for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Designation', 'create'))::uuid[]));
drop policy if exists designation_update on public.designation;
create policy designation_update on public.designation for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Designation', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Designation', 'write'))::uuid[]));
drop policy if exists designation_delete on public.designation;
create policy designation_delete on public.designation for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Designation', 'delete'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (JSON: HR User/HR Manager out of scope -> System Manager rwcd; Sales User read)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Designation', 'designation', 'setup', 'designation_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Designation', true, true, true, true),
       ('Sales User', 'Designation', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
