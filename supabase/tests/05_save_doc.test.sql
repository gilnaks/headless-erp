begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000005a1', 'save-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000005a2', 'save-sales@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000005b1', 'save-other@test.local', 'authenticated', 'authenticated');

insert into public.organizations (id, slug, name, country, default_currency) values
  ('10000000-0000-0000-0000-0000000005aa', 'save-a', 'Save A', 'United States', 'USD'),
  ('10000000-0000-0000-0000-0000000005bb', 'save-b', 'Save B', 'Netherlands', 'EUR');

do $$ begin perform app.sync_role_permissions(); end $$;

insert into public.org_members (org_id, user_id, roles, is_owner) values
  ('10000000-0000-0000-0000-0000000005aa', '00000000-0000-0000-0000-0000000005a1', '{System Manager}', true),
  ('10000000-0000-0000-0000-0000000005aa', '00000000-0000-0000-0000-0000000005a2', '{Sales User}', false),
  ('10000000-0000-0000-0000-0000000005bb', '00000000-0000-0000-0000-0000000005b1', '{System Manager}', true);

-- Fixture: a submittable doctype with a child table, registered only inside this transaction.
create table public.zz_test_doc (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  name text,
  title text not null default 'Untitled',
  remarks text,
  docstatus smallint not null default 0,
  unique (org_id, id)
);
create table public.zz_test_doc_item (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  parent_id uuid not null references public.zz_test_doc (id) on delete cascade,
  idx int not null,
  item text not null,
  qty numeric(21, 9) not null default 0,
  unique (parent_id, idx) deferrable initially deferred
);
alter table public.zz_test_doc enable row level security;
alter table public.zz_test_doc_item enable row level security;
create policy zz_all on public.zz_test_doc for all to authenticated
  using (org_id = any ((select app.orgs_with_perm('ZZ Test Doc', 'read'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('ZZ Test Doc', 'write'))::uuid[]));
create policy zz_item_all on public.zz_test_doc_item for all to authenticated
  using (org_id = any ((select app.orgs_with_perm('ZZ Test Doc', 'read'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('ZZ Test Doc', 'write'))::uuid[]));
grant all on public.zz_test_doc, public.zz_test_doc_item to authenticated;

insert into public.doctype_meta (doctype, table_name, module, is_submittable, allow_on_submit) values
  ('ZZ Test Doc', 'zz_test_doc', 'setup', true, '{remarks}');
insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field) values
  ('ZZ Test Doc Item', 'zz_test_doc_item', 'setup', true, 'ZZ Test Doc', 'items');
insert into public.role_permissions (org_id, role, doctype, can_read, can_write, can_create, can_delete) values
  ('10000000-0000-0000-0000-0000000005aa', 'System Manager', 'ZZ Test Doc', true, true, true, true);

------------------------------------------------------------------------------------------------------------------------
-- Owner A: Company (master, tree)
------------------------------------------------------------------------------------------------------------------------
create temp table _ids (k text primary key, id uuid);
grant all on _ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000005a1","role":"authenticated"}', true);

insert into _ids select 'holding', (public.save_doc('Company', jsonb_build_object(
  'org_id', '10000000-0000-0000-0000-0000000005aa', 'company_name', 'Save Holding', 'abbr', 'SH', 'is_group', true,
  'id', 'not-a-uuid', 'created_by', '00000000-0000-0000-0000-0000000005b1', 'path', 'evil', 'bogus_column', 1
)) ->> 'id')::uuid;

select results_eq(
  $$select name, abbr, is_group, default_currency, created_by from public.companies where id = (select id from _ids where k = 'holding')$$,
  $$values ('Save Holding', 'SH', true, 'USD', '00000000-0000-0000-0000-0000000005a1'::uuid)$$,
  'insert: fields saved, defaults applied, system columns and unknown keys ignored'
);

insert into _ids select 'child', (public.save_doc('Company', jsonb_build_object(
  'org_id', '10000000-0000-0000-0000-0000000005aa', 'company_name', 'Save Child', 'abbr', 'SC',
  'parent_id', (select id from _ids where k = 'holding')
)) ->> 'id')::uuid;

select is(
  (select parent_id from public.companies where id = (select id from _ids where k = 'child')),
  (select id from _ids where k = 'holding'),
  'tree parent (parent_id) is writable on masters'
);

select is(
  public.save_doc('Company', jsonb_build_object('id', (select id from _ids where k = 'child'), 'tax_id', 'NL123', 'org_id', '10000000-0000-0000-0000-0000000005bb')) ->> 'name',
  'Save Child',
  'update returns the document name'
);

select results_eq(
  $$select tax_id, abbr, org_id from public.companies where id = (select id from _ids where k = 'child')$$,
  $$values ('NL123', 'SC', '10000000-0000-0000-0000-0000000005aa'::uuid)$$,
  'update touches only the keys sent and never moves the row to another org'
);

select throws_ok(
  format($$select public.save_doc('Company', '{"id":"%s","abbr":"SH"}')$$, (select id from _ids where k = 'child')),
  'P0001', 'abbr_taken: Abbreviation already used for another company',
  'doctype validations still run'
);

select throws_ok(
  $$select public.save_doc('Nope', '{}')$$,
  'P0001', 'doctype_unknown: Nope is not a document type', 'unknown doctype is rejected'
);

select throws_ok(
  $$select public.save_doc('ZZ Test Doc Item', '{}')$$,
  'P0001', 'doctype_unknown: ZZ Test Doc Item is not a document type', 'child doctypes cannot be saved on their own'
);

select throws_ok(
  $$select public.save_doc('Company', '{"company_name":"No Org"}')$$,
  'P0001', 'org_required: organization is required', 'insert needs an organization'
);

select throws_ok(
  $$select public.save_doc('Company', '{"id":"30000000-0000-0000-0000-000000000000","tax_id":"x"}')$$,
  'P0001', 'not_found: Company not found', 'missing document'
);

------------------------------------------------------------------------------------------------------------------------
-- Owner A: submittable fixture with children
------------------------------------------------------------------------------------------------------------------------
insert into _ids select 'doc', (public.save_doc('ZZ Test Doc', jsonb_build_object(
  'org_id', '10000000-0000-0000-0000-0000000005aa', 'title', 'First', 'name', 'HACK-001', 'docstatus', 1,
  'items', jsonb_build_array(jsonb_build_object('item', 'A', 'qty', 1), jsonb_build_object('item', 'B', 'qty', 2))
)) ->> 'id')::uuid;

select results_eq(
  $$select name, docstatus from public.zz_test_doc where id = (select id from _ids where k = 'doc')$$,
  $$values (null::text, 0::smallint)$$,
  'submittable: name and docstatus cannot be set by save'
);

select results_eq(
  $$select idx, item, qty::int, org_id from public.zz_test_doc_item where parent_id = (select id from _ids where k = 'doc') order by idx$$,
  $$values (1, 'A', 1, '10000000-0000-0000-0000-0000000005aa'::uuid), (2, 'B', 2, '10000000-0000-0000-0000-0000000005aa'::uuid)$$,
  'child rows inserted with idx and parent org'
);

insert into _ids select 'row_b', id from public.zz_test_doc_item where parent_id = (select id from _ids where k = 'doc') and item = 'B';

select lives_ok(
  format($$select public.save_doc('ZZ Test Doc', '{"id":"%s","items":[{"id":"%s","item":"B2","qty":5},{"item":"C"}]}')$$,
    (select id from _ids where k = 'doc'), (select id from _ids where k = 'row_b')),
  'children can be reordered, edited, added and removed in one save'
);

select results_eq(
  $$select idx, item, qty::int from public.zz_test_doc_item where parent_id = (select id from _ids where k = 'doc') order by idx$$,
  $$values (1, 'B2', 5), (2, 'C', 0)$$,
  'child rows replaced: A removed, B edited and moved to idx 1, C added with defaults'
);

select is(
  (select id from public.zz_test_doc_item where parent_id = (select id from _ids where k = 'doc') and idx = 1),
  (select id from _ids where k = 'row_b'),
  'edited child keeps its id'
);

select is(
  (select title from public.zz_test_doc where id = (select id from _ids where k = 'doc')),
  'First',
  'saving only children leaves header fields alone'
);

reset role;
update public.zz_test_doc set docstatus = 1 where id = (select id from _ids where k = 'doc');
set local role authenticated;

select lives_ok(
  format($$select public.save_doc('ZZ Test Doc', '{"id":"%s","title":"First","remarks":"late note"}')$$, (select id from _ids where k = 'doc')),
  'submitted: allow_on_submit fields change (unchanged fields may be resent)'
);

select is(
  (select remarks from public.zz_test_doc where id = (select id from _ids where k = 'doc')),
  'late note',
  'allow_on_submit field updated'
);

select throws_ok(
  format($$select public.save_doc('ZZ Test Doc', '{"id":"%s","title":"Changed"}')$$, (select id from _ids where k = 'doc')),
  'P0001', 'update_after_submit: Not allowed to change title after submission',
  'submitted: other fields are locked'
);

select throws_ok(
  format($$select public.delete_doc('ZZ Test Doc', '%s')$$, (select id from _ids where k = 'doc')),
  'P0001', 'delete_submitted: Submitted or cancelled ZZ Test Doc cannot be deleted',
  'submitted documents cannot be deleted'
);

------------------------------------------------------------------------------------------------------------------------
-- Sales User A (Company read only) and owner B (other org)
------------------------------------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000005a2","role":"authenticated"}', true);

select throws_ok(
  format($$select public.save_doc('Company', '{"id":"%s","tax_id":"hacked"}')$$, (select id from _ids where k = 'child')),
  '42501', 'permission_denied: not permitted to change this Company',
  'reader without write permission cannot update'
);

select throws_ok(
  $$select public.save_doc('Company', '{"org_id":"10000000-0000-0000-0000-0000000005aa","company_name":"Sneaky","abbr":"SN"}')$$,
  '42501', null, 'reader without create permission cannot insert'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000005b1","role":"authenticated"}', true);

select throws_ok(
  format($$select public.save_doc('Company', '{"id":"%s","tax_id":"x"}')$$, (select id from _ids where k = 'child')),
  'P0001', 'not_found: Company not found', 'another org''s document is invisible'
);

select throws_ok(
  $$select public.save_doc('Company', '{"org_id":"10000000-0000-0000-0000-0000000005aa","company_name":"Cross","abbr":"CR"}')$$,
  '42501', null, 'cannot insert into another org'
);

-- Owner A deletes a leaf company
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000005a1","role":"authenticated"}', true);
select lives_ok(
  format($$select public.delete_doc('Company', '%s')$$, (select id from _ids where k = 'child')),
  'owner deletes a draft/master document'
);

select * from finish();
rollback;
