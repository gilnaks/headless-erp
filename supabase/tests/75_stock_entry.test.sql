begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007501', 'stock75@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007502', 'stock75-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007501","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Entry Co", "slug": "stock-75", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Entry Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Stock User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007501';
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
select set_config('test.wip', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Work In Progress'
), true);
select set_config('test.fg', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Finished Goods'
), true);
select set_config('test.git', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Goods In Transit'
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
  select '20000000-0000-0000-0000-0000000075c1', current_setting('test.org')::uuid, 'WIP Stock',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Stock'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000075c9', current_setting('test.org')::uuid, 'Temporary Opening',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Temporary'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000075c2', current_setting('test.org')::uuid, 'Freight',
         current_setting('test.company')::uuid, a.parent_id, 'Expense', 'Expense Account'
    from public.account a
   where a.id = current_setting('test.adj')::uuid;
update public.warehouse
   set account_id = '20000000-0000-0000-0000-0000000075c1'
 where org_id = current_setting('test.org')::uuid and warehouse_name = 'Work In Progress';
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  ('20000000-0000-0000-0000-0000000075d1', current_setting('test.org')::uuid, 'REC-75', 'REC-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000075d2', current_setting('test.org')::uuid, 'OPEN-75', 'OPEN-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000075d3', current_setting('test.org')::uuid, 'XFER-75', 'XFER-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000075d4', current_setting('test.org')::uuid, 'SAME-75', 'SAME-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000075d5', current_setting('test.org')::uuid, 'ADD-75', 'ADD-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000075d6', current_setting('test.org')::uuid, 'TRN-75', 'TRN-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000075d7', current_setting('test.org')::uuid, 'CAN-75', 'CAN-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000075d8', current_setting('test.org')::uuid, 'MFG-75', 'MFG-75', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
select set_config('test.receipt_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.name = 'Material Receipt'
), true);
select set_config('test.issue_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.name = 'Material Issue'
), true);
select set_config('test.transfer_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.name = 'Material Transfer'
), true);
select set_config('test.mfg_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.name = 'Manufacture'
), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007501","role":"authenticated"}', true);

select set_config('test.receipt', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d1',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.receipt_submitted', public.submit_doc('Stock Entry', current_setting('test.receipt')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.receipt')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 50
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.receipt')::uuid
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 50
       and (select d.amount = 50 and d.basic_rate = 5 from public.stock_entry_detail d
             where d.parent_id = current_setting('test.receipt')::uuid)
       and (select e.name like 'MAT-STE-2026-%' and e.docstatus = 1 from public.stock_entry e
             where e.id = current_setting('test.receipt')::uuid)
  ),
  true,
  'a receipt debits inventory, credits stock adjustment, and keeps the incoming rate'
);

select set_config('test.issue', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.issue_type')::uuid,
    'posting_date', '2026-03-02',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d1',
      'qty', 4, 'basic_rate', 99,
      's_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.issue_submitted', public.submit_doc('Stock Entry', current_setting('test.issue')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.issue')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 20
       and (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.issue')::uuid
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 20
       and (select d.basic_rate = 5 and d.amount = 20 from public.stock_entry_detail d
             where d.parent_id = current_setting('test.issue')::uuid)
  ),
  true,
  'an issue credits inventory at the valued rate and ignores the typed rate'
);

select set_config('test.xfer_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d3',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.xfer_in_submitted', public.submit_doc('Stock Entry', current_setting('test.xfer_in')::uuid)::text, true);
select set_config('test.xfer', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.transfer_type')::uuid,
    'posting_date', '2026-03-02',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d3',
      'qty', 10,
      's_warehouse_id', current_setting('test.wh')::uuid,
      't_warehouse_id', current_setting('test.wip')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.xfer_submitted', public.submit_doc('Stock Entry', current_setting('test.xfer')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.xfer')::uuid
               and g.account_id = '20000000-0000-0000-0000-0000000075c1' and not g.is_cancelled) = 50
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.xfer')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 50
       and (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.xfer')::uuid
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 0
  ),
  true,
  'a transfer debits the target warehouse account and credits the source'
);

select set_config('test.same_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d4',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.same_in_submitted', public.submit_doc('Stock Entry', current_setting('test.same_in')::uuid)::text, true);
select set_config('test.same', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.transfer_type')::uuid,
    'posting_date', '2026-03-03',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d4',
      'qty', 10,
      's_warehouse_id', current_setting('test.wh')::uuid,
      't_warehouse_id', current_setting('test.fg')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.same_submitted', public.submit_doc('Stock Entry', current_setting('test.same')::uuid)::text, true);

select is(
  (select count(*)::int from public.gl_entry g
    where g.voucher_id = current_setting('test.same')::uuid and not g.is_cancelled),
  0,
  'a transfer between warehouses on the same account posts no stock GL'
);

select set_config('test.opening', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-01-02',
    'is_opening', 'Yes',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d2',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.opening_submitted', public.submit_doc('Stock Entry', current_setting('test.opening')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.opening')::uuid
               and g.account_id = '20000000-0000-0000-0000-0000000075c9' and not g.is_cancelled) = 50
       and (select count(*) from public.gl_entry g
             where g.voucher_id = current_setting('test.opening')::uuid
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 0
  ),
  true,
  'an opening receipt credits temporary opening'
);

select set_config('test.bad', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.issue_type')::uuid,
    'posting_date', '2026-03-02',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d1',
      'qty', 1,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select throws_ok(
  $$select public.submit_doc('Stock Entry', current_setting('test.bad')::uuid)$$,
  'P0001',
  'ste_warehouse: Material Issue needs a source warehouse only',
  'a material issue without a source warehouse is rejected'
);

select set_config('test.add', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-04',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d5',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    )),
    'additional_costs', jsonb_build_array(jsonb_build_object(
      'expense_account_id', '20000000-0000-0000-0000-0000000075c2',
      'amount', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.add_submitted', public.submit_doc('Stock Entry', current_setting('test.add')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.add')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 60
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.add')::uuid
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 50
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.add')::uuid
               and g.account_id = '20000000-0000-0000-0000-0000000075c2' and not g.is_cancelled) = 10
       and (select d.basic_rate = 5 and d.additional_cost = 10 and d.amount = 60
             from public.stock_entry_detail d where d.parent_id = current_setting('test.add')::uuid)
  ),
  true,
  'additional cost stays in stock value and is reclassified off stock adjustment'
);

select set_config('test.trn_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d6',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.trn_in_submitted', public.submit_doc('Stock Entry', current_setting('test.trn_in')::uuid)::text, true);
select set_config('test.trn', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.transfer_type')::uuid,
    'posting_date', '2026-03-05',
    'add_to_transit', true,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d6',
      'qty', 10,
      's_warehouse_id', current_setting('test.wh')::uuid,
      't_warehouse_id', current_setting('test.fg')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.trn_submitted', public.submit_doc('Stock Entry', current_setting('test.trn')::uuid)::text, true);
select set_config('test.trn2', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.transfer_type')::uuid,
    'posting_date', '2026-03-06',
    'outgoing_stock_entry_id', current_setting('test.trn')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d6',
      'qty', 10,
      's_warehouse_id', current_setting('test.git')::uuid,
      't_warehouse_id', current_setting('test.fg')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.trn2_submitted', public.submit_doc('Stock Entry', current_setting('test.trn2')::uuid)::text, true);

select is(
  (
    select (select d.t_warehouse_id = current_setting('test.git')::uuid and d.per_transferred = 10
              from public.stock_entry_detail d where d.parent_id = current_setting('test.trn')::uuid)
       and (select b.actual_qty from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000075d6'
               and b.warehouse_id = current_setting('test.git')::uuid) = 0
       and (select b.actual_qty from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000075d6'
               and b.warehouse_id = current_setting('test.fg')::uuid) = 10
  ),
  true,
  'transit receives into Goods In Transit and the next transfer moves it on'
);

select throws_ok(
  $$select public.cancel_doc('Stock Entry', current_setting('test.trn')::uuid)$$,
  'P0001',
  'ste_transit: Cancel the later transfer first',
  'a transit entry that has been received further cannot be cancelled first'
);

select set_config('test.trn2_cancelled', public.cancel_doc('Stock Entry', current_setting('test.trn2')::uuid)::text, true);

select is(
  (
    select (select d.per_transferred = 0 from public.stock_entry_detail d
              where d.parent_id = current_setting('test.trn')::uuid)
       and (select b.actual_qty from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000075d6'
               and b.warehouse_id = current_setting('test.git')::uuid) = 10
  ),
  true,
  'cancelling the second transit entry returns the quantity and clears per transferred'
);

select set_config('test.mfg_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-01',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d8',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wip')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.mfg_in_submitted', public.submit_doc('Stock Entry', current_setting('test.mfg_in')::uuid)::text, true);
select set_config('test.mfg', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.mfg_type')::uuid,
    'posting_date', '2026-03-08',
    'items', jsonb_build_array(
      jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000075d8',
        'qty', 10,
        's_warehouse_id', current_setting('test.wip')::uuid,
        'uom_id', current_setting('test.nos')::uuid
      ),
      jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000075d8',
        'qty', 1, 'is_finished_item', true,
        't_warehouse_id', current_setting('test.fg')::uuid,
        'uom_id', current_setting('test.nos')::uuid
      )
    )
  )) ->> 'id'
), true);
select set_config('test.mfg_submitted', public.submit_doc('Stock Entry', current_setting('test.mfg')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.debit - g.credit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.mfg')::uuid
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 50
       and (select coalesce(sum(g.credit - g.debit), 0) from public.gl_entry g
             where g.voucher_id = current_setting('test.mfg')::uuid
               and g.account_id = '20000000-0000-0000-0000-0000000075c1' and not g.is_cancelled) = 50
       and (select d.valuation_rate = 50 from public.stock_entry_detail d
             where d.parent_id = current_setting('test.mfg')::uuid and d.t_warehouse_id is not null)
  ),
  true,
  'manufacture values the finished row at the source value'
);

select set_config('test.can', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-03-07',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000075d7',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.can_submitted', public.submit_doc('Stock Entry', current_setting('test.can')::uuid)::text, true);
select set_config('test.can_cancelled', public.cancel_doc('Stock Entry', current_setting('test.can')::uuid)::text, true);

select is(
  (
    select (select count(*) from public.stock_ledger_entry s
             where s.voucher_id = current_setting('test.can')::uuid and not s.is_cancelled) = 0
       and (select count(*) from public.gl_entry g
             where g.voucher_id = current_setting('test.can')::uuid and not g.is_cancelled) = 0
       and (select e.docstatus = 2 from public.stock_entry e where e.id = current_setting('test.can')::uuid)
  ),
  true,
  'cancelling a receipt leaves no open stock ledger or general ledger rows'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007502","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.stock_entry where org_id = current_setting('test.org')::uuid),
  0,
  'a user outside the organization cannot read the stock entry'
);

select * from finish();
rollback;
