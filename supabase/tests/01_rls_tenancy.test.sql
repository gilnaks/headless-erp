begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Fixtures (as postgres): two orgs, an owner each, plus a Sales User in org A.
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'owner-b@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a2', 'sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000c1', 'invitee@test.local', 'authenticated', 'authenticated');

insert into public.organizations (id, slug, name) values
  ('10000000-0000-0000-0000-00000000000a', 'org-a', 'Org A'),
  ('10000000-0000-0000-0000-00000000000b', 'org-b', 'Org B');

insert into public.roles (org_id, name, is_standard) values
  ('10000000-0000-0000-0000-00000000000a', 'System Manager', true),
  ('10000000-0000-0000-0000-00000000000a', 'Sales User', true),
  ('10000000-0000-0000-0000-00000000000b', 'System Manager', true);

insert into public.org_members (org_id, user_id, roles, is_owner) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', '{}', true),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', '{}', true),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', '{Sales User}', false);

insert into public.role_permissions (org_id, role, doctype, can_read, can_write) values
  ('10000000-0000-0000-0000-00000000000a', 'Sales User', 'Customer', true, true);

insert into public.invitations (org_id, email, roles, token) values
  ('10000000-0000-0000-0000-00000000000a', 'invitee@test.local', '{Sales User}', 'tok-a');

select is(
  (select roles from public.org_members where user_id = '00000000-0000-0000-0000-00000000000a'),
  '{System Manager}'::text[],
  'owner always holds System Manager'
);

-- As owner A.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated","email":"owner-a@test.local"}', true);

select results_eq('select slug from public.organizations', array['org-a'], 'owner A sees only org A');
select is((select count(*)::int from public.org_members), 2, 'owner A sees only org A members');
select is((select count(*)::int from public.roles where org_id = '10000000-0000-0000-0000-00000000000b'), 0, 'owner A cannot read org B roles');

select throws_ok(
  $$insert into public.roles (org_id, name) values ('10000000-0000-0000-0000-00000000000b', 'Hacker')$$,
  '42501', null, 'owner A cannot insert roles into org B'
);

select lives_ok(
  $$insert into public.roles (org_id, name) values ('10000000-0000-0000-0000-00000000000a', 'Custom Role')$$,
  'System Manager can add a custom role'
);

select throws_ok(
  $$update public.org_members set roles = '{Nonexistent}' where user_id = '00000000-0000-0000-0000-0000000000a2'$$,
  'P0001', 'invalid_role: role "Nonexistent" does not exist in this organization', 'unknown roles are rejected'
);

select throws_ok(
  $$delete from public.org_members where user_id = '00000000-0000-0000-0000-00000000000a'$$,
  'P0001', 'owner_protected: the organization owner cannot be removed', 'owner cannot be removed'
);

select throws_ok(
  $$update public.org_members set is_owner = true where user_id = '00000000-0000-0000-0000-0000000000a2'$$,
  'P0001', 'owner_protected: ownership cannot be changed here', 'ownership cannot be transferred via the API'
);

select ok(app.has_role('10000000-0000-0000-0000-00000000000a', 'System Manager'), 'has_role resolves owner role');

-- As Sales User A.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated","email":"sales-a@test.local"}', true);

select ok(app.has_perm('10000000-0000-0000-0000-00000000000a', 'Customer', 'write'), 'Sales User may write Customer');
select ok(not app.has_perm('10000000-0000-0000-0000-00000000000a', 'Customer', 'delete'), 'Sales User may not delete Customer');
select is((select count(*)::int from public.invitations), 0, 'non System Manager cannot read invitation tokens');

update public.org_members set roles = '{System Manager}' where user_id = '00000000-0000-0000-0000-0000000000a2';
select is(app.user_roles('10000000-0000-0000-0000-00000000000a'), '{Sales User}'::text[], 'Sales User cannot escalate own roles');

-- As invitee.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated","email":"invitee@test.local"}', true);

select is(public.accept_invitation('tok-a'), '10000000-0000-0000-0000-00000000000a'::uuid, 'invitee accepts invitation');
select is(app.user_roles('10000000-0000-0000-0000-00000000000a'), '{Sales User}'::text[], 'invitee joined with invited roles');

select * from finish();
rollback;
