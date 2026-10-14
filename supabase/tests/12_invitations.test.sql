begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000012a1', 'inv-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000012a2', 'inv-joiner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000012a3', 'inv-member-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000012a4', 'inv-revoked@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000012a5', 'inv-expired@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000012a1","role":"authenticated","email":"inv-owner-a@test.local"}', true);
select set_config('test.org', public.create_organization('{"name":"Invite Org A","slug":"invite-org-a"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000012a3', '{Sales User}');

-- Creating invitations
select set_config('test.inv', public.create_invitation(current_setting('test.org')::uuid, ' Inv-Joiner@Test.local ', '{}', 'Accounts')::text, true);
select is(
  (select email || ':' || coalesce(role_profile, '') || ':' || array_to_string(roles, ',')
   from public.invitations where id = (current_setting('test.inv')::jsonb ->> 'id')::uuid),
  'inv-joiner@test.local:Accounts:Accounts Manager,Accounts User',
  'the invitation stores the lower-cased email, the profile and its roles'
);
select throws_ok(
  $$select public.create_invitation(current_setting('test.org')::uuid, 'inv-joiner@test.local', '{Sales User}', null)$$,
  'P0001', 'invite_pending: an invitation to this email is already open; resend it instead', 'one open invitation per email'
);
select throws_ok(
  $$select public.create_invitation(current_setting('test.org')::uuid, 'inv-member-a@test.local', '{Sales User}', null)$$,
  'P0001', 'already_member: this person is already a member of the organization', 'members cannot be invited again'
);
select throws_ok(
  $$select public.create_invitation(current_setting('test.org')::uuid, 'ghost@test.local', '{Ghost}', null)$$,
  'P0001', 'invalid_role: role "Ghost" does not exist in this organization', 'unknown roles are rejected'
);
select throws_ok(
  $$select public.create_invitation(current_setting('test.org')::uuid, 'ghost@test.local', '{}', null)$$,
  'P0001', 'roles_required: choose at least one role or a role profile', 'an invitation needs roles or a profile'
);
select throws_ok(
  $$select public.create_invitation(current_setting('test.org')::uuid, 'not-an-email', '{Sales User}', null)$$,
  'P0001', 'invalid_email: enter a valid email address', 'the email must look like one'
);

-- Resend rotates the token
select set_config('test.old_token', current_setting('test.inv')::jsonb ->> 'token', true);
select set_config('test.inv', public.resend_invitation((current_setting('test.inv')::jsonb ->> 'id')::uuid)::text, true);
select isnt(current_setting('test.inv')::jsonb ->> 'token', current_setting('test.old_token'), 'resend issues a new token');

-- Revoked and expired invitations
select set_config('test.revoked', public.create_invitation(current_setting('test.org')::uuid, 'inv-revoked@test.local', '{Sales User}', null)::text, true);
update public.invitations set revoked_at = now() where id = (current_setting('test.revoked')::jsonb ->> 'id')::uuid;
select set_config('test.expired', public.create_invitation(current_setting('test.org')::uuid, 'inv-expired@test.local', '{Sales User}', null)::text, true);
update public.invitations set expires_at = now() - interval '1 day' where id = (current_setting('test.expired')::jsonb ->> 'id')::uuid;

select throws_ok(
  $$select public.resend_invitation((current_setting('test.revoked')::jsonb ->> 'id')::uuid)$$,
  'P0001', 'invitation_closed: this invitation was revoked; invite again instead', 'revoked invitations cannot be resent'
);

-- Members without System Manager
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000012a3","role":"authenticated","email":"inv-member-a@test.local"}', true);
select throws_ok(
  $$select public.create_invitation(current_setting('test.org')::uuid, 'someone@test.local', '{Sales User}', null)$$,
  '42501', 'permission_denied: only a System Manager can invite users', 'non System Managers cannot invite'
);
select throws_ok(
  $$select public.resend_invitation((current_setting('test.inv')::jsonb ->> 'id')::uuid)$$,
  'P0001', 'invitation_not_found: this invitation does not exist', 'non System Managers cannot resend'
);

-- Accepting
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000012a2","role":"authenticated","email":"inv-joiner@test.local"}', true);
select is(
  public.invitation_preview(current_setting('test.inv')::jsonb ->> 'token'),
  '{"org_name":"Invite Org A","email":"inv-joiner@test.local","state":"pending"}'::jsonb,
  'the preview shows the organization, email and state'
);
select throws_ok(
  $$select public.accept_invitation(current_setting('test.old_token'))$$,
  'P0001', 'invalid_invitation: this invitation is invalid or has expired', 'the token replaced by resend no longer works'
);
select lives_ok($$select public.accept_invitation(current_setting('test.inv')::jsonb ->> 'token')$$, 'the invitee accepts');
select is(
  (select role_profile || ':' || array_to_string(roles, ',') from public.org_members
   where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000012a2'),
  'Accounts:Accounts Manager,Accounts User', 'accepting applies the role profile'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000012a4","role":"authenticated","email":"inv-revoked@test.local"}', true);
select throws_ok(
  $$select public.accept_invitation(current_setting('test.revoked')::jsonb ->> 'token')$$,
  'P0001', 'invalid_invitation: this invitation has been revoked', 'revoked invitations are refused'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000012a5","role":"authenticated","email":"inv-expired@test.local"}', true);
select throws_ok(
  $$select public.accept_invitation(current_setting('test.expired')::jsonb ->> 'token')$$,
  'P0001', 'invalid_invitation: this invitation is invalid or has expired', 'expired invitations are refused'
);

-- Revoked or expired invitations do not block a new one
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000012a1","role":"authenticated","email":"inv-owner-a@test.local"}', true);
select lives_ok(
  $$select public.create_invitation(current_setting('test.org')::uuid, 'inv-revoked@test.local', '{Sales User}', null);
    select public.create_invitation(current_setting('test.org')::uuid, 'inv-expired@test.local', '{Sales User}', null)$$,
  'revoked and expired invitations can be replaced'
);

select * from finish();
rollback;
