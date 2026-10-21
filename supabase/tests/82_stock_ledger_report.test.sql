begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008201', 'stock82@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008202', 'stock82-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008201","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Ledger Co", "slug": "stock-82", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Ledger Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
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

insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000082a1', current_setting('test.org')::uuid, 'Group 82', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, true);
insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000082a2', current_setting('test.org')::uuid, 'Leaf 82', current_setting('test.company')::uuid, '20000000-0000-0000-0000-0000000082a1', false),
  ('20000000-0000-0000-0000-0000000082a3', current_setting('test.org')::uuid, 'Side 82', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false);

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id
) values
  ('20000000-0000-0000-0000-0000000082d1', current_setting('test.org')::uuid, 'IN-82', 'IN-82', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000082d2', current_setting('test.org')::uuid, 'OTHER-82', 'OTHER-82', current_setting('test.products')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000082d3', current_setting('test.org')::uuid, 'SIDE-82', 'SIDE-82', current_setting('test.products')::uuid, current_setting('test.nos')::uuid);

insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000082d1', '20000000-0000-0000-0000-0000000082a2',
    current_date, '10:00', current_date + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000082f1', 'IN-1', 4, 4, 2, 2, 8, 8,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000082d1', '20000000-0000-0000-0000-0000000082a2',
    current_date - 40, '10:00', (current_date - 40) + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000082f2', 'OLD-1', 1, 1, 2, 2, 2, 2,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000082d1', '20000000-0000-0000-0000-0000000082a2',
    current_date, '09:00', current_date + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000082f3', 'CAN-1', 9, 9, 2, 2, 18, 18,
    current_setting('test.nos')::uuid, true
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000082d2', '20000000-0000-0000-0000-0000000082a2',
    current_date, '11:00', current_date + time '11:00',
    'Stock Reconciliation', '20000000-0000-0000-0000-0000000082f4', 'REC-1', 3, 3, 1, 1, 3, 3,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000082d3', '20000000-0000-0000-0000-0000000082a3',
    current_date, '12:00', current_date + time '12:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000082f5', 'SIDE-1', 7, 7, 1, 1, 7, 7,
    current_setting('test.nos')::uuid, false
  );

select set_config('test.filters', jsonb_build_object(
  'company', current_setting('test.company'),
  'from_date', (current_date - 5)::text,
  'to_date', current_date::text
)::text, true);

set local role authenticated;

select throws_ok(
  $$ select public.report_stock_ledger('{}'::jsonb) $$,
  'P0001',
  'sle_company: Company is mandatory',
  'a missing company is rejected'
);
select throws_ok(
  format(
    'select public.report_stock_ledger(%L::jsonb)',
    jsonb_build_object(
      'company', current_setting('test.company'),
      'from_date', current_date,
      'to_date', current_date - 1
    )
  ),
  'P0001',
  'sle_dates: From Date must be before To Date',
  'a from-date after the to-date is rejected'
);

select is(
  public.report_stock_ledger(current_setting('test.filters')::jsonb) #>> '{rows,0,item}',
  'IN-82',
  'a receipt inside the range is first'
);
select is(
  (public.report_stock_ledger(current_setting('test.filters')::jsonb) #>> '{rows,0,qty}')::numeric,
  4::numeric,
  'qty is the movement'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(public.report_stock_ledger(current_setting('test.filters')::jsonb) -> 'rows') entry
     where entry ->> 'voucher' = 'OLD-1'
  ),
  'a row before the from-date is excluded'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(public.report_stock_ledger(current_setting('test.filters')::jsonb) -> 'rows') entry
     where entry ->> 'voucher' = 'CAN-1'
  ),
  'a cancelled row is excluded'
);

select is(
  jsonb_array_length(
    public.report_stock_ledger(
      current_setting('test.filters')::jsonb || jsonb_build_object('item', '20000000-0000-0000-0000-0000000082d1')
    ) -> 'rows'
  ),
  1,
  'an item filter keeps one row'
);
select is(
  public.report_stock_ledger(
    current_setting('test.filters')::jsonb || jsonb_build_object('item', '20000000-0000-0000-0000-0000000082d1')
  ) #>> '{rows,0,voucher}',
  'IN-1',
  'an item filter keeps that item'
);

select ok(
  exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_ledger(
          current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000082a1')
        ) -> 'rows'
      ) entry
     where entry ->> 'voucher' = 'IN-1'
  ),
  'a group warehouse includes its child'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_ledger(
          current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000082a1')
        ) -> 'rows'
      ) entry
     where entry ->> 'voucher' = 'SIDE-1'
  ),
  'a sibling warehouse is left out of the group'
);

select is(
  jsonb_array_length(
    public.report_stock_ledger(
      current_setting('test.filters')::jsonb || jsonb_build_object('voucher_type', 'Stock Reconciliation')
    ) -> 'rows'
  ),
  1,
  'a voucher type keeps one row'
);
select is(
  public.report_stock_ledger(
    current_setting('test.filters')::jsonb || jsonb_build_object('voucher_type', 'Stock Reconciliation')
  ) #>> '{rows,0,voucher}',
  'REC-1',
  'a voucher type filter matches that type'
);

select is(
  jsonb_array_length(
    public.report_stock_ledger(jsonb_build_object(
      'company', current_setting('test.company'),
      'from_date', (current_date + 10)::text,
      'to_date', (current_date + 10)::text
    )) -> 'rows'
  ),
  0,
  'an empty range returns no rows'
);
select is(
  public.report_stock_ledger(jsonb_build_object(
    'company', current_setting('test.company'),
    'from_date', current_date::text,
    'to_date', current_date::text
  )) #>> '{rows,0,item}',
  'IN-82',
  'a from-date equal to the to-date still lists that day'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008202","role":"authenticated"}', true);
select throws_ok(
  format(
    'select public.report_stock_ledger(%L::jsonb)',
    current_setting('test.filters')::jsonb
  ),
  'P0001',
  'sle_company: Company is mandatory',
  'a user outside the organization cannot read the company'
);

select * from finish();
rollback;
