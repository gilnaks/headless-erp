-- 0107 setup: invitations with a copyable link (docs/modules/00-setup.md §3.4, §5).
-- ERPNext source: erpnext/setup/onboarding_step/invite_users/invite_users.json ("Invite your team").
-- Frappe (no local clone; from memory): frappe/core/doctype/user/user.py (role_profile_name repopulates roles).
-- Delivery is link-only until the Email track: no email is sent; the System Manager copies /invite/<token>.

alter table public.invitations add column if not exists role_profile text;
alter table public.invitations add column if not exists revoked_at timestamptz;

alter table public.invitations drop constraint if exists invitations_role_profile_fkey;
alter table public.invitations
  add constraint invitations_role_profile_fkey foreign key (org_id, role_profile)
  references public.role_profile (org_id, name) on update cascade on delete set null (role_profile);

-- One open invitation per email and organization (older duplicates are revoked first).
update public.invitations i set revoked_at = now()
where i.accepted_at is null and i.revoked_at is null
  and exists (
    select 1 from public.invitations n
    where n.org_id = i.org_id and n.email = i.email and n.accepted_at is null and n.revoked_at is null
      and (n.created_at, n.id) > (i.created_at, i.id)
  );
create unique index if not exists invitations_open_uniq
  on public.invitations (org_id, email) where accepted_at is null and revoked_at is null;

------------------------------------------------------------------------------------------------------------------------
-- Validation: email shape, roles exist, profile roles win
------------------------------------------------------------------------------------------------------------------------

create or replace function app.invitations_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_unknown text;
begin
  new.email := lower(trim(new.email));
  if new.email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception using errcode = 'P0001', message = 'invalid_email: enter a valid email address';
  end if;

  if new.role_profile is not null then
    select rp.roles into new.roles from public.role_profile rp where rp.org_id = new.org_id and rp.name = new.role_profile;
  end if;
  new.roles := array(select distinct r from unnest(new.roles) r where r is not null and trim(r) <> '' order by r);

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

drop trigger if exists invitations_validate on public.invitations;
create trigger invitations_validate
  before insert or update of email, roles, role_profile on public.invitations
  for each row execute function app.invitations_validate();

------------------------------------------------------------------------------------------------------------------------
-- RPCs
------------------------------------------------------------------------------------------------------------------------

-- System Manager invites an email with roles or a role profile; returns { id, token } for the copyable link.
create or replace function app.create_invitation(p_org uuid, p_email text, p_roles text[], p_role_profile text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_inv public.invitations;
begin
  if not (p_org = any (app.orgs_with_role('System Manager'))) then
    raise exception using errcode = '42501', message = 'permission_denied: only a System Manager can invite users';
  end if;
  if nullif(trim(p_role_profile), '') is null and coalesce(cardinality(p_roles), 0) = 0 then
    raise exception using errcode = 'P0001', message = 'roles_required: choose at least one role or a role profile';
  end if;
  if exists (
    select 1 from public.org_members m join auth.users u on u.id = m.user_id
    where m.org_id = p_org and m.status = 'active' and lower(u.email) = v_email
  ) then
    raise exception using errcode = 'P0001', message = 'already_member: this person is already a member of the organization';
  end if;

  -- An expired open invitation no longer blocks a new one.
  update public.invitations set revoked_at = now()
  where org_id = p_org and email = v_email and accepted_at is null and revoked_at is null and expires_at < now();
  if exists (
    select 1 from public.invitations
    where org_id = p_org and email = v_email and accepted_at is null and revoked_at is null
  ) then
    raise exception using errcode = 'P0001', message = 'invite_pending: an invitation to this email is already open; resend it instead';
  end if;

  insert into public.invitations (org_id, email, roles, role_profile)
  values (p_org, v_email, coalesce(p_roles, '{}'), nullif(trim(p_role_profile), ''))
  returning * into v_inv;
  return jsonb_build_object('id', v_inv.id, 'token', v_inv.token);
end;
$$;

-- New token and a fresh 7-day expiry for an open invitation (the old link stops working).
create or replace function app.resend_invitation(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.invitations;
begin
  select * into v_inv from public.invitations where id = p_id for update;
  if not found or not (v_inv.org_id = any (app.orgs_with_role('System Manager'))) then
    raise exception using errcode = 'P0001', message = 'invitation_not_found: this invitation does not exist';
  end if;
  if v_inv.accepted_at is not null then
    raise exception using errcode = 'P0001', message = 'invitation_closed: this invitation was already accepted';
  end if;
  if v_inv.revoked_at is not null then
    raise exception using errcode = 'P0001', message = 'invitation_closed: this invitation was revoked; invite again instead';
  end if;

  update public.invitations
     set token = encode(extensions.gen_random_bytes(24), 'hex'), expires_at = now() + interval '7 days'
   where id = p_id
  returning * into v_inv;
  return jsonb_build_object('id', v_inv.id, 'token', v_inv.token);
end;
$$;

-- What the /invite page shows a signed-in user holding the link (tokens are secrets; RLS hides the table).
create or replace function app.invitation_preview(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'org_name', o.name,
    'email', i.email,
    'state', case
      when i.accepted_at is not null then 'accepted'
      when i.revoked_at is not null then 'revoked'
      when i.expires_at < now() then 'expired'
      else 'pending'
    end)
  from public.invitations i
  join public.organizations o on o.id = i.org_id
  where i.token = p_token and (select auth.uid()) is not null;
$$;

-- Accepting also refuses revoked invitations and applies the invited role profile.
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
  if v_inv.revoked_at is not null then
    raise exception using errcode = 'P0001', message = 'invalid_invitation: this invitation has been revoked';
  end if;
  if v_inv.email <> v_email then
    raise exception using errcode = 'P0001', message = 'invalid_invitation: this invitation was sent to a different email address';
  end if;

  insert into public.org_members (org_id, user_id, roles, role_profile, status)
  values (v_inv.org_id, v_uid, v_inv.roles, v_inv.role_profile, 'active')
  on conflict (org_id, user_id) do update
    set roles = case
          when excluded.role_profile is not null then excluded.roles
          else (select array(select distinct unnest(public.org_members.roles || excluded.roles)))
        end,
        role_profile = excluded.role_profile,
        status = 'active';

  update public.invitations set accepted_at = now(), accepted_by = v_uid where id = v_inv.id;
  return v_inv.org_id;
end;
$$;

create or replace function public.create_invitation(p_org uuid, p_email text, p_roles text[], p_role_profile text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.create_invitation(p_org, p_email, p_roles, p_role_profile);
$$;

create or replace function public.resend_invitation(p_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.resend_invitation(p_id);
$$;

create or replace function public.invitation_preview(p_token text)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.invitation_preview(p_token);
$$;

revoke execute on function
  app.invitations_validate(), app.create_invitation(uuid, text, text[], text), app.resend_invitation(uuid),
  app.invitation_preview(text),
  public.create_invitation(uuid, text, text[], text), public.resend_invitation(uuid), public.invitation_preview(text)
from public, anon, authenticated;
grant execute on function
  app.create_invitation(uuid, text, text[], text), app.resend_invitation(uuid), app.invitation_preview(text),
  public.create_invitation(uuid, text, text[], text), public.resend_invitation(uuid), public.invitation_preview(text)
to authenticated;
