begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role, last_sign_in_at) values
  ('00000000-0000-0000-0000-0000000011a1', 'users-owner-a@test.local', 'authenticated', 'authenticated', now()),
  ('00000000-0000-0000-0000-0000000011a2', 'users-member-a@test.local', 'authenticated', 'authenticated', now()),
  ('00000000-0000-0000-0000-0000000011a3', 'users-leaver-a@test.local', 'authenticated', 'authenticated', now()),
  ('00000000-0000-0000-0000-0000000011b1', 'users-owner-b@test.local', 'authenticated', 'authenticated', now());

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000011b1","role":"authenticated"}', true);
select set_config('test.org_b', public.create_organization('{"name":"Users Org B","slug":"users-org-b"}') ->> 'id', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000011a1","role":"authenticated"}', true);
select set_config('test.org', public.create_organization('{"name":"Users Org A","slug":"users-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);

insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000011a2', '{Sales User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000011a3', '{Sales User}');
insert into public.companies (id, org_id, company_name, abbr)
  values ('00000000-0000-0000-0000-0000000011c1', current_setting('test.org')::uuid, 'Users Co', 'UCO');
insert into public.user_permissions (org_id, user_id, doctype, record_id)
  values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000011a3', 'Company', '00000000-0000-0000-0000-0000000011c1');

-- Directory as System Manager (owner A)
select is(
  (select array_agg(email order by email) from public.org_member_directory(current_setting('test.org')::uuid)),
  '{users-leaver-a@test.local,users-member-a@test.local,users-owner-a@test.local}'::text[],
  'the directory lists the members of the organization with their emails'
);
select is(
  (select email from public.org_member_directory(current_setting('test.org')::uuid) limit 1),
  'users-owner-a@test.local', 'the owner is listed first'
);
select is(
  (select count(*)::int from public.org_member_directory(current_setting('test.org')::uuid) where last_sign_in_at is not null),
  3, 'System Managers see the last sign-in'
);
select is(
  (select count(*)::int from public.org_member_directory(current_setting('test.org_b')::uuid)),
  0, 'the directory of another organization is empty'
);

-- Owner protection
select throws_ok(
  $$update public.org_members set status = 'disabled'
    where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a1'$$,
  'P0001', 'owner_protected: the organization owner cannot be disabled', 'the owner cannot be disabled'
);
select throws_ok(
  $$delete from public.org_members
    where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a1'$$,
  'P0001', 'owner_protected: the organization owner cannot be removed', 'the owner cannot be removed'
);

-- System Manager edits members
update public.org_members set status = 'disabled'
  where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a2';
select is(
  (select status from public.org_members where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a2'),
  'disabled', 'System Manager can disable a member'
);
update public.org_members set status = 'active'
  where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a2';

delete from public.org_members where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a3';
select is(
  (select count(*)::int from public.user_permissions where user_id = '00000000-0000-0000-0000-0000000011a3'),
  0, 'removing a member deletes their user permissions'
);

-- Directory as a member without System Manager
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000011a2","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.org_member_directory(current_setting('test.org')::uuid)),
  2, 'members see their colleagues'
);
select is(
  (select count(*)::int from public.org_member_directory(current_setting('test.org')::uuid) where last_sign_in_at is not null),
  0, 'members without System Manager do not see the last sign-in'
);

update public.org_members set roles = '{System Manager}'
  where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a2';
select is(
  (select roles from public.org_members where org_id = current_setting('test.org')::uuid and user_id = '00000000-0000-0000-0000-0000000011a2'),
  '{Sales User}'::text[], 'members without System Manager cannot change roles'
);

-- Not a member
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000011b1","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.org_member_directory(current_setting('test.org')::uuid)),
  0, 'non-members get an empty directory'
);

select * from finish();
rollback;
