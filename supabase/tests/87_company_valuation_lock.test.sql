begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008701', 'company87@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008701","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Valuation Co", "slug": "company-87", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Valuation Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.other_name',
  public.create_company(jsonb_build_object(
    'org_id', current_setting('test.org'),
    'company_name', 'Other 87',
    'abbr', 'O87',
    'default_currency', 'PHP',
    'country', 'Philippines'
  )) ->> 'name',
  true
);
select set_config(
  'test.own_name',
  public.create_company(jsonb_build_object(
    'org_id', current_setting('test.org'),
    'company_name', 'Own 87',
    'abbr', 'W87',
    'default_currency', 'PHP',
    'country', 'Philippines'
  )) ->> 'name',
  true
);

reset role;
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid and c.company_name = 'Valuation Co'
), true);
select set_config('test.other', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid and c.company_name = 'Other 87'
), true);
select set_config('test.own', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid and c.company_name = 'Own 87'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and not w.is_group
   order by w.name
   limit 1
), true);
select set_config('test.other_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.other')::uuid and not w.is_group
   order by w.name
   limit 1
), true);
select set_config('test.own_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.own')::uuid and not w.is_group
   order by w.name
   limit 1
), true);

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id, valuation_method
) values
  ('20000000-0000-0000-0000-0000000087d1', current_setting('test.org')::uuid, 'OWN-87', 'OWN-87', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, 'Moving Average'),
  ('20000000-0000-0000-0000-0000000087d2', current_setting('test.org')::uuid, 'CAN-87', 'CAN-87', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000087d3', current_setting('test.org')::uuid, 'LIVE-87', 'LIVE-87', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000087d4', current_setting('test.org')::uuid, 'SIDE-87', 'SIDE-87', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008701","role":"authenticated"}', true);

select lives_ok(
  format(
    'update public.companies set valuation_method = %L where id = %L::uuid',
    'Moving Average',
    current_setting('test.company')
  ),
  'a company with no ledger can change its valuation method'
);
select lives_ok(
  format(
    'update public.companies set enable_perpetual_inventory = false where id = %L::uuid',
    current_setting('test.company')
  ),
  'a company with no ledger can turn perpetual inventory off'
);
update public.companies
   set enable_perpetual_inventory = true
 where id = current_setting('test.company')::uuid;

reset role;
insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values (
  current_setting('test.org')::uuid, current_setting('test.other')::uuid,
  '20000000-0000-0000-0000-0000000087d4', current_setting('test.other_wh')::uuid,
  current_date, '09:00', current_date + time '09:00',
  'Stock Entry', '20000000-0000-0000-0000-0000000087f4', 'SIDE-87', 1, 1, 1, 1, 1, 1,
  current_setting('test.nos')::uuid, false
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008701","role":"authenticated"}', true);
select lives_ok(
  format(
    'update public.companies set valuation_method = %L where id = %L::uuid',
    'LIFO',
    current_setting('test.company')
  ),
  'a ledger row on another company does not block this company'
);

reset role;
insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values (
  current_setting('test.org')::uuid, current_setting('test.own')::uuid,
  '20000000-0000-0000-0000-0000000087d1', current_setting('test.own_wh')::uuid,
  current_date, '10:00', current_date + time '10:00',
  'Stock Entry', '20000000-0000-0000-0000-0000000087f1', 'OWN-87', 2, 2, 1, 1, 2, 2,
  current_setting('test.nos')::uuid, false
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008701","role":"authenticated"}', true);
select lives_ok(
  format(
    'update public.companies set valuation_method = %L where id = %L::uuid',
    'LIFO',
    current_setting('test.own')
  ),
  'an item with its own valuation method does not block the company method'
);

reset role;
insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values (
  current_setting('test.org')::uuid, current_setting('test.company')::uuid,
  '20000000-0000-0000-0000-0000000087d2', current_setting('test.wh')::uuid,
  current_date, '11:00', current_date + time '11:00',
  'Stock Entry', '20000000-0000-0000-0000-0000000087f2', 'CAN-87', 3, 3, 1, 1, 3, 3,
  current_setting('test.nos')::uuid, true
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008701","role":"authenticated"}', true);
select throws_ok(
  format(
    'update public.companies set valuation_method = %L where id = %L::uuid',
    'FIFO',
    current_setting('test.company')
  ),
  'P0001',
  'company_valuation: Can''t change the valuation method, as there are transactions against some items which do not have its own valuation method',
  'a cancelled row for an item with no method blocks the valuation method'
);
select lives_ok(
  format(
    'update public.companies set enable_perpetual_inventory = false where id = %L::uuid',
    current_setting('test.company')
  ),
  'a cancelled row still allows perpetual inventory to be turned off'
);
update public.companies
   set enable_perpetual_inventory = true
 where id = current_setting('test.company')::uuid;

reset role;
insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values (
  current_setting('test.org')::uuid, current_setting('test.company')::uuid,
  '20000000-0000-0000-0000-0000000087d3', current_setting('test.wh')::uuid,
  current_date, '12:00', current_date + time '12:00',
  'Stock Entry', '20000000-0000-0000-0000-0000000087f3', 'LIVE-87', 4, 4, 1, 1, 4, 4,
  current_setting('test.nos')::uuid, false
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008701","role":"authenticated"}', true);
select throws_ok(
  format(
    'update public.companies set enable_perpetual_inventory = false where id = %L::uuid',
    current_setting('test.company')
  ),
  'P0001',
  'company_perpetual: Cannot disable perpetual inventory, as there are existing Stock Ledger Entries for the company Valuation Co. Please cancel the stock transactions first and try again.',
  'a live row blocks turning perpetual inventory off'
);
select throws_ok(
  format(
    'update public.companies set enable_item_wise_inventory_account = true where id = %L::uuid',
    current_setting('test.company')
  ),
  'P0001',
  'company_inventory: Cannot enable Item-wise Inventory Account, as there are existing Stock Ledger Entries for the company Valuation Co with Warehouse-wise Inventory Account. Please cancel the stock transactions first and try again.',
  'a live row blocks the item-wise inventory account flag'
);

select * from finish();
rollback;
