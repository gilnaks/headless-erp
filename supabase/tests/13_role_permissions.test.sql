begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000013a1', 'perm-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000013a2', 'perm-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000013b1', 'perm-owner-b@test.local', 'authenticated', 'authenticated');

-- Fixture: a submittable doctype and its child table, registered only inside this transaction.
insert into public.doctype_meta (doctype, table_name, module, is_submittable) values ('ZZ Perm Doc', 'zz_perm_doc', 'setup', true);
insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype) values
  ('ZZ Perm Item', 'zz_perm_item', 'setup', true, 'ZZ Perm Doc');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000013b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Perm Org B","slug":"perm-org-b"}') ->> 'id', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000013a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Perm Org A","slug":"perm-org-a"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000013a2', '{Sales User}');

-- Validation
select throws_ok(
  $$insert into public.role_permissions (org_id, role, doctype, can_read) values (current_setting('test.org')::uuid, 'Sales User', 'Nope', true)$$,
  'P0001', 'doctype_unknown: Nope is not a document type', 'unknown doctypes are rejected'
);
select throws_ok(
  $$insert into public.role_permissions (org_id, role, doctype, can_read) values (current_setting('test.org')::uuid, 'Sales User', 'ZZ Perm Item', true)$$,
  'P0001', 'doctype_unknown: ZZ Perm Item is not a document type', 'child doctypes get no permissions of their own'
);
select throws_ok(
  $$update public.role_permissions set can_submit = true
    where org_id = current_setting('test.org')::uuid and role = 'System Manager' and doctype = 'Company'$$,
  'P0001', 'perm_not_submittable: Submit, Cancel and Amend only apply to submittable document types (Company is not)',
  'submit is refused on a non-submittable doctype'
);

insert into public.role_permissions (org_id, role, doctype, can_read, can_write)
  values (current_setting('test.org')::uuid, 'Sales User', 'ZZ Perm Doc', true, true);
select throws_ok(
  $$update public.role_permissions set can_cancel = true
    where org_id = current_setting('test.org')::uuid and role = 'Sales User' and doctype = 'ZZ Perm Doc'$$,
  'P0001', 'perm_dependency: Cancel needs Submit', 'cancel needs submit'
);
select throws_ok(
  $$update public.role_permissions set can_submit = true, can_amend = true
    where org_id = current_setting('test.org')::uuid and role = 'Sales User' and doctype = 'ZZ Perm Doc'$$,
  'P0001', 'perm_dependency: Amend needs Cancel', 'amend needs cancel'
);
select throws_ok(
  $$update public.role_permissions set can_write = false, can_submit = true
    where org_id = current_setting('test.org')::uuid and role = 'Sales User' and doctype = 'ZZ Perm Doc'$$,
  'P0001', 'perm_dependency: Submit, Cancel and Amend need Write', 'submit needs write'
);
select lives_ok(
  $$update public.role_permissions set can_submit = true, can_cancel = true, can_amend = true
    where org_id = current_setting('test.org')::uuid and role = 'Sales User' and doctype = 'ZZ Perm Doc'$$,
  'a consistent submittable rule is accepted'
);

-- Reset one doctype
update public.role_permissions set can_create = false
  where org_id = current_setting('test.org')::uuid and role = 'System Manager' and doctype = 'Company';
insert into public.role_permissions (org_id, role, doctype, can_read)
  values (current_setting('test.org')::uuid, 'Sales User', 'Company', true)
  on conflict (org_id, role, doctype) do update set can_read = true, can_write = true;
update public.role_permissions set can_export = false
  where org_id = current_setting('test.org')::uuid and role = 'System Manager' and doctype = 'System Settings';

select is(
  public.reset_role_permissions(current_setting('test.org')::uuid, 'Company'),
  (select count(*)::int from public.role_permission_template where doctype = 'Company'),
  'reset re-creates one row per default rule'
);
select is(
  (select array_agg(role || ':' || can_read || can_write || can_create || can_delete order by role)
   from public.role_permissions where org_id = current_setting('test.org')::uuid and doctype = 'Company'),
  (select array_agg(role || ':' || can_read || can_write || can_create || can_delete order by role)
   from public.role_permission_template where doctype = 'Company'),
  'reset restores exactly the default rules'
);
select is(
  (select can_export from public.role_permissions
   where org_id = current_setting('test.org')::uuid and role = 'System Manager' and doctype = 'System Settings'),
  false, 'reset leaves other doctypes alone'
);
select throws_ok(
  $$select public.reset_role_permissions(current_setting('test.org')::uuid, 'Role')$$,
  'P0001', 'permission_locked: permissions for Role are fixed to System Manager', 'locked doctypes cannot be reset'
);
select throws_ok(
  $$select public.reset_role_permissions(current_setting('test.org_b')::uuid, 'Company')$$,
  '42501', 'permission_denied: only a System Manager can reset permissions', 'another organization cannot be reset'
);

select is(
  (select array_agg(doctype || ':' || locked order by doctype) from public.permission_doctypes() where doctype in ('Company', 'User', 'ZZ Perm Item')),
  '{Company:false,User:true}'::text[], 'the doctype list flags locked doctypes and skips child tables'
);

-- Members without System Manager
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000013a2","role":"authenticated"}', true);
select throws_ok(
  $$select public.reset_role_permissions(current_setting('test.org')::uuid, 'Company')$$,
  '42501', 'permission_denied: only a System Manager can reset permissions', 'non System Managers cannot reset'
);
update public.role_permissions set can_delete = true
  where org_id = current_setting('test.org')::uuid and role = 'Sales User' and doctype = 'ZZ Perm Doc';
select is(
  (select can_delete from public.role_permissions
   where org_id = current_setting('test.org')::uuid and role = 'Sales User' and doctype = 'ZZ Perm Doc'),
  false, 'non System Managers cannot change rules'
);
select is(
  (select count(*)::int from public.role_permissions where org_id = current_setting('test.org_b')::uuid),
  0, 'rules of another organization are invisible'
);

select * from finish();
rollback;
