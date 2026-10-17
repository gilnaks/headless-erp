begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000052a1', 'item-tax-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000052a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Item Tax Org","slug":"item-tax-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000052c1', current_setting('test.org')::uuid, 'Tax Co', 'TC'),
  ('20000000-0000-0000-0000-0000000052c2', current_setting('test.org')::uuid, 'Other Co', 'OC');

select set_config(
  'test.income',
  (
    select a.id::text from public.account a
     where a.company_id = '20000000-0000-0000-0000-0000000052c1'
       and a.is_group = false
       and a.account_type in ('Tax', 'Chargeable', 'Income Account', 'Expense Account', 'Expenses Included In Valuation')
     order by a.name
     limit 1
  ),
  true
);
select set_config(
  'test.income_name',
  (select a.name from public.account a where a.id = current_setting('test.income')::uuid),
  true
);
select set_config(
  'test.income2',
  (
    select a.id::text from public.account a
     where a.company_id = '20000000-0000-0000-0000-0000000052c1'
       and a.is_group = false
       and a.account_type in ('Tax', 'Chargeable', 'Income Account', 'Expense Account', 'Expenses Included In Valuation')
     order by a.name
     offset 1
     limit 1
  ),
  true
);
select set_config(
  'test.income2_name',
  (select a.name from public.account a where a.id = current_setting('test.income2')::uuid),
  true
);
select set_config(
  'test.recv',
  (
    select a.id::text from public.account a
     where a.company_id = '20000000-0000-0000-0000-0000000052c1'
       and a.is_group = false and a.account_type = 'Receivable'
     order by a.name
     limit 1
  ),
  true
);
select set_config(
  'test.acct2',
  (
    select a.id::text from public.account a
     where a.company_id = '20000000-0000-0000-0000-0000000052c2' and a.is_group = false
     order by a.name
     limit 1
  ),
  true
);

insert into public.item_tax_template (id, org_id, title, company_id)
values (
  '30000000-0000-0000-0000-0000000052d1',
  current_setting('test.org')::uuid,
  'VAT',
  '20000000-0000-0000-0000-0000000052c1'
);
insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate)
values (
  current_setting('test.org')::uuid,
  '30000000-0000-0000-0000-0000000052d1',
  1,
  current_setting('test.income')::uuid,
  12
);
insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate, not_applicable)
values (
  current_setting('test.org')::uuid,
  '30000000-0000-0000-0000-0000000052d1',
  2,
  current_setting('test.income2')::uuid,
  18,
  true
);

insert into public.item_tax_template (id, org_id, title, company_id)
values (
  '30000000-0000-0000-0000-0000000052d2',
  current_setting('test.org')::uuid,
  'Discount',
  '20000000-0000-0000-0000-0000000052c1'
);
insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate)
values (
  current_setting('test.org')::uuid,
  '30000000-0000-0000-0000-0000000052d2',
  1,
  current_setting('test.income')::uuid,
  -5
);

set constraints item_tax_template_rows, item_tax_detail_rows immediate;
set constraints item_tax_template_rows, item_tax_detail_rows deferred;

select is(
  (select name from public.item_tax_template where id = '30000000-0000-0000-0000-0000000052d1'),
  'VAT - TC',
  'the name is the title and the company abbreviation'
);
select is(
  (
    select tax_rate from public.item_tax_template_detail
     where parent_id = '30000000-0000-0000-0000-0000000052d1' and idx = 2
  ),
  0::numeric,
  'a not-applicable row stores rate 0'
);
select is(
  (
    select tax_rate from public.item_tax_template_detail
     where parent_id = '30000000-0000-0000-0000-0000000052d2' and idx = 1
  ),
  -5::numeric,
  'a negative rate saves'
);

select throws_ok(
  $$insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000052d1',
      9,
      current_setting('test.acct2')::uuid,
      9
    )$$,
  'P0001',
  'item_tax_company: Item Tax Row 9: Account must belong to the company',
  'an account from another company is rejected'
);

select throws_ok(
  $$insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000052d1',
      9,
      current_setting('test.recv')::uuid,
      9
    )$$,
  'P0001',
  'item_tax_type: Item Tax Row 9 must have account of type Tax or Income or Expense or Chargeable',
  'a receivable account is rejected'
);

select throws_ok(
  format(
    $q$insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate)
      values (current_setting('test.org')::uuid, '30000000-0000-0000-0000-0000000052d1', 3, %L::uuid, 5)$q$,
    current_setting('test.income')
  ),
  'P0001',
  format('item_tax_duplicate: %s entered twice in Item Tax', current_setting('test.income_name')),
  'the same account on two rows is rejected'
);

select throws_ok(
  $$
    set constraints item_tax_template_rows, item_tax_detail_rows deferred;
    insert into public.item_tax_template (org_id, title, company_id)
    values (current_setting('test.org')::uuid, 'Empty', '20000000-0000-0000-0000-0000000052c1');
    set constraints item_tax_template_rows, item_tax_detail_rows immediate;
  $$,
  'P0001',
  'item_tax_rows: Tax Rates is required',
  'a template with no tax row is rejected'
);

select set_config(
  'test.map',
  public.get_item_tax_map(
    '20000000-0000-0000-0000-0000000052c1',
    '30000000-0000-0000-0000-0000000052d1',
    jsonb_build_array(
      jsonb_build_object('account_head', current_setting('test.income_name'), 'rate', 3, 'set_by_item_tax_template', false),
      jsonb_build_object('account_head', 'Freight', 'rate', 7, 'set_by_item_tax_template', false),
      jsonb_build_object('account_head', 'Ignored', 'rate', 99, 'set_by_item_tax_template', true)
    )
  )::text,
  true
);

select is(
  (current_setting('test.map')::jsonb ->> 'Freight')::numeric,
  7::numeric,
  'a manual document rate is kept'
);
select is(
  (current_setting('test.map')::jsonb ->> current_setting('test.income_name'))::numeric,
  12::numeric,
  'the template overlays the document rate'
);
select is(
  current_setting('test.map')::jsonb ->> current_setting('test.income2_name'),
  'N/A',
  'a not-applicable template row is stored as N/A'
);
select ok(
  not (current_setting('test.map')::jsonb ? 'Ignored'),
  'a row marked set by the template is ignored'
);

reset role;
select lives_ok(
  $$
    delete from public.organizations where id = current_setting('test.org')::uuid;
    set constraints item_tax_template_rows, item_tax_detail_rows immediate;
  $$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
