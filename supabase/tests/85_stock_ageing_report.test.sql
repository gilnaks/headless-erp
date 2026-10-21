begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008501', 'stock85@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008502', 'stock85-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008501","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Ageing Co", "slug": "stock-85", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Ageing Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.root_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.parent_id is null
), true);

insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000085a1', current_setting('test.org')::uuid, 'Group 85', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, true);
insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000085a2', current_setting('test.org')::uuid, 'Leaf 85', current_setting('test.company')::uuid, '20000000-0000-0000-0000-0000000085a1', false),
  ('20000000-0000-0000-0000-0000000085a3', current_setting('test.org')::uuid, 'Side 85', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false);

select set_config('test.leaf', (
  select w.name from public.warehouse w where w.id = '20000000-0000-0000-0000-0000000085a2'
), true);
select set_config('test.side', (
  select w.name from public.warehouse w where w.id = '20000000-0000-0000-0000-0000000085a3'
), true);

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id
) values
  ('20000000-0000-0000-0000-0000000085d1', current_setting('test.org')::uuid, 'TODAY-85', 'TODAY-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d2', current_setting('test.org')::uuid, 'FIFO-85', 'FIFO-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d3', current_setting('test.org')::uuid, 'PACK-85', 'PACK-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d4', current_setting('test.org')::uuid, 'XFER-85', 'XFER-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d5', current_setting('test.org')::uuid, 'LATE-85', 'LATE-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d6', current_setting('test.org')::uuid, 'CAN-85', 'CAN-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d7', current_setting('test.org')::uuid, 'ZERO-85', 'ZERO-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d8', current_setting('test.org')::uuid, 'OLD-85', 'OLD-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000085d9', current_setting('test.org')::uuid, 'SIDE-85', 'SIDE-85', current_setting('test.products')::uuid, current_setting('test.nos')::uuid);

insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d1', '20000000-0000-0000-0000-0000000085a2',
    current_date, '09:00', current_date + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f1', 'TODAY-85', 10, 10, 5, 5, 50, 50,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d2', '20000000-0000-0000-0000-0000000085a2',
    current_date - 100, '09:00', (current_date - 100) + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f2', 'FIFO-OLD', 8, 8, 1, 1, 8, 8,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d2', '20000000-0000-0000-0000-0000000085a2',
    current_date - 10, '09:00', (current_date - 10) + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f3', 'FIFO-MID', 4, 12, 1, 1, 12, 4,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d2', '20000000-0000-0000-0000-0000000085a2',
    current_date, '08:00', current_date + time '08:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f4', 'FIFO-OUT', -5, 7, 0, 1, 7, -5,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d3', '20000000-0000-0000-0000-0000000085a2',
    current_date - 50, '09:00', (current_date - 50) + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f5', 'PACK-IN', 10, 10, 1, 1, 10, 10,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d3', '20000000-0000-0000-0000-0000000085a2',
    current_date, '12:00', current_date + time '12:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f6', 'PACK-OUT', -4, 6, 0, 1, 6, -4,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d3', '20000000-0000-0000-0000-0000000085a2',
    current_date, '12:01', current_date + time '12:01',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f6', 'PACK-BACK', 4, 10, 1, 1, 10, 4,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d4', '20000000-0000-0000-0000-0000000085a2',
    current_date - 80, '09:00', (current_date - 80) + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f7', 'XFER-IN', 10, 10, 1, 1, 10, 10,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d4', '20000000-0000-0000-0000-0000000085a2',
    current_date, '10:00', current_date + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f8', 'XFER-OUT', -6, 4, 0, 1, 4, -6,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d4', '20000000-0000-0000-0000-0000000085a3',
    current_date, '10:01', current_date + time '10:01',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f8', 'XFER-IN-SIDE', 6, 6, 1, 1, 6, 6,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d5', '20000000-0000-0000-0000-0000000085a2',
    current_date, '11:00', current_date + time '11:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085f9', 'LATE-NOW', 2, 2, 1, 1, 2, 2,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d5', '20000000-0000-0000-0000-0000000085a2',
    current_date + 1, '11:00', (current_date + 1) + time '11:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085fa', 'LATE-FUTURE', 20, 22, 1, 1, 22, 20,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d6', '20000000-0000-0000-0000-0000000085a2',
    current_date, '07:00', current_date + time '07:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085fb', 'CAN-85', 9, 9, 1, 1, 9, 9,
    current_setting('test.nos')::uuid, true
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d6', '20000000-0000-0000-0000-0000000085a2',
    current_date, '07:30', current_date + time '07:30',
    'Stock Entry', '20000000-0000-0000-0000-0000000085fc', 'CAN-KEEP', 3, 3, 1, 1, 3, 3,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d7', '20000000-0000-0000-0000-0000000085a2',
    current_date, '06:00', current_date + time '06:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085fd', 'ZERO-IN', 5, 5, 1, 1, 5, 5,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d7', '20000000-0000-0000-0000-0000000085a2',
    current_date, '06:01', current_date + time '06:01',
    'Stock Entry', '20000000-0000-0000-0000-0000000085fe', 'ZERO-OUT', -5, 0, 0, 1, 0, -5,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d8', '20000000-0000-0000-0000-0000000085a2',
    current_date - 121, '09:00', (current_date - 121) + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085e1', 'OLD-85', 2, 2, 1, 1, 2, 2,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000085d9', '20000000-0000-0000-0000-0000000085a3',
    current_date, '13:00', current_date + time '13:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000085e2', 'SIDE-85', 7, 7, 1, 1, 7, 7,
    current_setting('test.nos')::uuid, false
  );

select set_config('test.filters', jsonb_build_object(
  'company', current_setting('test.company'),
  'to_date', current_date::text
)::text, true);

set local role authenticated;
select set_config(
  'test.report',
  public.report_stock_ageing(current_setting('test.filters')::jsonb)::text,
  true
);

select throws_ok(
  $$ select public.report_stock_ageing('{}'::jsonb) $$,
  'P0001',
  'sage_company: Company is mandatory',
  'a missing company is rejected'
);
select throws_ok(
  format(
    'select public.report_stock_ageing(%L::jsonb)',
    jsonb_build_object('company', current_setting('test.company'))
  ),
  'P0001',
  'sage_date: As On Date is mandatory',
  'a missing as-on date is rejected'
);

select is(
  (
    select (entry ->> 'available_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'TODAY-85'
  ),
  10::numeric,
  'a receipt on the as-on date keeps its qty'
);
select is(
  (
    select (entry ->> 'average_age')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'TODAY-85'
  ),
  0::numeric,
  'a receipt on the as-on date has age 0'
);
select is(
  (
    select (entry ->> 'age_1')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'TODAY-85'
  ),
  10::numeric,
  'a receipt on the as-on date lands in 0 - 30'
);
select is(
  (
    select entry ->> 'row_type'
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'TODAY-85'
  ),
  'entry',
  'an ageing row is an entry'
);

select is(
  (
    select (entry ->> 'age_4')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'FIFO-85'
  ),
  3::numeric,
  'an issue consumes the older slot first'
);
select is(
  (
    select (entry ->> 'age_1')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'FIFO-85'
  ),
  4::numeric,
  'the newer slot remains after the older slot is consumed'
);
select is(
  (
    select (entry ->> 'average_age')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'FIFO-85'
  ),
  48.57::numeric,
  'average age is the qty-weighted age'
);

select is(
  (
    select (entry ->> 'age_2')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'PACK-85'
  ),
  10::numeric,
  'a same-warehouse voucher pair keeps the original inward date'
);
select is(
  (
    select (entry ->> 'age_1')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'PACK-85'
  ),
  0::numeric,
  'a same-warehouse voucher pair does not restart the age'
);

select is(
  (
    select (entry ->> 'available_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'XFER-85' and entry ->> 'warehouse' = current_setting('test.side')
  ),
  6::numeric,
  'a transfer moves qty onto the destination warehouse'
);
select is(
  (
    select (entry ->> 'average_age')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'XFER-85' and entry ->> 'warehouse' = current_setting('test.side')
  ),
  0::numeric,
  'a different-warehouse transfer ages from the transfer date'
);
select is(
  (
    select (entry ->> 'age_1')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'XFER-85' and entry ->> 'warehouse' = current_setting('test.side')
  ),
  6::numeric,
  'transferred qty sits in the first bucket'
);
select is(
  (
    select (entry ->> 'available_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'XFER-85' and entry ->> 'warehouse' = current_setting('test.leaf')
  ),
  4::numeric,
  'the source warehouse keeps the unconsumed qty'
);
select is(
  (
    select (entry ->> 'age_3')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'XFER-85' and entry ->> 'warehouse' = current_setting('test.leaf')
  ),
  4::numeric,
  'the source warehouse keeps the original inward age'
);

select is(
  (
    select (entry ->> 'available_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'LATE-85'
  ),
  2::numeric,
  'a row after the as-on date is ignored'
);
select is(
  (
    select (entry ->> 'available_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'CAN-85'
  ),
  3::numeric,
  'a cancelled row is ignored'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'ZERO-85'
  ),
  'a zero balance is omitted'
);
select is(
  (
    select (entry ->> 'age_5')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'OLD-85'
  ),
  2::numeric,
  'qty older than the last bound lands in Above'
);
select ok(
  (current_setting('test.report')::jsonb -> 'columns') @> '[{"label":"Age (0 - 30)"}]'::jsonb
    and (current_setting('test.report')::jsonb -> 'columns') @> '[{"label":"Age (91 - 120)"}]'::jsonb
    and (current_setting('test.report')::jsonb -> 'columns') @> '[{"label":"Age (121 - Above)"}]'::jsonb,
  'the seeded ageing range builds 30, 60, 90, and 120 buckets'
);

select is(
  jsonb_array_length(
    public.report_stock_ageing(current_setting('test.filters')::jsonb || jsonb_build_object(
      'item', '20000000-0000-0000-0000-0000000085d1'
    )) -> 'rows'
  ),
  1,
  'an item filter returns that item'
);
select is(
  (
    select entry ->> 'item'
      from jsonb_array_elements(
        public.report_stock_ageing(current_setting('test.filters')::jsonb || jsonb_build_object(
          'item', '20000000-0000-0000-0000-0000000085d1'
        )) -> 'rows'
      ) entry
  ),
  'TODAY-85',
  'an item filter matches the item code'
);
select is(
  jsonb_array_length(
    public.report_stock_ageing(current_setting('test.filters')::jsonb || jsonb_build_object(
      'warehouse', '20000000-0000-0000-0000-0000000085a1'
    )) -> 'rows'
  ),
  7,
  'a warehouse filter includes descendants'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_ageing(current_setting('test.filters')::jsonb || jsonb_build_object(
          'warehouse', '20000000-0000-0000-0000-0000000085a1'
        )) -> 'rows'
      ) entry
     where entry ->> 'item' = 'SIDE-85'
  ),
  'a warehouse filter skips warehouses outside the tree'
);
select is(
  jsonb_array_length(
    public.report_stock_ageing(current_setting('test.filters')::jsonb || jsonb_build_object(
      'warehouse', '20000000-0000-0000-0000-0000000085ff'
    )) -> 'rows'
  ),
  0,
  'an unknown warehouse returns no rows'
);
select is(
  jsonb_array_length(
    public.report_stock_ageing(current_setting('test.filters')::jsonb || jsonb_build_object(
      'item', '20000000-0000-0000-0000-0000000085ee'
    )) -> 'rows'
  ),
  0,
  'an unknown item returns no rows'
);
select is(
  jsonb_array_length(
    public.report_stock_ageing(current_setting('test.filters')::jsonb || jsonb_build_object(
      'item', 'not-a-uuid'
    )) -> 'rows'
  ),
  9,
  'an invalid item id is ignored'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008502","role":"authenticated"}', true);
select throws_ok(
  format(
    'select public.report_stock_ageing(%L::jsonb)',
    current_setting('test.filters')::jsonb
  ),
  'P0001',
  'sage_company: Company is mandatory',
  'a user outside the organization cannot read the company'
);

select * from finish();
rollback;
