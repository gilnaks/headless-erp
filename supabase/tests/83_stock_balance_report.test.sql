begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008301', 'stock83@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008302', 'stock83-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008301","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Balance Co", "slug": "stock-83", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Balance Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.root_group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.parent_id is null
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.root_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.parent_id is null
), true);

insert into public.item_group (id, org_id, item_group_name, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000083b1', current_setting('test.org')::uuid, 'Group 83', current_setting('test.root_group')::uuid, true);
insert into public.item_group (id, org_id, item_group_name, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000083b2', current_setting('test.org')::uuid, 'Child 83', '20000000-0000-0000-0000-0000000083b1', false),
  ('20000000-0000-0000-0000-0000000083b3', current_setting('test.org')::uuid, 'Side 83', current_setting('test.root_group')::uuid, false);

insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000083a1', current_setting('test.org')::uuid, 'Group 83', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, true);
insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000083a2', current_setting('test.org')::uuid, 'Leaf 83', current_setting('test.company')::uuid, '20000000-0000-0000-0000-0000000083a1', false),
  ('20000000-0000-0000-0000-0000000083a3', current_setting('test.org')::uuid, 'Side 83', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false);

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id
) values
  ('20000000-0000-0000-0000-0000000083d1', current_setting('test.org')::uuid, 'BAL-83', 'BAL-83', '20000000-0000-0000-0000-0000000083b2', current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000083d2', current_setting('test.org')::uuid, 'OUT-83', 'OUT-83', '20000000-0000-0000-0000-0000000083b2', current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000083d3', current_setting('test.org')::uuid, 'ZERO-83', 'ZERO-83', '20000000-0000-0000-0000-0000000083b2', current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000083d4', current_setting('test.org')::uuid, 'SIDE-83', 'SIDE-83', '20000000-0000-0000-0000-0000000083b3', current_setting('test.nos')::uuid);

insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d1', '20000000-0000-0000-0000-0000000083a2',
    current_date - 40, '10:00', (current_date - 40) + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f1', 'OLD-83', 4, 4, 2, 2, 8, 8,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d1', '20000000-0000-0000-0000-0000000083a2',
    current_date, '09:00', current_date + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f2', 'CAN-83', 9, 9, 9, 9, 81, 81,
    current_setting('test.nos')::uuid, true
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d1', '20000000-0000-0000-0000-0000000083a2',
    current_date, '10:00', current_date + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f3', 'IN-83', 6, 10, 3, 3, 26, 18,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d1', '20000000-0000-0000-0000-0000000083a2',
    current_date + 20, '10:00', (current_date + 20) + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f4', 'FUT-83', 100, 110, 9, 9, 926, 900,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d2', '20000000-0000-0000-0000-0000000083a2',
    current_date - 40, '11:00', (current_date - 40) + time '11:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f5', 'OUT-OLD', 10, 10, 5, 5, 50, 50,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d2', '20000000-0000-0000-0000-0000000083a2',
    current_date, '11:00', current_date + time '11:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f6', 'OUT-83', -3, 7, 0, 5, 35, -15,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d3', '20000000-0000-0000-0000-0000000083a2',
    current_date - 10, '10:00', (current_date - 10) + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f7', 'ZERO-IN', 5, 5, 5, 5, 25, 25,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d3', '20000000-0000-0000-0000-0000000083a2',
    current_date, '12:00', current_date + time '12:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f8', 'ZERO-OUT', -5, 0, 0, 5, 0, -25,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000083d4', '20000000-0000-0000-0000-0000000083a3',
    current_date, '12:00', current_date + time '12:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000083f9', 'SIDE-83', 7, 7, 2, 2, 14, 14,
    current_setting('test.nos')::uuid, false
  );

select set_config('test.filters', jsonb_build_object(
  'company', current_setting('test.company'),
  'from_date', (current_date - 5)::text,
  'to_date', current_date::text
)::text, true);

set local role authenticated;

select throws_ok(
  $$ select public.report_stock_balance('{}'::jsonb) $$,
  'P0001',
  'sbal_company: Company is mandatory',
  'a missing company is rejected'
);
select throws_ok(
  format(
    'select public.report_stock_balance(%L::jsonb)',
    jsonb_build_object('company', current_setting('test.company'))
  ),
  'P0001',
  'sbal_dates: From Date and To Date are mandatory',
  'missing dates are rejected'
);
select throws_ok(
  format(
    'select public.report_stock_balance(%L::jsonb)',
    jsonb_build_object(
      'company', current_setting('test.company'),
      'from_date', current_date,
      'to_date', current_date - 1
    )
  ),
  'P0001',
  'sbal_dates: From Date must be before To Date',
  'a from-date after the to-date is rejected'
);

select set_config(
  'test.report',
  public.report_stock_balance(current_setting('test.filters')::jsonb)::text,
  true
);

select is(
  (
    select (entry ->> 'opening_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-83'
  ),
  4::numeric,
  'opening qty is the movement before the from-date'
);
select is(
  (
    select (entry ->> 'opening_value')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-83'
  ),
  8::numeric,
  'opening value is the movement before the from-date'
);
select is(
  (
    select (entry ->> 'in_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-83'
  ),
  6::numeric,
  'in qty sums positive movement inside the range'
);
select is(
  (
    select (entry ->> 'out_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'OUT-83'
  ),
  3::numeric,
  'out qty is the absolute outward movement'
);
select is(
  (
    select (entry ->> 'balance_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-83'
  ),
  10::numeric,
  'balance qty ignores a cancelled row and a row after the to-date'
);
select is(
  (
    select (entry ->> 'balance_value')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-83'
  ),
  26::numeric,
  'balance value is the movement through the to-date'
);
select is(
  (
    select (entry ->> 'valuation_rate')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-83'
  ),
  3::numeric,
  'valuation rate is the latest ledger row on or before the to-date'
);
select is(
  (
    select entry ->> 'row_type'
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-83'
  ),
  'entry',
  'a balance row is an entry'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'ZERO-83'
  ),
  'a zero balance is omitted by default'
);

select set_config(
  'test.zero',
  public.report_stock_balance(
    current_setting('test.filters')::jsonb || jsonb_build_object('include_zero', true)
  )::text,
  true
);
select is(
  (
    select (entry ->> 'opening_qty')::numeric
      from jsonb_array_elements(current_setting('test.zero')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'ZERO-83'
  ),
  5::numeric,
  'include zero keeps the opening of a pair that ends at zero'
);
select is(
  (
    select (entry ->> 'out_qty')::numeric
      from jsonb_array_elements(current_setting('test.zero')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'ZERO-83'
  ),
  5::numeric,
  'include zero keeps the outward qty of a pair that ends at zero'
);
select is(
  (
    select (entry ->> 'balance_qty')::numeric
      from jsonb_array_elements(current_setting('test.zero')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'ZERO-83'
  ),
  0::numeric,
  'include zero shows a zero balance'
);

select is(
  jsonb_array_length(
    public.report_stock_balance(
      current_setting('test.filters')::jsonb || jsonb_build_object('item', '20000000-0000-0000-0000-0000000083d1')
    ) -> 'rows'
  ),
  1,
  'an item filter keeps one row'
);
select is(
  public.report_stock_balance(
    current_setting('test.filters')::jsonb || jsonb_build_object('item', '20000000-0000-0000-0000-0000000083d1')
  ) #>> '{rows,0,item}',
  'BAL-83',
  'an item filter keeps that item'
);

select ok(
  exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_balance(
          current_setting('test.filters')::jsonb || jsonb_build_object('item_group', '20000000-0000-0000-0000-0000000083b1')
        ) -> 'rows'
      ) entry
     where entry ->> 'item' = 'BAL-83'
  ),
  'an item group includes a descendant group'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_balance(
          current_setting('test.filters')::jsonb || jsonb_build_object('item_group', '20000000-0000-0000-0000-0000000083b1')
        ) -> 'rows'
      ) entry
     where entry ->> 'item' = 'SIDE-83'
  ),
  'a sibling item group is left out'
);

select ok(
  exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_balance(
          current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000083a1')
        ) -> 'rows'
      ) entry
     where entry ->> 'item' = 'BAL-83'
  ),
  'a group warehouse includes its child'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_balance(
          current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000083a1')
        ) -> 'rows'
      ) entry
     where entry ->> 'item' = 'SIDE-83'
  ),
  'a sibling warehouse is left out of the group'
);

select is(
  jsonb_array_length(
    public.report_stock_balance(
      current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000083ff')
    ) -> 'rows'
  ),
  0,
  'an unknown warehouse returns no rows'
);

select is(
  (
    select (entry ->> 'in_qty')::numeric
      from jsonb_array_elements(
        public.report_stock_balance(jsonb_build_object(
          'company', current_setting('test.company'),
          'from_date', current_date::text,
          'to_date', current_date::text
        )) -> 'rows'
      ) entry
     where entry ->> 'item' = 'BAL-83'
  ),
  6::numeric,
  'a from-date equal to the to-date still counts that day as in qty'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008302","role":"authenticated"}', true);
select throws_ok(
  format(
    'select public.report_stock_balance(%L::jsonb)',
    current_setting('test.filters')::jsonb
  ),
  'P0001',
  'sbal_company: Company is mandatory',
  'a user outside the organization cannot read the company'
);

select * from finish();
rollback;
