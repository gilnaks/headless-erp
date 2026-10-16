begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- Fixtures (as postgres)
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a2', 'sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'owner-b@test.local', 'authenticated', 'authenticated');

insert into public.organizations (id, slug, name, country, default_currency) values
  ('10000000-0000-0000-0000-00000000000a', 'org-a', 'Org A', 'United States', 'USD'),
  ('10000000-0000-0000-0000-00000000000b', 'org-b', 'Org B', 'Netherlands', 'EUR');

do $$ begin perform app.sync_role_permissions(); end $$;

insert into public.org_members (org_id, user_id, roles, is_owner) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', '{}', true),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', '{Sales User}', false),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', '{}', true);

select ok(
  exists (select 1 from public.role_permissions
          where org_id = '10000000-0000-0000-0000-00000000000a' and role = 'System Manager'
            and doctype = 'Company' and can_create and can_delete),
  'sync_role_permissions seeds Company permissions into existing orgs'
);

-- As owner A (System Manager)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

insert into public.companies (id, org_id, company_name, is_group) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', '  Acme Holding ', true);

select results_eq(
  $$select name, abbr, default_currency, country, chart_of_accounts, create_chart_of_accounts_based_on, reporting_currency
      from public.companies where id = '20000000-0000-0000-0000-000000000001'$$,
  $$values ('Acme Holding', 'AH', 'USD', 'United States', 'Standard', 'Standard Template', 'USD')$$,
  'company defaults: trimmed name, initials abbr, org currency/country, Standard chart, reporting currency'
);

select is(
  (select valuation_method || '/' || enable_perpetual_inventory::text from public.companies where id = '20000000-0000-0000-0000-000000000001'),
  'FIFO/true',
  'valuation_method FIFO and perpetual inventory on by default'
);

select throws_ok(
  $$insert into public.companies (org_id, company_name) values ('10000000-0000-0000-0000-00000000000a', 'Alpha Hotel')$$,
  'P0001', 'abbr_taken: Abbreviation already used for another company', 'abbreviation must be unique per org (case-insensitive)'
);

insert into public.companies (org_id, company_name, abbr) values ('10000000-0000-0000-0000-00000000000a', 'Blank', '   ');
select is((select abbr from public.companies where name = 'Blank'), 'B', 'blank abbreviation falls back to initials');

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-00000000000a', 'Leaf Co', 'LC');

select throws_ok(
  $$insert into public.companies (org_id, company_name, parent_id) values
      ('10000000-0000-0000-0000-00000000000a', 'Under Leaf', '20000000-0000-0000-0000-000000000002')$$,
  'P0001', 'invalid_parent: Parent Company must be a group company', 'parent company must be a group'
);

insert into public.companies (id, org_id, company_name, abbr, parent_id, default_currency, is_group) values
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-00000000000a', 'Acme Europe', 'AE',
   '20000000-0000-0000-0000-000000000001', 'EUR', true);

select results_eq(
  $$select create_chart_of_accounts_based_on, existing_company_id, chart_of_accounts, reporting_currency
      from public.companies where id = '20000000-0000-0000-0000-000000000003'$$,
  $$values ('Existing Company', '20000000-0000-0000-0000-000000000001'::uuid, null::text, 'USD')$$,
  'child company copies parent chart and reporting currency'
);

select throws_ok(
  $$insert into public.companies (org_id, company_name, abbr, create_chart_of_accounts_based_on)
    values ('10000000-0000-0000-0000-00000000000a', 'No Source', 'NS', 'Existing Company')$$,
  'P0001', 'coa_input: Please select Existing Company for creating Chart of Accounts', 'Existing Company chart needs a source company'
);

insert into public.companies (id, org_id, company_name, abbr, parent_id) values
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-00000000000a', 'Acme NL', 'ANL',
   '20000000-0000-0000-0000-000000000003');

select ok(
  (select c.path <@ p.path and extensions.nlevel(c.path) = 3
     from public.companies c, public.companies p
    where c.id = '20000000-0000-0000-0000-000000000004' and p.id = '20000000-0000-0000-0000-000000000001'),
  'grandchild path sits under the root company'
);

insert into public.companies (id, org_id, company_name, abbr, is_group) values
  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-00000000000a', 'Other Group', 'OG', true);
update public.companies set parent_id = '20000000-0000-0000-0000-000000000005'
 where id = '20000000-0000-0000-0000-000000000003';

select ok(
  (select c.path <@ g.path and not c.path <@ h.path
     from public.companies c, public.companies g, public.companies h
    where c.id = '20000000-0000-0000-0000-000000000004'
      and g.id = '20000000-0000-0000-0000-000000000005'
      and h.id = '20000000-0000-0000-0000-000000000001'),
  're-parenting moves descendants'
);

select throws_ok(
  $$update public.companies set parent_id = '20000000-0000-0000-0000-000000000003' where id = '20000000-0000-0000-0000-000000000005'$$,
  'P0001', 'invalid_parent: a company cannot be moved under its own descendant', 'tree cycles are rejected'
);

select throws_ok(
  $$update public.companies set is_group = false where id = '20000000-0000-0000-0000-000000000003'$$,
  'P0001', 'has_children: Company has child nodes and cannot be converted to a non-group', 'group with children cannot become a leaf'
);

select throws_ok(
  $$delete from public.companies where id = '20000000-0000-0000-0000-000000000003'$$,
  '23503', null, 'company with children cannot be deleted'
);

update public.companies set path = 'tampered' where id = '20000000-0000-0000-0000-000000000004';
select ok(
  (select c.path <@ g.path from public.companies c, public.companies g
    where c.id = '20000000-0000-0000-0000-000000000004' and g.id = '20000000-0000-0000-0000-000000000005'),
  'path cannot be written directly'
);

-- Chart seeding fills the SDBNB account, so the guard only trips after it is cleared.
update public.companies set stock_delivered_but_not_billed_id = null where id = '20000000-0000-0000-0000-000000000002';
select throws_ok(
  $$update public.companies set enable_stock_delivered_but_not_billed = true where id = '20000000-0000-0000-0000-000000000002'$$,
  'P0001', 'sdbnb_account_required: Please select Stock Delivered But Not Billed Account', 'SDBNB needs an account once enabled'
);

-- As Sales User A (read only)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);

select is((select count(*)::int from public.companies), 6, 'Sales User reads all org companies');

select throws_ok(
  $$insert into public.companies (org_id, company_name, abbr) values ('10000000-0000-0000-0000-00000000000a', 'Sneaky', 'SN')$$,
  '42501', null, 'Sales User cannot create companies'
);

update public.companies set tax_id = 'hacked' where id = '20000000-0000-0000-0000-000000000002';
select is((select tax_id from public.companies where id = '20000000-0000-0000-0000-000000000002'), null, 'Sales User cannot update companies');

-- User Permission restricts Sales User to Leaf Co
reset role;
insert into public.user_permissions (org_id, user_id, doctype, record_id) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'Company', '20000000-0000-0000-0000-000000000002');
set local role authenticated;

select results_eq('select name from public.companies', array['Leaf Co'], 'User Permission on Company limits visible companies');

-- As owner B
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);

select is((select count(*)::int from public.companies), 0, 'other org sees no companies of org A');

select lives_ok(
  $$insert into public.companies (org_id, company_name) values ('10000000-0000-0000-0000-00000000000b', 'Acme Holding')$$,
  'company names and abbreviations are unique per org, not globally'
);

select throws_ok(
  $$insert into public.companies (org_id, company_name, abbr, is_group, parent_id) values
      ('10000000-0000-0000-0000-00000000000b', 'Cross Org Child', 'COC', false, '20000000-0000-0000-0000-000000000001')$$,
  'P0001', 'invalid_parent: parent Company not found', 'cannot attach to another org''s company'
);

select * from finish();
rollback;
