-- 0105 setup: Role and Role Profile as documents (docs/modules/00-setup.md §2.7).
-- ERPNext source: erpnext/setup/install.py (DEFAULT_ROLE_PROFILES, create_default_role_profiles, update_roles).
-- Frappe (no local clone; from memory): frappe/core/doctype/role/role.py (standard roles cannot be renamed),
-- frappe/core/doctype/role_profile/role_profile.py (on_update re-syncs users holding the profile),
-- frappe/core/doctype/user/user.py (role_profile_name repopulates roles on validate).
-- Tables, RLS and the base org_members trigger live in 0002; templates in 0004/0102.

------------------------------------------------------------------------------------------------------------------------
-- uuid ids so the generic list/form/save_doc engine can address roles and profiles (pk stays (org_id, name))
------------------------------------------------------------------------------------------------------------------------

alter table public.roles add column if not exists id uuid not null default gen_random_uuid();
alter table public.role_profile add column if not exists id uuid not null default gen_random_uuid();

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'roles_org_id_id_key') then
    alter table public.roles add constraint roles_org_id_id_key unique (org_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'role_profile_org_id_id_key') then
    alter table public.role_profile add constraint role_profile_org_id_id_key unique (org_id, id);
  end if;
end;
$$;

------------------------------------------------------------------------------------------------------------------------
-- Access doctypes: permissions fixed to System Manager (no Administrator to recover from a lockout)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.locked_permission_doctypes()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['User', 'Role', 'Role Profile', 'User Permission'];
$$;

-- Runs as the invoker: API callers (authenticated) are refused, migrations and security definer functions pass.
create or replace function app.role_permissions_locked()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_doctype text;
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  foreach v_doctype in array array[case when tg_op <> 'INSERT' then old.doctype end, case when tg_op <> 'DELETE' then new.doctype end]
  loop
    if v_doctype = any (app.locked_permission_doctypes()) then
      raise exception using errcode = 'P0001',
        message = format('permission_locked: permissions for %s are fixed to System Manager', v_doctype);
    end if;
  end loop;
  return coalesce(new, old);
end;
$$;

drop trigger if exists role_permissions_locked on public.role_permissions;
create trigger role_permissions_locked
  before insert or update or delete on public.role_permissions
  for each row execute function app.role_permissions_locked();

------------------------------------------------------------------------------------------------------------------------
-- Role guards (frappe Role: standard roles cannot be renamed; System Manager must stay usable)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.roles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_api boolean := current_user in ('authenticated', 'anon');
begin
  if tg_op = 'DELETE' then
    if v_api and old.is_standard then
      raise exception using errcode = 'P0001', message = format('role_standard: Standard role %s cannot be deleted', old.name);
    end if;
    return old;
  end if;

  if v_api then
    if tg_op = 'INSERT' then
      new.is_standard := false;
    elsif new.is_standard is distinct from old.is_standard then
      raise exception using errcode = 'P0001', message = 'role_standard: Standard flag cannot be changed';
    elsif old.is_standard and new.name is distinct from old.name then
      raise exception using errcode = 'P0001', message = format('role_standard: Standard role %s cannot be renamed', old.name);
    end if;
  end if;

  new.name := trim(new.name);
  if new.name = 'System Manager' and new.disabled then
    raise exception using errcode = 'P0001', message = 'role_protected: System Manager cannot be disabled';
  end if;
  return new;
end;
$$;

drop trigger if exists roles_guard on public.roles;
create trigger roles_guard
  before insert or update or delete on public.roles
  for each row execute function app.roles_guard();

-- Role names are also stored in text[] columns (no FK): keep them in step with renames and deletes.
-- Profiles first, so members holding a profile are re-synced from the already rewritten profile.
create or replace function app.roles_propagate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.organizations o where o.id = old.org_id) then
    return null;
  end if;

  if tg_op = 'UPDATE' then
    if new.name = old.name then
      return null;
    end if;
    update public.role_profile set roles = array_replace(roles, old.name, new.name)
      where org_id = old.org_id and old.name = any (roles);
    update public.org_members set roles = array_replace(roles, old.name, new.name)
      where org_id = old.org_id and old.name = any (roles);
    update public.invitations set roles = array_replace(roles, old.name, new.name)
      where org_id = old.org_id and old.name = any (roles);
  else
    update public.role_profile set roles = array_remove(roles, old.name)
      where org_id = old.org_id and old.name = any (roles);
    update public.org_members set roles = array_remove(roles, old.name)
      where org_id = old.org_id and old.name = any (roles);
    update public.invitations set roles = array_remove(roles, old.name)
      where org_id = old.org_id and old.name = any (roles);
  end if;
  return null;
end;
$$;

drop trigger if exists roles_propagate on public.roles;
create trigger roles_propagate
  after update or delete on public.roles
  for each row execute function app.roles_propagate();

-- Standard roles are protected by roles_guard (with a message) instead of being hidden from the delete policy.
drop policy if exists roles_delete on public.roles;
create policy roles_delete on public.roles for delete to authenticated
  using (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Role Profile: validate roles, re-sync members holding the profile (frappe RoleProfile.on_update)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.role_profile_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_unknown text;
begin
  new.name := trim(new.name);
  new.roles := array(
    select r from unnest(new.roles) with ordinality u (r, i)
    where r is not null and trim(r) <> ''
    group by r order by min(i)
  );

  select r into v_unknown
  from unnest(new.roles) r
  where not exists (select 1 from public.roles x where x.org_id = new.org_id and x.name = r)
  limit 1;
  if v_unknown is not null then
    raise exception using errcode = 'P0001', message = format('invalid_role: role "%s" does not exist in this organization', v_unknown);
  end if;
  return new;
end;
$$;

drop trigger if exists role_profile_validate on public.role_profile;
create trigger role_profile_validate
  before insert or update on public.role_profile
  for each row execute function app.role_profile_validate();

create or replace function app.role_profile_sync_members()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.roles is distinct from old.roles then
    update public.org_members set roles = new.roles
      where org_id = new.org_id and role_profile = new.name;
  end if;
  return null;
end;
$$;

drop trigger if exists role_profile_sync_members on public.role_profile;
create trigger role_profile_sync_members
  after update on public.role_profile
  for each row execute function app.role_profile_sync_members();

-- org_members: a member holding a profile always carries exactly the profile's roles (frappe User.validate
-- populate_role_profile_roles); assigning roles by hand means clearing the profile in the same update.
create or replace function app.org_members_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_unknown text;
  v_privileged boolean := current_user not in ('authenticated', 'anon');
begin
  if tg_op = 'DELETE' then
    -- Owners cannot be removed while the organization exists (cascade from organizations is allowed).
    if old.is_owner and exists (select 1 from public.organizations o where o.id = old.org_id) then
      raise exception using errcode = 'P0001', message = 'owner_protected: the organization owner cannot be removed';
    end if;
    return old;
  end if;

  if not v_privileged and new.is_owner is distinct from (case when tg_op = 'UPDATE' then old.is_owner else false end) then
    raise exception using errcode = 'P0001', message = 'owner_protected: ownership cannot be changed here';
  end if;

  if new.role_profile is not null
     and (tg_op = 'INSERT' or new.role_profile is distinct from old.role_profile or new.roles is distinct from old.roles) then
    select rp.roles into new.roles from public.role_profile rp where rp.org_id = new.org_id and rp.name = new.role_profile;
  end if;

  if new.is_owner then
    if new.status <> 'active' then
      raise exception using errcode = 'P0001', message = 'owner_protected: the organization owner cannot be disabled';
    end if;
    if not ('System Manager' = any (new.roles)) then
      new.roles := new.roles || 'System Manager'::text;
    end if;
  end if;

  new.roles := array(select distinct r from unnest(new.roles) r order by r);

  select r into v_unknown
  from unnest(new.roles) r
  where not exists (select 1 from public.roles x where x.org_id = new.org_id and x.name = r)
  limit 1;
  if v_unknown is not null then
    raise exception using errcode = 'P0001', message = format('invalid_role: role "%s" does not exist in this organization', v_unknown);
  end if;

  return new;
end;
$$;

revoke execute on function
  app.locked_permission_doctypes(), app.role_permissions_locked(), app.roles_guard(), app.roles_propagate(),
  app.role_profile_validate(), app.role_profile_sync_members(), app.org_members_validate()
from public, anon, authenticated;
-- role_permissions_locked runs as the caller and reads the locked list.
grant execute on function app.locked_permission_doctypes() to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Default permissions (frappe role.json / role_profile.json: System Manager only)
------------------------------------------------------------------------------------------------------------------------

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Role',         true, true, true, true),
  ('System Manager', 'Role Profile', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
