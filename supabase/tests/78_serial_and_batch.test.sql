begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007801', 'stock78@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007802', 'stock78-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007801","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Serial Batch Co", "slug": "stock-78", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Serial Batch Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Stock Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007801';
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
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000078c9', current_setting('test.org')::uuid, 'Temporary Opening',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Temporary'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;
insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id, has_serial_no, has_batch_no
) values
  ('20000000-0000-0000-0000-0000000078d1', current_setting('test.org')::uuid, 'SER-78', 'SER-78', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, true, false),
  ('20000000-0000-0000-0000-0000000078d2', current_setting('test.org')::uuid, 'BAT-78', 'BAT-78', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false, true),
  ('20000000-0000-0000-0000-0000000078d3', current_setting('test.org')::uuid, 'OPEN-78', 'OPEN-78', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false, true);
insert into public.batch (id, org_id, name, batch_id, item_id, expiry_date) values
  ('20000000-0000-0000-0000-0000000078b1', current_setting('test.org')::uuid, 'EXP-78', 'EXP-78', '20000000-0000-0000-0000-0000000078d2', '2026-01-01'),
  ('20000000-0000-0000-0000-0000000078b2', current_setting('test.org')::uuid, 'FRESH-78', 'FRESH-78', '20000000-0000-0000-0000-0000000078d2', '2026-12-31');
select set_config('test.receipt_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.purpose = 'Material Receipt'
), true);
select set_config('test.issue_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.purpose = 'Material Issue'
), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007801","role":"authenticated"}', true);

select set_config('test.missing', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d1',
      'qty', 1, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select throws_ok(
  $$select public.submit_doc('Stock Entry', current_setting('test.missing')::uuid)$$,
  'P0001',
  'sabb_serial: Serial numbers are required for SER-78',
  'a receipt without serials is rejected'
);

select set_config('test.old', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d1',
      'qty', 1, 'basic_rate', 5, 'serial_no', 'SN-A',
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.old_submitted', public.submit_doc('Stock Entry', current_setting('test.old')::uuid)::text, true);
select set_config('test.new', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-02',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d1',
      'qty', 1, 'basic_rate', 5, 'serial_no', 'SN-B',
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.new_submitted', public.submit_doc('Stock Entry', current_setting('test.new')::uuid)::text, true);

select is(
  (
    select (select s.warehouse_id = current_setting('test.wh')::uuid and s.purchase_rate = 5
              from public.serial_no s where s.org_id = current_setting('test.org')::uuid and s.name = 'SN-A')
       and (select s.warehouse_id = current_setting('test.wh')::uuid and s.purchase_rate = 5
              from public.serial_no s where s.org_id = current_setting('test.org')::uuid and s.name = 'SN-B')
       and (select sle.valuation_rate = 5 and sle.incoming_rate = 5 and sle.serial_and_batch_bundle_id is not null
              from public.stock_ledger_entry sle
             where sle.voucher_id = current_setting('test.old')::uuid and not sle.is_cancelled)
       and (select b.name like 'SABB-%' and b.docstatus = 1 and b.total_qty = 1
              from public.serial_and_batch_bundle b
              join public.stock_ledger_entry sle on sle.serial_and_batch_bundle_id = b.id
             where sle.voucher_id = current_setting('test.new')::uuid and not sle.is_cancelled)
  ),
  true,
  'a receipt of two serials sets the warehouse and keeps the typed rate'
);

select set_config('test.issue', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.issue_type')::uuid,
    'posting_date', '2026-03-03',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d1',
      'qty', 1,
      's_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.issue_submitted', public.submit_doc('Stock Entry', current_setting('test.issue')::uuid)::text, true);

select is(
  (
    select (select s.warehouse_id is null from public.serial_no s
             where s.org_id = current_setting('test.org')::uuid and s.name = 'SN-A')
       and (select s.warehouse_id = current_setting('test.wh')::uuid from public.serial_no s
             where s.org_id = current_setting('test.org')::uuid and s.name = 'SN-B')
       and (select d.serial_no = 'SN-A' from public.stock_entry_detail d
             where d.parent_id = current_setting('test.issue')::uuid)
  ),
  true,
  'an issue auto-picks the oldest serial and clears its warehouse'
);

select set_config('test.issue_cancelled', public.cancel_doc('Stock Entry', current_setting('test.issue')::uuid)::text, true);

select is(
  (
    select s.warehouse_id = current_setting('test.wh')::uuid
      from public.serial_no s
     where s.org_id = current_setting('test.org')::uuid and s.name = 'SN-A'
  ),
  true,
  'cancelling the issue restores the serial warehouse'
);

select set_config('test.exp', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-02-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d2',
      'qty', 5, 'basic_rate', 2, 'batch_no', 'EXP-78',
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.exp_submitted', public.submit_doc('Stock Entry', current_setting('test.exp')::uuid)::text, true);
select set_config('test.fresh', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-02-02',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d2',
      'qty', 5, 'basic_rate', 3, 'batch_no', 'FRESH-78',
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.fresh_submitted', public.submit_doc('Stock Entry', current_setting('test.fresh')::uuid)::text, true);
select set_config('test.pick', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.issue_type')::uuid,
    'posting_date', '2026-03-04',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d2',
      'qty', 5,
      's_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.pick_submitted', public.submit_doc('Stock Entry', current_setting('test.pick')::uuid)::text, true);

select is(
  (
    select (select b.batch_qty = 5 from public.batch b where b.id = '20000000-0000-0000-0000-0000000078b1')
       and (select b.batch_qty = 0 from public.batch b where b.id = '20000000-0000-0000-0000-0000000078b2')
       and (select d.batch_no = 'FRESH-78' from public.stock_entry_detail d
             where d.parent_id = current_setting('test.pick')::uuid)
  ),
  true,
  'an expired batch is skipped and the later batch is issued'
);

select set_config('test.open_missing', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Opening Stock',
    'posting_date', '2026-01-15',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d3',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 4, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select throws_ok(
  $$select public.submit_doc('Stock Reconciliation', current_setting('test.open_missing')::uuid)$$,
  'P0001',
  'sabb_batch: Batch is required for OPEN-78',
  'an opening reconciliation without a batch is rejected'
);

select set_config('test.open', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Opening Stock',
    'posting_date', '2026-01-16',
    'posting_time', '10:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d3',
      'warehouse_id', current_setting('test.wh')::uuid,
      'qty', 4, 'valuation_rate', 5, 'batch_no', 'OPEN-B'
    ))
  )) ->> 'id'
), true);
select set_config('test.open_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.open')::uuid)::text, true);

select is(
  (
    select (select b.batch_qty = 4 and b.item_id = '20000000-0000-0000-0000-0000000078d3'
              from public.batch b
             where b.org_id = current_setting('test.org')::uuid and b.name = 'OPEN-B')
       and (select bin.actual_qty = 4 from public.bin bin
             where bin.item_id = '20000000-0000-0000-0000-0000000078d3'
               and bin.warehouse_id = current_setting('test.wh')::uuid)
  ),
  true,
  'an opening reconciliation with a batch receives that batch'
);

select set_config('test.again', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-05',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000078d1',
      'qty', 1, 'basic_rate', 5, 'serial_no', 'SN-B',
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select throws_ok(
  $$select public.submit_doc('Stock Entry', current_setting('test.again')::uuid)$$,
  'P0001',
  'sabb_serial: Serial SN-B is already in stock',
  'a second receipt of an in-stock serial is rejected'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007802","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.serial_no),
  0,
  'a user outside the organization cannot read the serial'
);

select * from finish();
rollback;
