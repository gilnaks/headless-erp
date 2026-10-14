begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000010a1', 'roles-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000010a2', 'roles-member-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000010b1', 'roles-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000010b1","role":"authenticated"}', true);
select set_config('test.org_b', public.create_organization('{"name":"Roles Org B","slug":"roles-org-b"}') ->> 'id', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000010a1","role":"authenticated"}', true);
select set_config('test.org', public.create_organization('{"name":"Roles Org A","slug":"roles-org-a"}') ->> 'id', true);

-- Standard roles and System Manager
select throws_ok(
  $$update public.roles set name = 'Boss' where org_id = current_setting('test.org')::uuid and name = 'Sales User'$$,
  'P0001', 'role_standard: Standard role Sales User cannot be renamed', 'standard roles cannot be renamed'
);
select throws_ok(
  $$delete from public.roles where org_id = current_setting('test.org')::uuid and name = 'Sales User'$$,
  'P0001', 'role_standard: Standard role Sales User cannot be deleted', 'standard roles cannot be deleted'
);
select throws_ok(
  $$update public.roles set disabled = true where org_id = current_setting('test.org')::uuid and name = 'System Manager'$$,
  'P0001', 'role_protected: System Manager cannot be disabled', 'System Manager cannot be disabled'
);
select throws_ok(
  $$update public.roles set is_standard = false where org_id = current_setting('test.org')::uuid and name = 'Auditor'$$,
  'P0001', 'role_standard: Standard flag cannot be changed', 'the standard flag cannot be cleared'
);
select lives_ok(
  $$insert into public.roles (org_id, name, is_standard) values (current_setting('test.org')::uuid, 'Reviewer', true)$$,
  'System Manager can add a custom role'
);
select is(
  (select is_standard from public.roles where org_id = current_setting('test.org')::uuid and name = 'Reviewer'),
  false, 'roles added through the API are never standard'
);
select isnt((select id from public.roles where org_id = current_setting('test.org')::uuid and name = 'Reviewer'), null, 'roles have a uuid id');

-- Profiles, members and invitations referencing the custom role
insert into public.role_permissions (org_id, role, doctype, can_read) values (current_setting('test.org')::uuid, 'Reviewer', 'Company', true);
insert into public.role_profile (org_id, name, roles) values (current_setting('test.org')::uuid, 'Review', '{Sales User,Reviewer,Sales User}');
insert into public.org_members (org_id, user_id, role_profile) values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000010a2', 'Review');
insert into public.invitations (org_id, email, roles) values (current_setting('test.org')::uuid, 'later@test.local', '{Reviewer}');

select is(
  (select roles from public.role_profile where org_id = current_setting('test.org')::uuid and name = 'Review'),
  '{Sales User,Reviewer}'::text[], 'profile roles are deduplicated in order'
);
select throws_ok(
  $$insert into public.role_profile (org_id, name, roles) values (current_setting('test.org')::uuid, 'Ghosts', '{Ghost}')$$,
  'P0001', 'invalid_role: role "Ghost" does not exist in this organization', 'profiles reject unknown roles'
);

update public.roles set name = 'Approver' where org_id = current_setting('test.org')::uuid and name = 'Reviewer';

select is(
  (select roles from public.role_profile where org_id = current_setting('test.org')::uuid and name = 'Review'),
  '{Sales User,Approver}'::text[], 'renaming a role rewrites profiles'
);
select is(
  (select roles from public.org_members where user_id = '00000000-0000-0000-0000-0000000010a2'),
  '{Approver,Sales User}'::text[], 'renaming a role rewrites member roles'
);
select is(
  (select roles from public.invitations where org_id = current_setting('test.org')::uuid),
  '{Approver}'::text[], 'renaming a role rewrites invitations'
);
select is(
  (select count(*)::int from public.role_permissions where org_id = current_setting('test.org')::uuid and role = 'Approver'),
  1, 'renaming a role carries its permissions'
);

update public.role_profile set roles = '{Sales User}' where org_id = current_setting('test.org')::uuid and name = 'Review';
select is(
  (select roles from public.org_members where user_id = '00000000-0000-0000-0000-0000000010a2'),
  '{Sales User}'::text[], 'editing a profile re-syncs its members'
);

update public.org_members set roles = '{Approver}' where user_id = '00000000-0000-0000-0000-0000000010a2';
select is(
  (select roles from public.org_members where user_id = '00000000-0000-0000-0000-0000000010a2'),
  '{Sales User}'::text[], 'a member holding a profile keeps the profile roles'
);

update public.org_members set role_profile = null, roles = '{Approver}' where user_id = '00000000-0000-0000-0000-0000000010a2';

-- Locked access doctypes
select throws_ok(
  $$insert into public.role_permissions (org_id, role, doctype, can_read) values (current_setting('test.org')::uuid, 'Sales User', 'Role', true)$$,
  'P0001', 'permission_locked: permissions for Role are fixed to System Manager', 'access doctype permissions are locked'
);

select is(
  (select count(*)::int from public.roles where org_id = current_setting('test.org_b')::uuid),
  0, 'roles of another organization are invisible'
);

-- As a member without System Manager
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000010a2","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.roles (org_id, name) values (current_setting('test.org')::uuid, 'Sneaky')$$,
  '42501', null, 'members without System Manager cannot add roles'
);

-- Deleting the custom role strips it everywhere
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000010a1","role":"authenticated"}', true);
delete from public.roles where org_id = current_setting('test.org')::uuid and name = 'Approver';

select is(
  (select roles from public.org_members where user_id = '00000000-0000-0000-0000-0000000010a2'),
  '{}'::text[], 'deleting a role strips it from members'
);
select is(
  (select roles from public.invitations where org_id = current_setting('test.org')::uuid),
  '{}'::text[], 'deleting a role strips it from invitations'
);

select * from finish();
rollback;
