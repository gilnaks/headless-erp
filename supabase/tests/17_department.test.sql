begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000017a1', 'dept-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000017a2', 'dept-accounts-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000017a3', 'dept-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000017b1', 'dept-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000017b1","role":"authenticated"}', true);
select set_config('test.org_b', public.create_organization('{"name":"Dept Org B","slug":"dept-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.companies (org_id, company_name, abbr) values (current_setting('test.org_b')::uuid, 'Dept B', 'DB');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000017a1","role":"authenticated"}', true);
select set_config('test.org', public.create_organization('{"name":"Dept Org A","slug":"dept-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000017a2', '{Accounts User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000017a3', '{Sales User}');

select is(
  (select array_agg(name) from public.department where parent_id is null),
  array['All Departments'],
  'a new organization gets the All Departments root (and sees no other organization''s)'
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000017c1', current_setting('test.org')::uuid, 'Dept Alpha', 'DA');

select is(
  (select count(*)::int from public.department where company_id = '00000000-0000-0000-0000-0000000017c1'),
  13, 'a new company gets the 13 ERPNext departments'
);
select is(
  (select parent_id from public.department where name = 'Accounts - DA'),
  (select id from public.department where org_id = current_setting('test.org')::uuid and parent_id is null),
  'company departments are named "<department> - <abbr>" under the root'
);

insert into public.department (org_id, department_name, company_id, is_group)
values (current_setting('test.org')::uuid, ' Engineering ', '00000000-0000-0000-0000-0000000017c1', true);
select is(
  (select (d.name, d.parent_id = r.id)::text from public.department d, public.department r
    where d.department_name = 'Engineering' and r.org_id = d.org_id and r.parent_id is null),
  '("Engineering - DA",t)', 'an empty parent becomes the root; the name is trimmed and suffixed'
);

insert into public.department (org_id, department_name, company_id, parent_id)
  select current_setting('test.org')::uuid, 'Platform', '00000000-0000-0000-0000-0000000017c1', id
    from public.department where name = 'Engineering - DA';
select ok(
  (select p.path operator(extensions.<@) g.path from public.department p, public.department g
    where p.name = 'Platform - DA' and g.name = 'Engineering - DA'),
  'children sit under their group'
);

update public.department set department_name = 'Platform Team' where name = 'Platform - DA';
select ok(exists (select 1 from public.department where name = 'Platform Team - DA'), 'renaming keeps the company suffix');

update public.companies set abbr = 'DAL' where id = '00000000-0000-0000-0000-0000000017c1';
select ok(exists (select 1 from public.department where name = 'Platform Team - DAL'), 'a new company abbreviation renames its departments');

select throws_ok(
  $$insert into public.department (org_id, department_name, company_id) values (current_setting('test.org')::uuid, 'Sales', '00000000-0000-0000-0000-0000000017c1')$$,
  '23505', null, 'department names are unique per organization'
);
select throws_ok(
  $$insert into public.department (org_id, department_name) values (current_setting('test.org')::uuid, 'Orphan')$$,
  'P0001', 'company_required: Company is mandatory', 'departments other than the root need a company'
);
select throws_ok(
  $$insert into public.department (org_id, department_name, company_id, parent_id)
    select current_setting('test.org')::uuid, 'Nested', '00000000-0000-0000-0000-0000000017c1', id
      from public.department where name = 'Sales - DAL'$$,
  'P0001', null, 'the parent must be a group'
);
select throws_ok(
  $$update public.department set department_name = 'Everything' where org_id = current_setting('test.org')::uuid and parent_id is null$$,
  'P0001', 'department_root: The root department cannot be changed', 'the root cannot be renamed'
);
select throws_ok(
  $$delete from public.department where org_id = current_setting('test.org')::uuid and parent_id is null$$,
  'P0001', 'department_root: The root department cannot be deleted', 'the root cannot be deleted'
);
select throws_ok(
  $$delete from public.department where name = 'Engineering - DAL'$$,
  '23503', null, 'a group with children cannot be deleted'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000017a2","role":"authenticated"}', true);
select is((select count(*)::int from public.department), 16, 'Accounts User reads departments');
select throws_ok(
  $$insert into public.department (org_id, department_name, company_id) values (current_setting('test.org')::uuid, 'Audit', '00000000-0000-0000-0000-0000000017c1')$$,
  '42501', null, 'Accounts User cannot add departments'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000017a3","role":"authenticated"}', true);
select is((select count(*)::int from public.department), 0, 'roles without a rule see no departments');

reset role;
delete from public.organizations where id = current_setting('test.org_b')::uuid;
select is((select count(*)::int from public.department where org_id = current_setting('test.org_b')::uuid), 0, 'deleting an organization removes its department tree');

select * from finish();
rollback;
