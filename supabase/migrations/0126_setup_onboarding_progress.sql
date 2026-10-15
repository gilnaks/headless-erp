-- 0126 setup: Home onboarding checklist -> public.onboarding_progress (docs/modules/00-setup.md §7, C6).
-- ERPNext sources: erpnext/setup/workspace/home/home.json (Home workspace: onboarding, chart, number cards),
-- erpnext/setup/module_onboarding/organization_onboarding (steps; Quality dropped) and the Frappe Module Onboarding
-- behaviour (a step is complete or skipped; the card hides when every step is done or it is dismissed).
-- Steps complete from the events that finish them: inviting a user here, the module steps when those modules land
-- (they call app.onboarding_complete).

create table if not exists public.onboarding_progress (
  org_id       uuid not null references public.organizations (id) on delete cascade,
  step         text not null
               check (step in ('invite_users', 'accounting', 'selling', 'buying', 'stock', 'manufacturing', 'projects', 'assets')),
  idx          int not null,
  completed_at timestamptz,
  skipped_at   timestamptz,
  created_at   timestamptz not null default now(),
  created_by   uuid default auth.uid(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid,
  primary key (org_id, step)
);

alter table public.organizations add column if not exists onboarding_dismissed_at timestamptz;

drop trigger if exists touch_updated on public.onboarding_progress;
create trigger touch_updated
  before update on public.onboarding_progress
  for each row execute function app.touch_updated();

-- Members read; every write goes through the app.onboarding_* functions below.
alter table public.onboarding_progress enable row level security;
alter table public.onboarding_progress force row level security;

drop policy if exists onboarding_progress_select on public.onboarding_progress;
create policy onboarding_progress_select on public.onboarding_progress for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Seeding (Stage C6 of provisioning: every new organization gets the steps)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.seed_onboarding(p_org uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.onboarding_progress (org_id, step, idx)
  select p_org, s.step, s.idx
    from unnest(array['invite_users', 'accounting', 'selling', 'buying', 'stock', 'manufacturing', 'projects', 'assets'])
         with ordinality as s(step, idx)
  on conflict (org_id, step) do nothing;
$$;

create or replace function app.organizations_seed_onboarding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_onboarding(new.id);
  return new;
end;
$$;

drop trigger if exists organizations_seed_onboarding on public.organizations;
create trigger organizations_seed_onboarding
  after insert on public.organizations
  for each row execute function app.organizations_seed_onboarding();

------------------------------------------------------------------------------------------------------------------------
-- Step changes
------------------------------------------------------------------------------------------------------------------------

-- Called by the events that finish a step (definer callers only).
create or replace function app.onboarding_complete(p_org uuid, p_step text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.onboarding_progress
     set completed_at = now()
   where org_id = p_org and step = p_step and completed_at is null;
$$;

create or replace function app.invitations_complete_onboarding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.onboarding_complete(new.org_id, 'invite_users');
  return new;
end;
$$;

drop trigger if exists invitations_complete_onboarding on public.invitations;
create trigger invitations_complete_onboarding
  after insert on public.invitations
  for each row execute function app.invitations_complete_onboarding();

create or replace function app.onboarding_skip(p_org uuid, p_step text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app.has_role(p_org, 'System Manager') then
    raise exception using errcode = '42501', message = 'permission_denied: only a System Manager can change the onboarding checklist';
  end if;
  update public.onboarding_progress
     set skipped_at = now()
   where org_id = p_org and step = p_step and completed_at is null and skipped_at is null;
end;
$$;

create or replace function app.onboarding_dismiss(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app.has_role(p_org, 'System Manager') then
    raise exception using errcode = '42501', message = 'permission_denied: only a System Manager can change the onboarding checklist';
  end if;
  update public.organizations set onboarding_dismissed_at = now() where id = p_org and onboarding_dismissed_at is null;
end;
$$;

revoke execute on function app.seed_onboarding(uuid) from public, anon, authenticated;
revoke execute on function app.organizations_seed_onboarding() from public, anon, authenticated;
revoke execute on function app.onboarding_complete(uuid, text) from public, anon, authenticated;
revoke execute on function app.invitations_complete_onboarding() from public, anon, authenticated;
revoke execute on function app.onboarding_skip(uuid, text) from public, anon;
revoke execute on function app.onboarding_dismiss(uuid) from public, anon;
grant execute on function app.onboarding_skip(uuid, text) to authenticated;
grant execute on function app.onboarding_dismiss(uuid) to authenticated;

create or replace function public.onboarding_skip(p_org uuid, p_step text)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.onboarding_skip(p_org, p_step);
$$;

create or replace function public.onboarding_dismiss(p_org uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.onboarding_dismiss(p_org);
$$;

revoke execute on function public.onboarding_skip(uuid, text) from public, anon;
revoke execute on function public.onboarding_dismiss(uuid) from public, anon;
grant execute on function public.onboarding_skip(uuid, text) to authenticated;
grant execute on function public.onboarding_dismiss(uuid) to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Backfill: existing organizations get the steps; those that already invited someone have that step done.
------------------------------------------------------------------------------------------------------------------------

select app.seed_onboarding(o.id) from public.organizations o;

update public.onboarding_progress p
   set completed_at = i.first_invite
  from (select org_id, min(created_at) as first_invite from public.invitations group by org_id) i
 where p.org_id = i.org_id and p.step = 'invite_users' and p.completed_at is null;
