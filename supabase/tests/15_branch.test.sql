begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000015a1', 'branch-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000015a2', 'branch-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000015b1', 'branch-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000015b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Branch Org B","slug":"branch-org-b"}') ->> 'id', true);
insert into public.branch (org_id, branch) values (current_setting('test.org_b')::uuid, 'Head Office');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000015a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Branch Org A","slug":"branch-org-a"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000015a2', '{Sales User}');

insert into public.branch (org_id, branch) values (current_setting('test.org')::uuid, '  Head Office ');
select is((select branch from public.branch where org_id = current_setting('test.org')::uuid), 'Head Office', 'the name is trimmed');
select throws_ok(
  $$insert into public.branch (org_id, branch) values (current_setting('test.org')::uuid, 'head office')$$,
  '23505', null, 'branch names are unique per organization (case-insensitive)'
);
select is((select count(*)::int from public.branch), 1, 'branches of another organization are invisible');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000015a2","role":"authenticated"}', true);
select is((select count(*)::int from public.branch), 1, 'every role reads branches');
select throws_ok(
  $$insert into public.branch (org_id, branch) values (current_setting('test.org')::uuid, 'Warehouse')$$,
  '42501', null, 'non System Managers cannot add branches'
);
update public.branch set branch = 'Renamed' where org_id = current_setting('test.org')::uuid;
select is((select branch from public.branch where org_id = current_setting('test.org')::uuid), 'Head Office', 'non System Managers cannot rename branches');
delete from public.branch where org_id = current_setting('test.org')::uuid;
select is((select count(*)::int from public.branch), 1, 'non System Managers cannot delete branches');

select * from finish();
rollback;
