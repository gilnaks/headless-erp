-- 0106 setup: Users page (docs/modules/00-setup.md §2.6).
-- ERPNext source: erpnext/setup/install.py (roles granted to the first user), erpnext/setup/onboarding_step/invite_users.
-- Frappe (no local clone; from memory): frappe/core/doctype/user/user.json (System Manager rwcd),
-- user.py on_trash (a user's User Permission rows go with the user).
-- Membership rows (org_members) and their trigger live in 0002/0105; emails only exist in auth.users.

------------------------------------------------------------------------------------------------------------------------
-- Member directory: org_members joined with auth.users (email) and user_profile
------------------------------------------------------------------------------------------------------------------------

-- Active members see their colleagues; last sign-in is an admin detail (System Manager only).
create or replace function app.org_member_directory(p_org uuid)
returns table (
  user_id         uuid,
  email           text,
  full_name       text,
  avatar_url      text,
  roles           text[],
  role_profile    text,
  status          text,
  is_owner        boolean,
  created_at      timestamptz,
  last_sign_in_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select m.user_id, u.email::text, p.full_name, p.avatar_url, m.roles, m.role_profile, m.status, m.is_owner, m.created_at,
         case when p_org = any (app.orgs_with_role('System Manager')) then u.last_sign_in_at end
  from public.org_members m
  join auth.users u on u.id = m.user_id
  left join public.user_profile p on p.user_id = m.user_id
  where m.org_id = p_org and app.is_member(p_org)
  order by m.is_owner desc, lower(coalesce(p.full_name, u.email::text));
$$;

create or replace function public.org_member_directory(p_org uuid)
returns table (
  user_id         uuid,
  email           text,
  full_name       text,
  avatar_url      text,
  roles           text[],
  role_profile    text,
  status          text,
  is_owner        boolean,
  created_at      timestamptz,
  last_sign_in_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app.org_member_directory(p_org);
$$;

revoke execute on function app.org_member_directory(uuid), public.org_member_directory(uuid) from public, anon;
grant execute on function app.org_member_directory(uuid), public.org_member_directory(uuid) to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Removing a member drops their User Permissions in that organization
------------------------------------------------------------------------------------------------------------------------

create or replace function app.org_members_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.user_permissions where org_id = old.org_id and user_id = old.user_id;
  return null;
end;
$$;

drop trigger if exists org_members_cleanup on public.org_members;
create trigger org_members_cleanup
  after delete on public.org_members
  for each row execute function app.org_members_cleanup();

revoke execute on function app.org_members_cleanup() from public, anon, authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Default permissions (frappe user.json: System Manager only; locked by 0105)
------------------------------------------------------------------------------------------------------------------------

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'User', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
