begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007301', 'stock73@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007302', 'stock73-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007301","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Ledger Co", "slug": "stock-73", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Ledger Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
select set_config('test.group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.wh', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Stores'
), true);

insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, valuation_method) values
  ('20000000-0000-0000-0000-0000000073d1', current_setting('test.org')::uuid, 'FIFO-73', 'FIFO-73', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000073d2', current_setting('test.org')::uuid, 'MA-73', 'MA-73', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, 'Moving Average'),
  ('20000000-0000-0000-0000-0000000073d3', current_setting('test.org')::uuid, 'BACK-73', 'BACK-73', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000073d4', current_setting('test.org')::uuid, 'CAN-73', 'CAN-73', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000073d5', current_setting('test.org')::uuid, 'FRZ-73', 'FRZ-73', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, null);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007301","role":"authenticated"}', true);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d1',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-02-01',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073a1', 'voucher_no', 'SLE-1'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d1',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 8,
    'posting_date', '2026-02-02',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073a2', 'voucher_no', 'SLE-2'
  )));
end
$$;

select is(
  (
    select s.qty_after_transaction = 20
       and s.stock_value = 130
       and s.valuation_rate = 6.5
       and (s.stock_queue -> 0 ->> 0)::numeric = 10
       and (s.stock_queue -> 0 ->> 1)::numeric = 5
       and (s.stock_queue -> 1 ->> 0)::numeric = 10
       and (s.stock_queue -> 1 ->> 1)::numeric = 8
       and exists (
         select 1 from public.bin b
          where b.item_id = s.item_id and b.warehouse_id = s.warehouse_id
            and b.actual_qty = 20 and b.stock_value = 130 and b.valuation_rate = 6.5
            and b.projected_qty = b.actual_qty and b.ordered_qty = 0 and b.reserved_qty = 0
       )
      from public.stock_ledger_entry s
     where s.voucher_id = '10000000-0000-0000-0000-0000000073a2' and not s.is_cancelled
  ),
  true,
  'FIFO receipts of 10 at 5 and 10 at 8 leave qty 20 and value 130'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d1',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', -15,
    'posting_date', '2026-02-03',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073a3', 'voucher_no', 'SLE-3'
  )));
end
$$;

select is(
  (
    select s.qty_after_transaction = 5
       and s.stock_value = 40
       and s.outgoing_rate = 6
       and jsonb_array_length(s.stock_queue) = 1
       and (s.stock_queue -> 0 ->> 0)::numeric = 5
       and (s.stock_queue -> 0 ->> 1)::numeric = 8
       and exists (
         select 1 from public.bin b
          where b.item_id = s.item_id and b.actual_qty = 5 and b.stock_value = 40
       )
      from public.stock_ledger_entry s
     where s.voucher_id = '10000000-0000-0000-0000-0000000073a3' and not s.is_cancelled
  ),
  true,
  'an outward of 15 consumes the first FIFO bucket and part of the second'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d2',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-02-10',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073b1', 'voucher_no', 'MA-1'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d2',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 15,
    'posting_date', '2026-02-11',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073b2', 'voucher_no', 'MA-2'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d2',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', -5,
    'posting_date', '2026-02-12',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073b3', 'voucher_no', 'MA-3'
  )));
end
$$;

select is(
  (
    select
      (select qty_after_transaction = 20 and stock_value = 200 and valuation_rate = 10
         from public.stock_ledger_entry where voucher_id = '10000000-0000-0000-0000-0000000073b2')
      and
      (select qty_after_transaction = 15 and stock_value = 150 and valuation_rate = 10 and outgoing_rate = 10
         from public.stock_ledger_entry where voucher_id = '10000000-0000-0000-0000-0000000073b3')
  ),
  true,
  'moving average recomputes on inward and keeps the rate on outward'
);

select throws_ok(
  $$select app.make_sl_entries(jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000073d1',
      'warehouse_id', current_setting('test.wh'),
      'actual_qty', -10,
      'posting_date', '2026-02-04',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073a4', 'voucher_no', 'SLE-4'
    )))$$,
  'P0001', null,
  'negative stock is rejected while both flags are off'
);

reset role;
update public.stock_settings set allow_negative_stock = true where org_id = current_setting('test.org')::uuid;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007301","role":"authenticated"}', true);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d1',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', -10,
    'posting_date', '2026-02-05',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073a5', 'voucher_no', 'SLE-5'
  )));
end
$$;

select is(
  (
    select s.qty_after_transaction = -5 and s.stock_value = -40 and s.valuation_rate = 8
       and exists (
         select 1 from public.bin b
          where b.item_id = s.item_id and b.actual_qty = -5 and b.stock_value = -40
       )
      from public.stock_ledger_entry s
     where s.voucher_id = '10000000-0000-0000-0000-0000000073a5' and not s.is_cancelled
  ),
  true,
  'a shortfall posts at the last rate when Stock Settings allows negative stock'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d3',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 10,
    'posting_date', '2026-03-02',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073c2', 'voucher_no', 'BACK-2'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d3',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', -4,
    'posting_date', '2026-03-03',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073c3', 'voucher_no', 'BACK-3'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d3',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 2,
    'posting_date', '2026-03-01',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073c1', 'voucher_no', 'BACK-1'
  )));
end
$$;

select is(
  (
    select outgoing_rate = 2 and qty_after_transaction = 16 and stock_value = 112
      from public.stock_ledger_entry
     where voucher_id = '10000000-0000-0000-0000-0000000073c3' and not is_cancelled
  ),
  true,
  'a backdated inward reposts the later outward'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d4',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-04-01',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073e1', 'voucher_no', 'CAN-1'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000073d4',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 8,
    'posting_date', '2026-04-02',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073e2', 'voucher_no', 'CAN-2'
  )));
  perform app.make_sl_entries(
    jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000073d4',
      'warehouse_id', current_setting('test.wh'),
      'actual_qty', 10,
      'posting_date', '2026-04-02',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073e2', 'voucher_no', 'CAN-2'
    )),
    '{"is_cancelled": true}'::jsonb
  );
end
$$;

select is(
  (
    select
      (select count(*) = 2 and bool_and(is_cancelled)
         from public.stock_ledger_entry where voucher_id = '10000000-0000-0000-0000-0000000073e2')
      and
      (select not is_cancelled from public.stock_ledger_entry where voucher_id = '10000000-0000-0000-0000-0000000073e1')
      and
      (select actual_qty = 10 and stock_value = 50
         from public.bin where item_id = '20000000-0000-0000-0000-0000000073d4')
  ),
  true,
  'cancel flags the original and the reversal and restores the bin'
);

reset role;
update public.stock_settings set stock_frozen_upto = '2026-05-01' where org_id = current_setting('test.org')::uuid;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007301","role":"authenticated"}', true);

select throws_ok(
  $$select app.make_sl_entries(jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000073d5',
      'warehouse_id', current_setting('test.wh'),
      'actual_qty', 1, 'incoming_rate', 1,
      'posting_date', '2026-05-01',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000073f1', 'voucher_no', 'FRZ-1'
    )))$$,
  'P0001', null,
  'a frozen date blocks a caller without stock_auth_role'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007302","role":"authenticated"}', true);
select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Stock Ledger Other", "slug": "stock-73-b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Ledger Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select is(
  (
    select (select count(*) from public.stock_ledger_entry where org_id = current_setting('test.org')::uuid) = 0
       and (select count(*) from public.bin where org_id = current_setting('test.org')::uuid) = 0
  ),
  true,
  'another organization cannot see the rows'
);

reset role;
select throws_ok(
  $$update public.stock_ledger_entry set actual_qty = actual_qty + 1 where voucher_no = 'SLE-1'$$,
  'P0001', null,
  'a direct qty update is rejected'
);

select * from finish();
rollback;
