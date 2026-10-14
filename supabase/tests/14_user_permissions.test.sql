begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000014a1', 'up-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000014a2', 'up-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000014a3', 'up-outsider@test.local', 'authenticated', 'authenticated');

-- Fixture: a document type a permission can be scoped to.
insert into public.doctype_meta (doctype, table_name, module) values ('ZZ UP Doc', 'zz_up_doc', 'setup');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000014a1","role":"authenticated"}', true);
select set_config('test.org', public.create_organization('{"name":"UP Org A","slug":"up-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', '{Sales User}');

-- Group > Child > Grandchild, plus a sibling root
insert into public.companies (id, org_id, company_name, abbr, is_group) values
  ('00000000-0000-0000-0000-0000000014c1', current_setting('test.org')::uuid, 'UP Group', 'UPG', true),
  ('00000000-0000-0000-0000-0000000014c4', current_setting('test.org')::uuid, 'UP Other', 'UPO', false);
insert into public.companies (id, org_id, company_name, abbr, is_group, parent_id) values
  ('00000000-0000-0000-0000-0000000014c2', current_setting('test.org')::uuid, 'UP Child', 'UPC', true, '00000000-0000-0000-0000-0000000014c1');
insert into public.companies (id, org_id, company_name, abbr, is_group, parent_id) values
  ('00000000-0000-0000-0000-0000000014c3', current_setting('test.org')::uuid, 'UP Grandchild', 'UPGC', false, '00000000-0000-0000-0000-0000000014c2');

-- Validation (as System Manager)
select throws_ok(
  $$insert into public.user_permissions (org_id, user_id, doctype, record_id)
    values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a3', 'Company', '00000000-0000-0000-0000-0000000014c1')$$,
  'P0001', 'user_not_member: the user is not a member of this organization', 'only members can be restricted'
);
select throws_ok(
  $$insert into public.user_permissions (org_id, user_id, doctype, record_id)
    values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Role', '00000000-0000-0000-0000-0000000014c1')$$,
  'P0001', 'doctype_not_allowed: User Permissions cannot restrict Role', 'only user permission targets can be restricted'
);
select throws_ok(
  $$insert into public.user_permissions (org_id, user_id, doctype, record_id)
    values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Company', '00000000-0000-0000-0000-0000000014ff')$$,
  'P0001', 'record_unknown: Company not found', 'the record must exist in the organization'
);
select throws_ok(
  $$insert into public.user_permissions (org_id, user_id, doctype, record_id, applicable_for)
    values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Company', '00000000-0000-0000-0000-0000000014c1', 'Nope')$$,
  'P0001', 'applicable_for_unknown: Nope is not a document type', 'applicable for must be a document type'
);

insert into public.user_permissions (org_id, user_id, doctype, record_id, is_default) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Company', '00000000-0000-0000-0000-0000000014c1', true);
select throws_ok(
  $$insert into public.user_permissions (org_id, user_id, doctype, record_id, is_default)
    values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Company', '00000000-0000-0000-0000-0000000014c4', true)$$,
  'P0001', 'default_exists: this user already has a default Company', 'one default per user and doctype'
);
select throws_ok(
  $$insert into public.user_permissions (org_id, user_id, doctype, record_id)
    values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Company', '00000000-0000-0000-0000-0000000014c1')$$,
  '23505', null, 'duplicates are rejected'
);
select is(
  (select applicable_for is null from public.user_permissions
   where user_id = '00000000-0000-0000-0000-0000000014a2' and record_id = '00000000-0000-0000-0000-0000000014c1'),
  true, 'blank applicable for means every document type'
);

-- As the restricted user: the group and its descendants
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000014a2","role":"authenticated"}', true);
select results_eq(
  $$select company_name::text from public.companies order by company_name$$,
  array['UP Child', 'UP Grandchild', 'UP Group'], 'a permission on a group company includes its descendants'
);
select is(
  app.company_allowed(current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014c3', 'Sales Invoice'),
  true, 'descendants are allowed for other document types too'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000014a1","role":"authenticated"}', true);
update public.user_permissions set hide_descendants = true
  where user_id = '00000000-0000-0000-0000-0000000014a2' and record_id = '00000000-0000-0000-0000-0000000014c1';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000014a2","role":"authenticated"}', true);
select results_eq(
  $$select company_name::text from public.companies order by company_name$$,
  array['UP Group'], 'hide descendants keeps only the record itself'
);

-- applicable_for: a row for Sales Invoice does not restrict the Company list
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000014a1","role":"authenticated"}', true);
delete from public.user_permissions where user_id = '00000000-0000-0000-0000-0000000014a2';
insert into public.user_permissions (org_id, user_id, doctype, record_id, applicable_for) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Company', '00000000-0000-0000-0000-0000000014c4', 'ZZ UP Doc');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000014a2","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.companies where company_name like 'UP %'),
  4, 'a permission applicable to another document type leaves the Company list alone'
);
select is(
  app.company_allowed(current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014c1', 'ZZ UP Doc'),
  false, 'the scoped document type is restricted'
);

-- Non System Managers
select is(
  (select count(*)::int from public.user_permissions where user_id = '00000000-0000-0000-0000-0000000014a2'),
  1, 'users read their own restrictions'
);
select throws_ok(
  $$insert into public.user_permissions (org_id, user_id, doctype, record_id)
    values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000014a2', 'Company', '00000000-0000-0000-0000-0000000014c1')$$,
  '42501', null, 'non System Managers cannot add user permissions'
);
delete from public.user_permissions where user_id = '00000000-0000-0000-0000-0000000014a2';
select is(
  (select count(*)::int from public.user_permissions where user_id = '00000000-0000-0000-0000-0000000014a2'),
  1, 'non System Managers cannot remove user permissions'
);

select * from finish();
rollback;
