begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000007a1', 'profiles-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000007a2', 'profiles-member@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000007a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Profiles Org","slug":"profiles-org"}') ->> 'id', true);

select results_eq(
  $$select name, roles from public.role_profile where org_id = current_setting('test.org')::uuid order by name$$,
  $$values ('Accounts', '{Accounts User,Accounts Manager}'::text[]),
           ('Inventory', '{Stock User,Stock Manager,Item Manager}'::text[]),
           ('Manufacturing', '{Stock User,Manufacturing User,Manufacturing Manager}'::text[]),
           ('Purchase', '{Item Manager,Stock User,Purchase User,Purchase Manager}'::text[]),
           ('Sales', '{Sales User,Stock User,Sales Manager}'::text[])$$,
  'a new organization gets the five ERPNext role profiles'
);

reset role;
insert into public.org_members (org_id, user_id, roles, role_profile, status)
values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000007a2', '{Employee}', 'Sales', 'active');

select is(
  (select roles from public.org_members where user_id = '00000000-0000-0000-0000-0000000007a2'),
  '{Sales Manager,Sales User,Stock User}'::text[],
  'assigning a role profile replaces the member roles'
);

update public.role_profile set roles = '{Sales User}' where org_id = current_setting('test.org')::uuid and name = 'Sales';
 select app.sync_role_permissions(current_setting('test.org')::uuid);
select is(
  (select roles from public.role_profile where org_id = current_setting('test.org')::uuid and name = 'Sales'),
  '{Sales User}'::text[],
  're-syncing never overwrites a profile the tenant edited'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000007a1","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.role_profile_template),
  5,
  'role profile templates are readable by authenticated users'
);

select * from finish();
rollback;
