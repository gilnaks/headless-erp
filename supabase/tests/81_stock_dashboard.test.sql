begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008101', 'stock81@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008102', 'stock81-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008101","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Dashboard Co", "slug": "stock-81", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Dashboard Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.root_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.parent_id is null
), true);
select set_config('test.stores', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.warehouse_name = 'Stores'
), true);

insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group, disabled) values
  ('20000000-0000-0000-0000-0000000081a1', current_setting('test.org')::uuid, 'Group 81', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, true, false),
  ('20000000-0000-0000-0000-0000000081a2', current_setting('test.org')::uuid, 'Empty 81', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false, false),
  ('20000000-0000-0000-0000-0000000081a3', current_setting('test.org')::uuid, 'Valued 81', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false, false),
  ('20000000-0000-0000-0000-0000000081a4', current_setting('test.org')::uuid, 'Closed 81', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false, true);

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id, safety_stock, disabled
) values
  ('20000000-0000-0000-0000-0000000081d1', current_setting('test.org')::uuid, 'OLD-81', 'OLD-81', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, false),
  ('20000000-0000-0000-0000-0000000081d2', current_setting('test.org')::uuid, 'NEW-81', 'NEW-81', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, false),
  ('20000000-0000-0000-0000-0000000081d3', current_setting('test.org')::uuid, 'OUT-81', 'OUT-81', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, false),
  ('20000000-0000-0000-0000-0000000081d4', current_setting('test.org')::uuid, 'SHORT-81', 'SHORT-81', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, 10, false),
  ('20000000-0000-0000-0000-0000000081d5', current_setting('test.org')::uuid, 'OK-81', 'OK-81', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, 10, false),
  ('20000000-0000-0000-0000-0000000081d6', current_setting('test.org')::uuid, 'HEALTH-81', 'HEALTH-81', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, 1, false),
  ('20000000-0000-0000-0000-0000000081d7', current_setting('test.org')::uuid, 'OFF-81', 'OFF-81', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, true);

insert into public.item_reorder (
  org_id, parent_id, idx, warehouse_id, material_request_type, warehouse_reorder_level, warehouse_reorder_qty
) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000081d4',
  1,
  current_setting('test.stores')::uuid,
  'Purchase',
  8,
  1
);

insert into public.bin (org_id, item_id, warehouse_id, actual_qty, projected_qty, stock_value, stock_uom_id) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000081d1', '20000000-0000-0000-0000-0000000081a1', 4, 4, 50, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000081d1', '20000000-0000-0000-0000-0000000081a2', 0, 0, 0, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000081d1', '20000000-0000-0000-0000-0000000081a3', 4, 4, 12, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000081d4', current_setting('test.stores')::uuid, 2, 2, 0, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000081d5', current_setting('test.stores')::uuid, 9, 9, 0, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000081d6', current_setting('test.stores')::uuid, 50, 50, 0, current_setting('test.nos')::uuid);

insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, stock_uom_id, is_cancelled
) values
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000081d1', current_setting('test.stores')::uuid,
    current_date - 10, '10:00', (current_date - 10) + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000081f1', 'OLD-1', 5, 5, current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000081d1', current_setting('test.stores')::uuid,
    current_date, '15:00', current_date + time '15:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000081f6', 'OLD-2', 1, 6, current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000081d2', current_setting('test.stores')::uuid,
    current_date - 40, '10:00', (current_date - 40) + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000081f3', 'NEW-OLD', 9, 9, current_setting('test.nos')::uuid, true
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000081d2', current_setting('test.stores')::uuid,
    current_date - 1, '12:00', (current_date - 1) + time '12:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000081f2', 'NEW-1', 2, 2, current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000081d3', current_setting('test.stores')::uuid,
    current_date - 30, '10:00', (current_date - 30) + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000081f4', 'OUT-1', 3, 3, current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000081d3', current_setting('test.stores')::uuid,
    current_date, '18:00', current_date + time '18:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000081f5', 'OUT-2', -3, 0, current_setting('test.nos')::uuid, false
  );

select set_config('test.filters', jsonb_build_object('company', current_setting('test.company'))::text, true);

set local role authenticated;

select throws_ok(
  $$ select public.card_stock('{}'::jsonb) $$,
  'P0001',
  'dash_company: Company is mandatory',
  'a missing company is rejected'
);

select is(
  (public.card_stock(current_setting('test.filters')::jsonb) ->> 'active_items')::int,
  6,
  'active items skip a disabled item'
);
select is(
  (public.card_stock(current_setting('test.filters')::jsonb) ->> 'warehouses')::int,
  8,
  'warehouses count groups and skip a disabled warehouse'
);
select is(
  (public.card_stock(current_setting('test.filters')::jsonb) ->> 'stock_value')::numeric,
  62::numeric,
  'stock value sums bins, including a group warehouse'
);

select is(
  jsonb_array_length(public.chart_stock('warehouse_value', current_setting('test.filters')::jsonb) -> 'chart' -> 'labels'),
  1,
  'a zero-value warehouse and a group warehouse are left off the chart'
);
select matches(
  public.chart_stock('warehouse_value', current_setting('test.filters')::jsonb) #>> '{chart,labels,0}',
  '^Valued 81',
  'the valued leaf is the warehouse chart'
);

select is(
  public.chart_stock('oldest_items', current_setting('test.filters')::jsonb) #>> '{chart,labels,0}',
  'OLD-81',
  'the oldest in-stock item is first'
);
select is(
  (public.chart_stock('oldest_items', current_setting('test.filters')::jsonb) #>> '{chart,datasets,0,values,0}')::numeric,
  10::numeric,
  'age is days since the earliest in-stock ledger row'
);
select is(
  (public.chart_stock('oldest_items', current_setting('test.filters')::jsonb) #>> '{chart,datasets,0,values,1}')::numeric,
  1::numeric,
  'a cancelled older row does not age the newer item'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements_text(
        public.chart_stock('oldest_items', current_setting('test.filters')::jsonb) -> 'chart' -> 'labels'
      ) label
     where label = 'OUT-81'
  ),
  'an item whose latest row is zero is left off'
);

select matches(
  public.chart_stock('shortage', current_setting('test.filters')::jsonb) #>> '{chart,labels,0}',
  '^SHORT-81',
  'the larger shortfall is first'
);
select is(
  (public.chart_stock('shortage', current_setting('test.filters')::jsonb) #>> '{chart,datasets,0,values,0}')::numeric,
  8::numeric,
  'shortage is the larger of the safety and reorder gaps'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements_text(
        public.chart_stock('shortage', current_setting('test.filters')::jsonb) -> 'chart' -> 'labels'
      ) label
     where label like 'HEALTH-81%'
  ),
  'a healthy bin is left off the shortage chart'
);

select is(
  (public.chart_stock('purchase_receipt_trends', current_setting('test.filters')::jsonb) ->> 'available')::boolean,
  false,
  'purchase receipt trends are not built'
);
select is(
  (public.chart_stock('delivery_trends', current_setting('test.filters')::jsonb) ->> 'available')::boolean,
  false,
  'delivery trends are not built'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008102","role":"authenticated"}', true);
select throws_ok(
  format(
    'select public.card_stock(%L::jsonb)',
    current_setting('test.filters')::jsonb
  ),
  'P0001',
  'dash_company: Company is mandatory',
  'a user outside the organization cannot read the company'
);

select * from finish();
rollback;
