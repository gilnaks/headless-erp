begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000051a1', 'tax-tpl-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000051a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Tax Template Org","slug":"tax-template-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = '{System Manager,Accounts Manager}'
 where user_id = '00000000-0000-0000-0000-0000000051a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000051a1","role":"authenticated"}', true);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000051c1', current_setting('test.org')::uuid, 'Tax Co', 'TC'),
  ('20000000-0000-0000-0000-0000000051c2', current_setting('test.org')::uuid, 'Other Co', 'OC');

select set_config(
  'test.acct',
  (
    select a.id::text from public.account a
     where a.company_id = '20000000-0000-0000-0000-0000000051c1' and a.is_group = false
     order by a.name
     limit 1
  ),
  true
);
select set_config(
  'test.acct2',
  (
    select a.id::text from public.account a
     where a.company_id = '20000000-0000-0000-0000-0000000051c2' and a.is_group = false
     order by a.name
     limit 1
  ),
  true
);
select set_config(
  'test.cc2',
  (
    select c.id::text from public.cost_center c
     where c.company_id = '20000000-0000-0000-0000-0000000051c2' and c.is_group = false
     order by c.name
     limit 1
  ),
  true
);

insert into public.tax_category (id, org_id, title)
values ('30000000-0000-0000-0000-0000000051e1', current_setting('test.org')::uuid, 'VAT Cat');

insert into public.sales_taxes_and_charges_template (id, org_id, title, company_id)
values (
  '30000000-0000-0000-0000-0000000051d1',
  current_setting('test.org')::uuid,
  'VAT',
  '20000000-0000-0000-0000-0000000051c1'
);
insert into public.purchase_taxes_and_charges_template (id, org_id, title, company_id)
values (
  '30000000-0000-0000-0000-0000000051d2',
  current_setting('test.org')::uuid,
  'GST',
  '20000000-0000-0000-0000-0000000051c1'
);

select is(
  (select name from public.sales_taxes_and_charges_template where id = '30000000-0000-0000-0000-0000000051d1'),
  'VAT - TC',
  'the sales template name is the title and the company abbreviation'
);
select is(
  (select name from public.purchase_taxes_and_charges_template where id = '30000000-0000-0000-0000-0000000051d2'),
  'GST - TC',
  'the purchase template name is the title and the company abbreviation'
);

select throws_ok(
  $$insert into public.sales_taxes_and_charges_template (org_id, title, company_id, disabled, is_default)
    values (current_setting('test.org')::uuid, 'Closed', '20000000-0000-0000-0000-0000000051c1', true, true)$$,
  'P0001',
  'tax_template_default: Disabled template must not be default template',
  'a disabled default is rejected'
);

insert into public.sales_taxes_and_charges_template (id, org_id, title, company_id, tax_category_id)
values (
  '30000000-0000-0000-0000-0000000051d3',
  current_setting('test.org')::uuid,
  'Standard',
  '20000000-0000-0000-0000-0000000051c1',
  '30000000-0000-0000-0000-0000000051e1'
);
select throws_ok(
  $$insert into public.sales_taxes_and_charges_template (org_id, title, company_id, tax_category_id)
    values (
      current_setting('test.org')::uuid,
      'Other',
      '20000000-0000-0000-0000-0000000051c1',
      '30000000-0000-0000-0000-0000000051e1'
    )$$,
  'P0001',
  'tax_template_category: Only one template is allowed with each tax category',
  'a second enabled template with the same tax category is rejected'
);

select throws_ok(
  $$insert into public.sales_taxes_and_charges (org_id, parent_id, idx, charge_type, account_head_id, description)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000051d1',
      1,
      'On Previous Row Amount',
      current_setting('test.acct')::uuid,
      'VAT'
    )$$,
  'P0001',
  'tax_row_id: Cannot select charge type as On Previous Row Amount or On Previous Row Total for first row',
  'a previous-row charge on the first row is rejected'
);

select throws_ok(
  $$insert into public.purchase_taxes_and_charges (
      org_id, parent_id, idx, charge_type, account_head_id, description, included_in_print_rate
    ) values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000051d2',
      1,
      'Actual',
      current_setting('test.acct')::uuid,
      'GST',
      true
    )$$,
  'P0001',
  'tax_inclusive_actual: Charge of type Actual in row 1 cannot be included in Item Rate or Paid Amount',
  'an Actual charge included in the print rate is rejected'
);

select throws_ok(
  $$insert into public.sales_taxes_and_charges (org_id, parent_id, idx, charge_type, account_head_id, description)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000051d1',
      1,
      'On Net Total',
      current_setting('test.acct2')::uuid,
      'Wrong'
    )$$,
  'P0001',
  'tax_account_head: Account must be a ledger of the company',
  'an account from another company is rejected'
);

select throws_ok(
  $$insert into public.sales_taxes_and_charges (
      org_id, parent_id, idx, charge_type, account_head_id, description, cost_center_id
    ) values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000051d1',
      1,
      'On Net Total',
      current_setting('test.acct')::uuid,
      'Wrong center',
      current_setting('test.cc2')::uuid
    )$$,
  'P0001',
  'tax_cost_center: Row 1: Cost Center does not belong to Company',
  'a cost center from another company is rejected'
);

delete from public.tax_category where id = '30000000-0000-0000-0000-0000000051e1';
select ok(
  (
    select tax_category_id is null
      from public.sales_taxes_and_charges_template
     where id = '30000000-0000-0000-0000-0000000051d3'
  ),
  'deleting the tax category clears the template link'
);

reset role;
select lives_ok(
  format('delete from public.organizations where id = %L', current_setting('test.org')),
  'deleting the organization succeeds'
);

select * from finish();
rollback;
