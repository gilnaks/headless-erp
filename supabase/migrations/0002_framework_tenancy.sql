-- 0002 framework: tenancy, membership, roles, permissions, invitations, user profile, doctype registry.
-- Spec: docs/architecture/01-tenancy-auth-rls.md, docs/modules/00-setup.md §2.6–2.9.
-- ERPNext/Frappe sources: frappe/core/doctype/{user,role,role_profile,user_permission,custom_docperm},
-- erpnext/setup/install.py (DEFAULT_ROLE_PROFILES).

------------------------------------------------------------------------------------------------------------------------
-- Tables
------------------------------------------------------------------------------------------------------------------------

create table if not exists public.organizations (
  id               uuid primary key default gen_random_uuid(),
  slug             text not null unique check (slug ~ '^[a-z0-9-]{3,40}$'),
  name             text not null,
  country          text,
  default_currency text,
  time_zone        text not null default 'UTC',
  language         text not null default 'en',
  plan             text not null default 'free',
  status           text not null default 'active' check (status in ('active', 'suspended')),
  provisioned_at   timestamptz,
  created_at       timestamptz not null default now(),
  created_by       uuid default auth.uid(),
  updated_at       timestamptz not null default now(),
  updated_by       uuid
);

create table if not exists public.roles (
  org_id      uuid not null references public.organizations (id) on delete cascade,
  name        text not null check (length(trim(name)) > 0),
  is_standard boolean not null default false,
  disabled    boolean not null default false,
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid(),
  updated_at  timestamptz not null default now(),
  updated_by  uuid,
  primary key (org_id, name)
);

create table if not exists public.org_members (
  org_id       uuid not null references public.organizations (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  roles        text[] not null default '{}',
  role_profile text,
  is_owner     boolean not null default false,
  status       text not null default 'active' check (status in ('active', 'invited', 'disabled')),
  created_at   timestamptz not null default now(),
  created_by   uuid default auth.uid(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid,
  primary key (org_id, user_id)
);
create index if not exists org_members_user_idx on public.org_members (user_id, status);

create table if not exists public.role_profile (
  org_id     uuid not null references public.organizations (id) on delete cascade,
  name       text not null,
  roles      text[] not null default '{}',
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (org_id, name)
);

alter table public.org_members drop constraint if exists org_members_role_profile_fkey;
alter table public.org_members
  add constraint org_members_role_profile_fkey foreign key (org_id, role_profile)
  references public.role_profile (org_id, name) on update cascade on delete set null (role_profile);

-- Mirrors the doctype JSON `permissions` array (permlevel 0 only).
create table if not exists public.role_permissions (
  org_id     uuid not null,
  role       text not null,
  doctype    text not null,
  can_read   boolean not null default false,
  can_write  boolean not null default false,
  can_create boolean not null default false,
  can_submit boolean not null default false,
  can_cancel boolean not null default false,
  can_amend  boolean not null default false,
  can_delete boolean not null default false,
  can_report boolean not null default true,
  can_export boolean not null default true,
  if_owner   boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (org_id, role, doctype),
  foreign key (org_id, role) references public.roles (org_id, name) on update cascade on delete cascade
);
create index if not exists role_permissions_doctype_idx on public.role_permissions (org_id, doctype);

-- Frappe "User Permission": restricts a user to specific records of a doctype.
create table if not exists public.user_permissions (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  user_id          uuid not null references auth.users (id) on delete cascade,
  doctype          text not null,
  record_id        uuid not null,
  applicable_for   text,
  is_default       boolean not null default false,
  hide_descendants boolean not null default false,
  created_at       timestamptz not null default now(),
  created_by       uuid default auth.uid(),
  updated_at       timestamptz not null default now(),
  updated_by       uuid
);
create unique index if not exists user_permissions_uniq
  on public.user_permissions (org_id, user_id, doctype, record_id, coalesce(applicable_for, ''));

create table if not exists public.invitations (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations (id) on delete cascade,
  email       text not null check (email = lower(email)),
  roles       text[] not null default '{}',
  token       text not null unique default encode(extensions.gen_random_bytes(24), 'hex'),
  expires_at  timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid(),
  updated_at  timestamptz not null default now(),
  updated_by  uuid
);
create index if not exists invitations_org_idx on public.invitations (org_id, email);

-- Global identity profile (one row per auth user); membership and roles are per org.
create table if not exists public.user_profile (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  last_name  text,
  full_name  text generated always as (nullif(trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')), '')) stored,
  avatar_url text,
  language   text,
  time_zone  text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid
);

-- Global doctype registry; `defineDoctype()` descriptors must agree with it.
create table if not exists public.doctype_meta (
  doctype                text primary key,
  table_name             text not null unique,
  module                 text not null,
  is_submittable         boolean not null default false,
  is_tree                boolean not null default false,
  is_child               boolean not null default false,
  parent_doctype         text references public.doctype_meta (doctype),
  title_field            text,
  naming_series_default  text,
  no_copy_fields         text[] not null default '{}',
  allow_on_submit        text[] not null default '{}',
  user_permission_target boolean not null default false
);

------------------------------------------------------------------------------------------------------------------------
-- Permission helpers (authoritative: read org_members/role_permissions, never the JWT claim)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.user_org_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(m.org_id), '{}')
  from public.org_members m
  where m.user_id = (select auth.uid()) and m.status = 'active';
$$;

create or replace function app.is_member(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    where m.org_id = p_org and m.user_id = (select auth.uid()) and m.status = 'active'
  );
$$;

create or replace function app.user_roles(p_org uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select array_agg(r.name order by r.name)
       from public.org_members m
       join public.roles r on r.org_id = m.org_id and r.name = any (m.roles) and not r.disabled
      where m.org_id = p_org and m.user_id = (select auth.uid()) and m.status = 'active'),
    '{}');
$$;

-- Orgs in which the current user holds `p_role`. Used in policies as `org_id = any ((select ...))` (one initplan).
create or replace function app.orgs_with_role(p_role text)
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(m.org_id), '{}')
  from public.org_members m
  join public.roles r on r.org_id = m.org_id and r.name = p_role and not r.disabled
  where m.user_id = (select auth.uid()) and m.status = 'active' and p_role = any (m.roles);
$$;

-- Orgs in which the current user may perform `p_action` on `p_doctype`.
create or replace function app.orgs_with_perm(p_doctype text, p_action text)
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct m.org_id), '{}')
  from public.org_members m
  join public.roles r on r.org_id = m.org_id and r.name = any (m.roles) and not r.disabled
  join public.role_permissions rp on rp.org_id = m.org_id and rp.role = r.name and rp.doctype = p_doctype
  where m.user_id = (select auth.uid())
    and m.status = 'active'
    and case p_action
          when 'read'   then rp.can_read
          when 'write'  then rp.can_write
          when 'create' then rp.can_create
          when 'submit' then rp.can_submit
          when 'cancel' then rp.can_cancel
          when 'amend'  then rp.can_amend
          when 'delete' then rp.can_delete
          when 'report' then rp.can_report and rp.can_read
          when 'export' then rp.can_export and rp.can_read
          else false
        end;
$$;

create or replace function app.has_perm(p_org uuid, p_doctype text, p_action text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_org = any (app.orgs_with_perm(p_doctype, p_action));
$$;

create or replace function app.has_role(p_org uuid, p_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_org = any (app.orgs_with_role(p_role));
$$;

-- Records of `p_doctype` the user is restricted to (null = unrestricted), per Frappe User Permission semantics.
create or replace function app.allowed_records(p_org uuid, p_doctype text, p_for text default null)
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select array_agg(up.record_id)
  from public.user_permissions up
  where up.org_id = p_org
    and up.user_id = (select auth.uid())
    and up.doctype = p_doctype
    and (up.applicable_for is null or up.applicable_for = p_for);
$$;

create or replace function app.record_allowed(p_org uuid, p_doctype text, p_record uuid, p_for text default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p_record = any (app.allowed_records(p_org, p_doctype, p_for)), app.allowed_records(p_org, p_doctype, p_for) is null);
$$;

create or replace function app.company_allowed(p_org uuid, p_company uuid, p_for text default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.record_allowed(p_org, 'Company', p_company, p_for);
$$;

grant execute on function
  app.user_org_ids(), app.is_member(uuid), app.user_roles(uuid), app.orgs_with_role(text),
  app.orgs_with_perm(text, text), app.has_perm(uuid, text, text), app.has_role(uuid, text),
  app.allowed_records(uuid, text, text), app.record_allowed(uuid, text, uuid, text),
  app.company_allowed(uuid, uuid, text)
to authenticated, service_role;

------------------------------------------------------------------------------------------------------------------------
-- Membership integrity
------------------------------------------------------------------------------------------------------------------------

-- Runs as the invoker so `current_user` distinguishes API callers from provisioning/service role.
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

  if new.role_profile is not null and (tg_op = 'INSERT' or new.role_profile is distinct from old.role_profile) then
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

drop trigger if exists org_members_validate on public.org_members;
create trigger org_members_validate
  before insert or update or delete on public.org_members
  for each row execute function app.org_members_validate();

------------------------------------------------------------------------------------------------------------------------
-- Auth integration
------------------------------------------------------------------------------------------------------------------------

create or replace function app.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_profile (user_id, first_name, last_name)
  values (new.id, new.raw_user_meta_data ->> 'first_name', new.raw_user_meta_data ->> 'last_name')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.handle_new_user();

-- Custom Access Token Hook: adds `app.orgs = { <org_id>: [roles] }` for UI hints. RLS never trusts it.
create or replace function app.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_orgs jsonb;
begin
  select coalesce(jsonb_object_agg(m.org_id::text, to_jsonb(m.roles)), '{}'::jsonb)
    into v_orgs
  from public.org_members m
  where m.user_id = (event ->> 'user_id')::uuid and m.status = 'active';

  return jsonb_set(event, '{claims,app}', jsonb_build_object('orgs', v_orgs), true);
end;
$$;

grant usage on schema app to supabase_auth_admin;
grant execute on function app.custom_access_token_hook(jsonb) to supabase_auth_admin;

-- Invite flow: the signed-in user whose email matches the invitation joins the org.
create or replace function app.accept_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.invitations;
  v_uid uuid := auth.uid();
  v_email text := lower(auth.jwt() ->> 'email');
begin
  if v_uid is null then
    raise exception using errcode = 'P0001', message = 'not_authenticated: sign in to accept the invitation';
  end if;

  select * into v_inv from public.invitations where token = p_token for update;
  if not found or v_inv.accepted_at is not null or v_inv.expires_at < now() then
    raise exception using errcode = 'P0001', message = 'invalid_invitation: this invitation is invalid or has expired';
  end if;
  if v_inv.email <> v_email then
    raise exception using errcode = 'P0001', message = 'invalid_invitation: this invitation was sent to a different email address';
  end if;

  insert into public.org_members (org_id, user_id, roles, status)
  values (v_inv.org_id, v_uid, v_inv.roles, 'active')
  on conflict (org_id, user_id) do update
    set roles = (select array(select distinct unnest(public.org_members.roles || excluded.roles))),
        status = 'active';

  update public.invitations set accepted_at = now(), accepted_by = v_uid where id = v_inv.id;
  return v_inv.org_id;
end;
$$;

grant execute on function app.accept_invitation(text) to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Audit triggers
------------------------------------------------------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array['organizations', 'roles', 'org_members', 'role_profile', 'role_permissions',
                           'user_permissions', 'invitations', 'user_profile']
  loop
    execute format('drop trigger if exists touch_updated on public.%I', t);
    execute format('create trigger touch_updated before update on public.%I for each row execute function app.touch_updated()', t);
  end loop;
end;
$$;

------------------------------------------------------------------------------------------------------------------------
-- RLS
------------------------------------------------------------------------------------------------------------------------

alter table public.organizations    enable row level security; alter table public.organizations    force row level security;
alter table public.roles            enable row level security; alter table public.roles            force row level security;
alter table public.org_members      enable row level security; alter table public.org_members      force row level security;
alter table public.role_profile     enable row level security; alter table public.role_profile     force row level security;
alter table public.role_permissions enable row level security; alter table public.role_permissions force row level security;
alter table public.user_permissions enable row level security; alter table public.user_permissions force row level security;
alter table public.invitations      enable row level security; alter table public.invitations      force row level security;
alter table public.user_profile     enable row level security; alter table public.user_profile     force row level security;
alter table public.doctype_meta     enable row level security; alter table public.doctype_meta     force row level security;

-- organizations: members read; System Manager updates; created/deleted only by provisioning (service role).
drop policy if exists organizations_select on public.organizations;
create policy organizations_select on public.organizations for select to authenticated
  using (id = any ((select app.user_org_ids())::uuid[]));
drop policy if exists organizations_update on public.organizations;
create policy organizations_update on public.organizations for update to authenticated
  using (id = any ((select app.orgs_with_role('System Manager'))::uuid[]))
  with check (id = any ((select app.orgs_with_role('System Manager'))::uuid[]));

-- Tables administered by System Manager and readable by every member.
do $$
declare t text;
begin
  foreach t in array array['roles', 'org_members', 'role_profile', 'role_permissions']
  loop
    execute format('drop policy if exists %1$s_select on public.%1$I', t);
    execute format('create policy %1$s_select on public.%1$I for select to authenticated using (org_id = any ((select app.user_org_ids())::uuid[]))', t);
    execute format('drop policy if exists %1$s_insert on public.%1$I', t);
    execute format($p$create policy %1$s_insert on public.%1$I for insert to authenticated
      with check (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]))$p$, t);
    execute format('drop policy if exists %1$s_update on public.%1$I', t);
    execute format($p$create policy %1$s_update on public.%1$I for update to authenticated
      using (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]))
      with check (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]))$p$, t);
    execute format('drop policy if exists %1$s_delete on public.%1$I', t);
    execute format($p$create policy %1$s_delete on public.%1$I for delete to authenticated
      using (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]))$p$, t);
  end loop;
end;
$$;

-- Standard roles cannot be renamed or deleted by tenants.
drop policy if exists roles_delete on public.roles;
create policy roles_delete on public.roles for delete to authenticated
  using (not is_standard and org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));

-- user_permissions: System Manager manages; a user can read their own restrictions.
drop policy if exists user_permissions_select on public.user_permissions;
create policy user_permissions_select on public.user_permissions for select to authenticated
  using (user_id = (select auth.uid()) or org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));
drop policy if exists user_permissions_insert on public.user_permissions;
create policy user_permissions_insert on public.user_permissions for insert to authenticated
  with check (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));
drop policy if exists user_permissions_update on public.user_permissions;
create policy user_permissions_update on public.user_permissions for update to authenticated
  using (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));
drop policy if exists user_permissions_delete on public.user_permissions;
create policy user_permissions_delete on public.user_permissions for delete to authenticated
  using (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));

-- invitations: System Manager only (tokens are secrets); acceptance goes through app.accept_invitation().
drop policy if exists invitations_all on public.invitations;
create policy invitations_all on public.invitations for all to authenticated
  using (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));

-- user_profile: self read/write; members of a shared org read.
drop policy if exists user_profile_select on public.user_profile;
create policy user_profile_select on public.user_profile for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.org_members m
      where m.user_id = user_profile.user_id and m.org_id = any ((select app.user_org_ids())::uuid[])
    )
  );
drop policy if exists user_profile_update on public.user_profile;
create policy user_profile_update on public.user_profile for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- doctype_meta: global, read-only for authenticated users.
drop policy if exists doctype_meta_select on public.doctype_meta;
create policy doctype_meta_select on public.doctype_meta for select to authenticated using (true);

------------------------------------------------------------------------------------------------------------------------
-- Registry
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values
  ('User', 'org_members', 'setup', 'user_id'),
  ('Role', 'roles', 'setup', 'name'),
  ('Role Profile', 'role_profile', 'setup', 'name'),
  ('User Permission', 'user_permissions', 'setup', 'doctype')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;
