-- 0102 setup: default Role Profiles (docs/modules/00-setup.md §2.7).
-- ERPNext source: erpnext/setup/install.py (DEFAULT_ROLE_PROFILES, create_default_role_profiles).
-- The per-org `role_profile` table and the trigger that copies a profile's roles onto `org_members` live in 0002.

create table if not exists public.role_profile_template (
  name  text primary key,
  roles text[] not null default '{}'
);

alter table public.role_profile_template enable row level security;
alter table public.role_profile_template force row level security;

drop policy if exists role_profile_template_select on public.role_profile_template;
create policy role_profile_template_select on public.role_profile_template for select to authenticated using (true);

insert into public.role_profile_template (name, roles) values
  ('Inventory',     '{Stock User,Stock Manager,Item Manager}'),
  ('Manufacturing', '{Stock User,Manufacturing User,Manufacturing Manager}'),
  ('Accounts',      '{Accounts User,Accounts Manager}'),
  ('Sales',         '{Sales User,Stock User,Sales Manager}'),
  ('Purchase',      '{Item Manager,Stock User,Purchase User,Purchase Manager}')
on conflict (name) do update set roles = excluded.roles;

-- Copies missing standard roles, default permissions and role profiles into one org (or all orgs when p_org is null).
-- Never overwrites rows a tenant has edited.
create or replace function app.sync_role_permissions(p_org uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.roles (org_id, name, is_standard)
  select o.id, rt.name, true
  from public.organizations o cross join public.role_template rt
  where p_org is null or o.id = p_org
  on conflict (org_id, name) do nothing;

  insert into public.role_permissions (org_id, role, doctype, can_read, can_write, can_create, can_submit,
                                       can_cancel, can_amend, can_delete, can_report, can_export, if_owner)
  select o.id, t.role, t.doctype, t.can_read, t.can_write, t.can_create, t.can_submit,
         t.can_cancel, t.can_amend, t.can_delete, t.can_report, t.can_export, t.if_owner
  from public.organizations o cross join public.role_permission_template t
  where p_org is null or o.id = p_org
  on conflict (org_id, role, doctype) do nothing;

  insert into public.role_profile (org_id, name, roles)
  select o.id, t.name, t.roles
  from public.organizations o cross join public.role_profile_template t
  where p_org is null or o.id = p_org
  on conflict (org_id, name) do nothing;
$$;

revoke execute on function app.sync_role_permissions(uuid) from public, anon, authenticated;

select app.sync_role_permissions();
