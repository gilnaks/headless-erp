begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007601', 'stock76@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007602', 'stock76-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007601","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Reconciliation Co", "slug": "stock-76", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Reconciliation Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Stock Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007601';
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
select set_config('test.company', (
  select w.company_id::text from public.warehouse w where w.id = current_setting('test.wh')::uuid
), true);
select set_config('test.inv', (
  select c.default_inventory_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.adj', (
  select c.stock_adjustment_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000076c9', current_setting('test.org')::uuid, 'Temporary Opening',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Temporary'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  ('20000000-0000-0000-0000-0000000076d1', current_setting('test.org')::uuid, 'OPEN-76', 'OPEN-76', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000076d2', current_setting('test.org')::uuid, 'BLOCK-76', 'BLOCK-76', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000076d3', current_setting('test.org')::uuid, 'UP-76', 'UP-76', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000076d4', current_setting('test.org')::uuid, 'DOWN-76', 'DOWN-76', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000076d5', current_setting('test.org')::uuid, 'ADJ-76', 'ADJ-76', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000076d6', current_setting('test.org')::uuid, 'ZERO-76', 'ZERO-76', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000076d7', current_setting('test.org')::uuid, 'CAN-76', 'CAN-76', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
select set_config('test.receipt_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.name = 'Material Receipt'
), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007601","role":"authenticated"}', true);

select set_config('test.open', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Opening Stock',
    'posting_date', '2026-01-15',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d1',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 10, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select set_config('test.open_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.open')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.open')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 50
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.open')::uuid
               and g.account_id = '20000000-0000-0000-0000-0000000076c9' and not g.is_cancelled) = 50
       and (select b.actual_qty = 10 and b.stock_value = 50 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000076d1'
               and b.warehouse_id = current_setting('test.wh')::uuid)
       and (select r.name like 'MAT-RECO-2026-%' and r.docstatus = 1 and r.difference_amount = 50
              from public.stock_reconciliation r where r.id = current_setting('test.open')::uuid)
  ),
  true,
  'opening stock debits inventory and credits Temporary Opening'
);

select set_config('test.block_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-02-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d2',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.block_in_submitted', public.submit_doc('Stock Entry', current_setting('test.block_in')::uuid)::text, true);
select set_config('test.block', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Opening Stock',
    'posting_date', '2026-02-02',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d2',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 10, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select throws_ok(
  $$select public.submit_doc('Stock Reconciliation', current_setting('test.block')::uuid)$$,
  'P0001',
  'reco_opening: Opening Stock is only for an item and warehouse with no stock yet',
  'opening stock is rejected after a receipt'
);

select set_config('test.up_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d3',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.up_in_submitted', public.submit_doc('Stock Entry', current_setting('test.up_in')::uuid)::text, true);
select set_config('test.up', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Stock Reconciliation',
    'posting_date', '2026-03-02',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d3',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 12, 'valuation_rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.up_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.up')::uuid)::text, true);

select is(
  (
    select (select b.actual_qty = 12 and b.stock_value = 120 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000076d3'
               and b.warehouse_id = current_setting('test.wh')::uuid)
       and (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.up')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 70
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.up')::uuid
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 70
       and (select (s.stock_queue -> 0 ->> 0)::numeric = 12 and (s.stock_queue -> 0 ->> 1)::numeric = 10
              and jsonb_array_length(s.stock_queue) = 1
              from public.stock_ledger_entry s
             where s.voucher_id = current_setting('test.up')::uuid and not s.is_cancelled)
       and (select d.quantity_difference = 2 and d.amount_difference = 70
              from public.stock_reconciliation_item d
             where d.parent_id = current_setting('test.up')::uuid)
  ),
  true,
  'a reconciliation sets qty 12 at rate 10 and posts the value difference'
);

select set_config('test.down_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d4',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.down_in_submitted', public.submit_doc('Stock Entry', current_setting('test.down_in')::uuid)::text, true);
select set_config('test.down', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Stock Reconciliation',
    'posting_date', '2026-03-02',
    'posting_time', '11:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d4',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 4, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select set_config('test.down_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.down')::uuid)::text, true);

select is(
  (
    select (select b.actual_qty = 4 and b.stock_value = 20 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000076d4'
               and b.warehouse_id = current_setting('test.wh')::uuid)
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.down')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 30
       and (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.down')::uuid
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 30
  ),
  true,
  'cutting qty from 10 to 4 credits inventory for the value removed'
);

select set_config('test.adj_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-04-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d5',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.adj_in_submitted', public.submit_doc('Stock Entry', current_setting('test.adj_in')::uuid)::text, true);
select set_config('test.adj', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Adjustment Entry',
    'posting_date', '2026-04-02',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d5',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 10, 'valuation_rate', 8
    ))
  )) ->> 'id'
), true);
select set_config('test.adj_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.adj')::uuid)::text, true);

select is(
  (
    select (select b.actual_qty = 10 and b.stock_value = 80 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000076d5'
               and b.warehouse_id = current_setting('test.wh')::uuid)
       and (select s.actual_qty = 0 and s.is_adjustment_entry from public.stock_ledger_entry s
             where s.voucher_id = current_setting('test.adj')::uuid and not s.is_cancelled)
       and (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.adj')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 30
  ),
  true,
  'an adjustment keeps the qty and posts the rate change'
);

select set_config('test.zero_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-05-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d6',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.zero_in_submitted', public.submit_doc('Stock Entry', current_setting('test.zero_in')::uuid)::text, true);
select set_config('test.zero', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Stock Reconciliation',
    'posting_date', '2026-05-02',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d6',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 12, 'valuation_rate', 0
    ))
  )) ->> 'id'
), true);
select throws_ok(
  $$select public.submit_doc('Stock Reconciliation', current_setting('test.zero')::uuid)$$,
  'P0001',
  'reco_rate: Row 1: Valuation Rate is required',
  'a zero rate without the flag is rejected'
);

select set_config('test.can_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-06-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d7',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.can_in_submitted', public.submit_doc('Stock Entry', current_setting('test.can_in')::uuid)::text, true);
select set_config('test.can', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Stock Reconciliation',
    'posting_date', '2026-06-02',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000076d7',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 12, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select set_config('test.can_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.can')::uuid)::text, true);
select set_config('test.can_cancelled', public.cancel_doc('Stock Reconciliation', current_setting('test.can')::uuid)::text, true);

select is(
  (
    select (select count(*) from public.stock_ledger_entry s
             where s.voucher_id = current_setting('test.can')::uuid and not s.is_cancelled) = 0
       and (select count(*) from public.gl_entry g
             where g.voucher_id = current_setting('test.can')::uuid and not g.is_cancelled) = 0
       and (select b.actual_qty = 10 and b.stock_value = 50 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000076d7'
               and b.warehouse_id = current_setting('test.wh')::uuid)
       and (select r.docstatus = 2 from public.stock_reconciliation r where r.id = current_setting('test.can')::uuid)
  ),
  true,
  'cancelling a reconciliation leaves no open stock ledger or general ledger rows'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007602","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.stock_reconciliation where org_id = current_setting('test.org')::uuid),
  0,
  'a user outside the organization cannot read the reconciliation'
);

select * from finish();
rollback;
