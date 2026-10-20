begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007901', 'stock79@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007902', 'stock79-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007901","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Item Details Co", "slug": "stock-79", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Item Details Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Item Manager', 'Stock Manager', 'Sales Manager', 'Purchase Manager', 'Accounts User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007901';

select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.root_group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.parent_id is null
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.box', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Box'
), true);
select set_config('test.kg', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Kg'
), true);
select set_config('test.stores', (
  select c.default_warehouse_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.income', (
  select c.default_income_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.expense', (
  select c.default_expense_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.main_cc', (
  select c.cost_center_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.selling', (
  select p.id::text from public.price_list p
   where p.org_id = current_setting('test.org')::uuid and p.price_list_name = 'Standard Selling'
), true);
select set_config('test.all_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.parent_id is null
), true);
select set_config('test.cc_root', (
  select c.id::text from public.cost_center c
   where c.company_id = current_setting('test.company')::uuid and c.parent_id is null
), true);
select set_config('test.tax_account', (
  select a.id::text from public.account a
   where a.company_id = current_setting('test.company')::uuid
     and a.is_group = false
     and a.account_type in (
       'Tax', 'Chargeable', 'Income Account', 'Expense Account', 'Expenses Included In Valuation'
     )
   order by a.name
   limit 1
), true);

insert into public.item_group (id, org_id, item_group_name, parent_id, is_group) values (
  '20000000-0000-0000-0000-0000000079a1',
  current_setting('test.org')::uuid,
  'Parts 79',
  current_setting('test.root_group')::uuid,
  false
);
insert into public.warehouse (id, org_id, name, warehouse_name, company_id, parent_id) values
  ('20000000-0000-0000-0000-0000000079a2', current_setting('test.org')::uuid, 'Special 79', 'Special 79', current_setting('test.company')::uuid, current_setting('test.all_wh')::uuid),
  ('20000000-0000-0000-0000-0000000079a3', current_setting('test.org')::uuid, 'Group 79', 'Group 79', current_setting('test.company')::uuid, current_setting('test.all_wh')::uuid),
  ('20000000-0000-0000-0000-0000000079a4', current_setting('test.org')::uuid, 'Brand 79', 'Brand 79', current_setting('test.company')::uuid, current_setting('test.all_wh')::uuid);
insert into public.cost_center (id, org_id, name, cost_center_name, company_id, parent_id, is_group) values (
  '20000000-0000-0000-0000-0000000079c1',
  current_setting('test.org')::uuid,
  'Shop 79',
  'Shop 79',
  current_setting('test.company')::uuid,
  current_setting('test.cc_root')::uuid,
  false
);
insert into public.brand (id, org_id, brand) values (
  '20000000-0000-0000-0000-0000000079b1', current_setting('test.org')::uuid, 'Acme 79'
);
insert into public.customer (id, org_id, name, customer_name) values (
  '20000000-0000-0000-0000-0000000079a6', current_setting('test.org')::uuid, 'Buyer 79', 'Buyer 79'
);
insert into public.tax_category (id, org_id, name, title) values (
  '20000000-0000-0000-0000-0000000079a7', current_setting('test.org')::uuid, 'VAT 79', 'VAT 79'
);
insert into public.item_tax_template (id, org_id, name, title, company_id) values
  ('20000000-0000-0000-0000-0000000079e1', current_setting('test.org')::uuid, 'Blank 79', 'Blank 79', current_setting('test.company')::uuid),
  ('20000000-0000-0000-0000-0000000079e2', current_setting('test.org')::uuid, 'Match 79', 'Match 79', current_setting('test.company')::uuid),
  ('20000000-0000-0000-0000-0000000079e3', current_setting('test.org')::uuid, 'Later 79', 'Later 79', current_setting('test.company')::uuid),
  ('20000000-0000-0000-0000-0000000079e4', current_setting('test.org')::uuid, 'Group 79', 'Group 79', current_setting('test.company')::uuid);
insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079e1', 1, current_setting('test.tax_account')::uuid, 12),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079e2', 1, current_setting('test.tax_account')::uuid, 12),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079e3', 1, current_setting('test.tax_account')::uuid, 12),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079e4', 1, current_setting('test.tax_account')::uuid, 12);

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id, brand_id, last_purchase_rate
) values
  ('20000000-0000-0000-0000-0000000079d1', current_setting('test.org')::uuid, 'BAR-79', 'BAR-79', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, null),
  ('20000000-0000-0000-0000-0000000079d2', current_setting('test.org')::uuid, 'DEF-79', 'DEF-79', '20000000-0000-0000-0000-0000000079a1', current_setting('test.nos')::uuid, null, null),
  ('20000000-0000-0000-0000-0000000079d3', current_setting('test.org')::uuid, 'GRP-79', 'GRP-79', '20000000-0000-0000-0000-0000000079a1', current_setting('test.nos')::uuid, null, null),
  ('20000000-0000-0000-0000-0000000079d4', current_setting('test.org')::uuid, 'BRD-79', 'BRD-79', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, '20000000-0000-0000-0000-0000000079b1', null),
  ('20000000-0000-0000-0000-0000000079d6', current_setting('test.org')::uuid, 'UOM-79', 'UOM-79', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, null),
  ('20000000-0000-0000-0000-0000000079d7', current_setting('test.org')::uuid, 'PRC-79', 'PRC-79', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, null),
  ('20000000-0000-0000-0000-0000000079d8', current_setting('test.org')::uuid, 'BUY-79', 'BUY-79', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, 7),
  ('20000000-0000-0000-0000-0000000079d9', current_setting('test.org')::uuid, 'TAX-79', 'TAX-79', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, null);

insert into public.item_barcode (org_id, parent_id, idx, barcode) values (
  current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079d1', 1, 'sku-79'
);
insert into public.item_default (
  org_id, parent_id, idx, company_id, default_warehouse_id, expense_account_id, buying_cost_center_id, selling_cost_center_id
) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000079d2',
  1,
  current_setting('test.company')::uuid,
  '20000000-0000-0000-0000-0000000079a2',
  current_setting('test.income')::uuid,
  '20000000-0000-0000-0000-0000000079c1',
  current_setting('test.main_cc')::uuid
);
insert into public.item_group_default (org_id, parent_id, idx, company_id, default_warehouse_id) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000079a1',
  1,
  current_setting('test.company')::uuid,
  '20000000-0000-0000-0000-0000000079a3'
);
insert into public.brand_default (org_id, parent_id, idx, company_id, default_warehouse_id) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000079b1',
  1,
  current_setting('test.company')::uuid,
  '20000000-0000-0000-0000-0000000079a4'
);
insert into public.item_uom (org_id, parent_id, idx, uom_id, conversion_factor) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000079d6',
  2,
  current_setting('test.box')::uuid,
  12
);
insert into public.item_price (
  org_id, name, item_id, item_name, uom_id, packing_unit, price_list_id, customer_id, currency, price_list_rate, valid_from, valid_upto
) values
  (current_setting('test.org')::uuid, 'list-79', '20000000-0000-0000-0000-0000000079d7', 'PRC-79', current_setting('test.nos')::uuid, 0, current_setting('test.selling')::uuid, null, 'PHP', 10, '2026-01-01', null),
  (current_setting('test.org')::uuid, 'party-79', '20000000-0000-0000-0000-0000000079d7', 'PRC-79', current_setting('test.nos')::uuid, 0, current_setting('test.selling')::uuid, '20000000-0000-0000-0000-0000000079a6', 'PHP', 15, '2026-01-01', null),
  (current_setting('test.org')::uuid, 'old-79', '20000000-0000-0000-0000-0000000079d7', 'PRC-79', current_setting('test.nos')::uuid, 0, current_setting('test.selling')::uuid, '20000000-0000-0000-0000-0000000079a6', 'PHP', 99, '2020-01-01', '2020-01-01'),
  (current_setting('test.org')::uuid, 'pack-79', '20000000-0000-0000-0000-0000000079d7', 'PRC-79', current_setting('test.nos')::uuid, 10, current_setting('test.selling')::uuid, '20000000-0000-0000-0000-0000000079a6', 'PHP', 20, '2026-01-01', null);
insert into public.item_tax (
  org_id, parent_id, idx, item_tax_template_id, tax_category_id, valid_from, minimum_net_rate, maximum_net_rate
) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079d9', 1, '20000000-0000-0000-0000-0000000079e1', null, null, null, null),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079d9', 2, '20000000-0000-0000-0000-0000000079e2', '20000000-0000-0000-0000-0000000079a7', '2026-01-01', null, null),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000079d9', 3, '20000000-0000-0000-0000-0000000079e3', '20000000-0000-0000-0000-0000000079a7', '2026-02-01', 1000, 2000);
insert into public.item_group_tax (org_id, parent_id, idx, item_tax_template_id) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000079a1',
  1,
  '20000000-0000-0000-0000-0000000079e4'
);
insert into public.bin (org_id, item_id, warehouse_id, actual_qty, projected_qty, stock_uom_id) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000079d1',
  current_setting('test.stores')::uuid,
  4,
  6,
  current_setting('test.nos')::uuid
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007901","role":"authenticated"}', true);

select is(
  (
    public.get_item_details(jsonb_build_object(
      'barcode', 'SKU-79',
      'company_id', current_setting('test.company')::uuid
    )) ->> 'item_id'
  ),
  '20000000-0000-0000-0000-0000000079d1',
  'a barcode resolves to the item'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d2',
      'company_id', current_setting('test.company')::uuid
    )) ->> 'warehouse_id'
  ),
  '20000000-0000-0000-0000-0000000079a2',
  'the item default warehouse beats the group and the company'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d2',
      'company_id', current_setting('test.company')::uuid,
      'warehouse_id', current_setting('test.stores')::uuid
    )) ->> 'warehouse_id'
  ),
  current_setting('test.stores'),
  'a warehouse already passed is kept'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d1',
      'company_id', current_setting('test.company')::uuid
    )) ->> 'warehouse_id'
  ),
  current_setting('test.stores'),
  'an item with no default uses the company warehouse'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d3',
      'company_id', current_setting('test.company')::uuid
    )) ->> 'warehouse_id'
  ),
  '20000000-0000-0000-0000-0000000079a3',
  'the item group default is used when the item has none'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d4',
      'company_id', current_setting('test.company')::uuid
    )) ->> 'warehouse_id'
  ),
  '20000000-0000-0000-0000-0000000079a4',
  'the brand default is used when the item and its group have none'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d6',
      'company_id', current_setting('test.company')::uuid,
      'uom_id', current_setting('test.box')::uuid,
      'qty', 2
    )) ->> 'conversion_factor'
  )::numeric,
  12::numeric,
  'the item UOM conversion factor is returned'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d6',
      'company_id', current_setting('test.company')::uuid,
      'uom_id', current_setting('test.box')::uuid,
      'qty', 2
    )) ->> 'stock_qty'
  )::numeric,
  24::numeric,
  'stock qty is qty times the conversion factor'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d7',
      'company_id', current_setting('test.company')::uuid,
      'price_list_id', current_setting('test.selling')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000079a6',
      'qty', 12,
      'transaction_date', '2026-03-01'
    )) ->> 'rate'
  )::numeric,
  20::numeric,
  'the customer price for the largest packing unit beats the list and an expired price'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d8',
      'company_id', current_setting('test.company')::uuid,
      'doctype', 'Purchase Order'
    )) ->> 'rate'
  )::numeric,
  7::numeric,
  'a buying document with no price uses the last purchase rate'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d2',
      'company_id', current_setting('test.company')::uuid
    )) ->> 'expense_account_id'
  ),
  current_setting('test.income'),
  'the item default expense account beats the company expense account'
);
select isnt(
  current_setting('test.income'),
  current_setting('test.expense'),
  'the company income and expense accounts differ'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d2',
      'company_id', current_setting('test.company')::uuid,
      'transaction_type', 'selling'
    )) ->> 'cost_center_id'
  ),
  current_setting('test.main_cc'),
  'selling uses the selling cost center'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d2',
      'company_id', current_setting('test.company')::uuid,
      'doctype', 'Purchase Order'
    )) ->> 'cost_center_id'
  ),
  '20000000-0000-0000-0000-0000000079c1',
  'buying uses the buying cost center'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d9',
      'company_id', current_setting('test.company')::uuid,
      'tax_category_id', '20000000-0000-0000-0000-0000000079a7',
      'net_rate', 10,
      'transaction_date', '2026-06-01'
    )) ->> 'item_tax_template_id'
  ),
  '20000000-0000-0000-0000-0000000079e2',
  'an exact tax category beats a blank row and a rate outside the band is skipped'
);
select is(
  (
    public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d3',
      'company_id', current_setting('test.company')::uuid,
      'transaction_date', '2026-06-01'
    )) ->> 'item_tax_template_id'
  ),
  '20000000-0000-0000-0000-0000000079e4',
  'a group template is used when the item has none'
);
select ok(
  (
    select (d ->> 'actual_qty')::numeric = 4 and (d ->> 'projected_qty')::numeric = 6
      from (
        select public.get_item_details(jsonb_build_object(
          'item_id', '20000000-0000-0000-0000-0000000079d1',
          'company_id', current_setting('test.company')::uuid
        )) as d
      ) q
  ),
  'bin qty is returned for the item and warehouse'
);
select throws_ok(
  $$
    select public.get_item_details(jsonb_build_object(
      'barcode', 'missing-79',
      'company_id', current_setting('test.company')::uuid
    ))
  $$,
  'P0001',
  'item_details: Barcode was not found',
  'an unknown barcode is rejected'
);
select throws_ok(
  $$
    select public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d6',
      'company_id', current_setting('test.company')::uuid,
      'uom_id', current_setting('test.kg')::uuid
    ))
  $$,
  'P0001',
  'item_details: UOM is not on the item',
  'a UOM that is not on the item is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007902","role":"authenticated"}', true);
select throws_ok(
  $$
    select public.get_item_details(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000079d1',
      'company_id', current_setting('test.company')::uuid
    ))
  $$,
  'P0001',
  'item_details: Item was not found',
  'a user outside the organization cannot read the item'
);

select * from finish();
rollback;
