begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000024a1', 'pf-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000024a2', 'pf-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000024b1', 'pf-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000024b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"PF Org B","slug":"pf-org-b"}') ->> 'id', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000024a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"PF Org A","slug":"pf-org-a"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000024a2', '{Sales User}');

-- Seeding (set_default_print_formats)
select results_eq(
  $$select name, template_key, is_standard, is_default, disabled from public.print_format where doc_type = 'Company'$$,
  $$values ('Company Standard', 'record', true, true, false)$$,
  'every organization gets "<Doctype> Standard" as the default format'
);
select is(
  (select count(*)::int from public.print_format where is_standard),
  (select count(*)::int from public.doctype_meta m where app.is_printable(m.doctype)),
  'one standard format per printable doctype'
);
select is(
  (select count(*)::int from public.print_format where doc_type in ('Holiday', 'Print Settings', 'User', 'Currency')),
  0, 'child tables, singles, members and global tables get no format'
);

-- Standard formats are locked except Default / Disabled
select throws_ok(
  $$insert into public.print_format (org_id, name, doc_type, is_standard) values (current_setting('test.org')::uuid, 'Fake Standard', 'Branch', true)$$,
  'P0001', 'print_format_standard: Standard Print Formats are created by the system',
  'users cannot create standard formats'
);
select throws_ok(
  $$update public.print_format set name = 'Renamed' where doc_type = 'Company' and is_standard$$,
  'P0001', 'print_format_standard: Standard Print Format cannot be updated; only Default and Disabled can change',
  'standard formats cannot be renamed'
);
select throws_ok(
  $$update public.print_format set disabled = true where doc_type = 'Company' and is_standard$$,
  'P0001', 'print_format_disabled_default: A disabled Print Format cannot be the default',
  'the default format cannot be disabled'
);
insert into public.print_format (id, org_id, name, doc_type, is_default) values
  ('00000000-0000-0000-0000-0000000024e1', current_setting('test.org')::uuid, ' Company Compact ', 'Company', true);
select results_eq(
  $$select name from public.print_format where doc_type = 'Company' and is_default$$,
  $$values ('Company Compact')$$,
  'a new default replaces the previous one (one default per doctype)'
);
update public.print_format set disabled = true where doc_type = 'Company' and is_standard;
select ok((select disabled from public.print_format where doc_type = 'Company' and is_standard), 'standard formats can be disabled once not the default');
select throws_ok(
  $$delete from public.print_format where doc_type = 'Company' and is_standard$$,
  'P0001', 'print_format_standard: Standard Print Format cannot be deleted',
  'standard formats cannot be deleted'
);
delete from public.print_format where id = '00000000-0000-0000-0000-0000000024e1';
select is((select count(*)::int from public.print_format where doc_type = 'Company'), 1, 'custom formats can be deleted');
select throws_ok(
  $$insert into public.print_format (org_id, name, doc_type) values (current_setting('test.org')::uuid, 'Holiday Rows', 'Holiday')$$,
  'P0001', 'print_format_doc_type: Holiday cannot be printed',
  'child tables cannot have print formats'
);

-- RLS
select is((select count(*)::int from public.print_format where org_id = current_setting('test.org_b')::uuid), 0, 'formats of another organization are invisible');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000024a2","role":"authenticated"}', true);
select ok((select count(*) from public.print_format) > 0, 'every role reads print formats');
select throws_ok(
  $$insert into public.print_format (org_id, name, doc_type) values (current_setting('test.org')::uuid, 'Sales Format', 'Branch')$$,
  '42501', null, 'non System Managers cannot add print formats'
);
update public.print_format set is_default = false where doc_type = 'Branch';
select ok((select is_default from public.print_format where doc_type = 'Branch'), 'non System Managers cannot change the default');

-- Doctypes registered later get their standard format in every organization
reset role;
create table public.pf_test_doctype (id uuid primary key, org_id uuid not null, title text);
insert into public.doctype_meta (doctype, table_name, module, title_field) values ('PF Test Doctype', 'pf_test_doctype', 'setup', 'title');
select is(
  (select count(*)::int from public.print_format where doc_type = 'PF Test Doctype' and org_id in (current_setting('test.org')::uuid, current_setting('test.org_b')::uuid)),
  2, 'registering a doctype seeds its standard format for every organization'
);

select * from finish();
rollback;
