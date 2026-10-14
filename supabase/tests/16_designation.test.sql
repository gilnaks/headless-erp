begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000016a1', 'designation-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000016a2', 'designation-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000016a3', 'designation-stock-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000016b1', 'designation-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000016b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Designation Org B","slug":"designation-org-b"}') ->> 'id', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000016a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Designation Org A","slug":"designation-org-a"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000016a2', '{Sales User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000016a3', '{Stock User}');

select is((select count(*)::int from public.designation), 31, 'a new organization gets the 31 ERPNext designations');
select ok(
  exists (select 1 from public.designation where designation_name = 'Chief Executive Officer' and description is null),
  'presets carry the ERPNext names'
);
select throws_ok(
  $$insert into public.designation (org_id, designation_name) values (current_setting('test.org')::uuid, ' accountant ')$$,
  '23505', null, 'designation names are unique per organization (case-insensitive, trimmed)'
);
insert into public.designation (org_id, designation_name, description)
values (current_setting('test.org')::uuid, 'Warehouse Lead', 'Runs the floor');
select is((select count(*)::int from public.designation), 32, 'System Manager adds designations; other organizations stay invisible');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000016a2","role":"authenticated"}', true);
select is((select count(*)::int from public.designation), 32, 'Sales User reads designations');
select throws_ok(
  $$insert into public.designation (org_id, designation_name) values (current_setting('test.org')::uuid, 'Clerk')$$,
  '42501', null, 'Sales User cannot add designations'
);
update public.designation set description = 'x' where designation_name = 'Warehouse Lead';
select is((select description from public.designation where designation_name = 'Warehouse Lead'), 'Runs the floor', 'Sales User cannot edit designations');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000016a3","role":"authenticated"}', true);
select is((select count(*)::int from public.designation), 0, 'roles without a rule see no designations');

select * from finish();
rollback;
