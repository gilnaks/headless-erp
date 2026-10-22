begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009401', 'dnstock94@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009401","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "DN Stock Co", "slug": "dn-stock-94", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "DN Stock Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User', 'Stock Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009401';
select set_config('test.group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
   limit 1
), true);
select set_config('test.cogs', (
  select c.default_expense_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.inv', (
  select c.default_inventory_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.sdbnb', (
  select c.stock_delivered_but_not_billed_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.price_list', (
  select p.id::text from public.price_list p
   where p.org_id = current_setting('test.org')::uuid and p.price_list_name = 'Standard Selling'
), true);
select set_config('test.warehouse', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid
     and w.company_id = current_setting('test.company')::uuid
     and w.warehouse_name = 'Stores'
), true);
select set_config('test.transit', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid
     and w.company_id = current_setting('test.company')::uuid
     and w.warehouse_name = 'Goods In Transit'
), true);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  ('20000000-0000-0000-0000-0000000094d1', current_setting('test.org')::uuid, 'DN-94-STK', 'DN-94-STK', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item) values
  ('20000000-0000-0000-0000-0000000094d2', current_setting('test.org')::uuid, 'DN-94-SVC', 'DN-94-SVC', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false),
  ('20000000-0000-0000-0000-0000000094d3', current_setting('test.org')::uuid, 'DN-94-KIT', 'DN-94-KIT', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, has_serial_no) values
  ('20000000-0000-0000-0000-0000000094d4', current_setting('test.org')::uuid, 'DN-94-SER', 'DN-94-SER', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, true);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-0000000094c1', current_setting('test.org')::uuid, 'Acme', 'Acme');
insert into public.product_bundle (id, org_id, new_item_id) values
  ('20000000-0000-0000-0000-0000000094e1', current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000094d3');
insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000094e1', 1, '20000000-0000-0000-0000-0000000094d1', 3);
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000094c9', current_setting('test.org')::uuid, 'Temporary Opening',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Temporary'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000094ca', current_setting('test.org')::uuid, 'Stock Delivered But Not Billed',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Stock Delivered But Not Billed'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009401","role":"authenticated"}', true);
select set_config('test.bundle_submitted', public.submit_doc('Product Bundle', '20000000-0000-0000-0000-0000000094e1')::text, true);
select set_config('test.opening', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Opening Stock',
    'posting_date', (current_date - 1)::text,
    'posting_time', '08:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000094d1',
      'warehouse_id', current_setting('test.warehouse')::uuid,
      'qty', 20, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select set_config('test.opening_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.opening')::uuid)::text, true);

select set_config('test.note', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000094c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000094d1',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.note_submitted', public.submit_doc('Delivery Note', current_setting('test.note')::uuid)::text, true);

select is(
  (
    select (select e.actual_qty = -2 and e.outgoing_rate = 5 and not e.is_cancelled
              from public.stock_ledger_entry e
             where e.voucher_id = current_setting('test.note')::uuid) 
       and (select i.incoming_rate = 5
              from public.delivery_note_item i
             where i.parent_id = current_setting('test.note')::uuid)
       and (select coalesce(sum(g.debit - g.credit), 0) = 10
              from public.gl_entry g
             where g.voucher_id = current_setting('test.note')::uuid
               and g.account_id = current_setting('test.cogs')::uuid
               and not g.is_cancelled)
       and (select coalesce(sum(g.credit - g.debit), 0) = 10
              from public.gl_entry g
             where g.voucher_id = current_setting('test.note')::uuid
               and g.account_id = current_setting('test.inv')::uuid
               and not g.is_cancelled)
       and not exists (
         select 1 from public.gl_entry g
          where g.voucher_id = current_setting('test.note')::uuid and g.party_id is not null
       )
       and (select b.actual_qty = 18
              from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000094d1'
               and b.warehouse_id = current_setting('test.warehouse')::uuid)
  ),
  true,
  'a delivery note issues stock at the valuation rate and debits cost of goods sold'
);

select set_config('test.note_cancelled', public.cancel_doc('Delivery Note', current_setting('test.note')::uuid)::text, true);

select is(
  (
    select not exists (
             select 1 from public.stock_ledger_entry e
              where e.voucher_id = current_setting('test.note')::uuid and not e.is_cancelled
           )
       and not exists (
             select 1 from public.gl_entry g
              where g.voucher_id = current_setting('test.note')::uuid and not g.is_cancelled
           )
       and (select b.actual_qty = 20
              from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000094d1'
               and b.warehouse_id = current_setting('test.warehouse')::uuid)
  ),
  true,
  'cancelling the note restores the bin and leaves no open stock or general ledger'
);

select set_config('test.again', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000094c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000094d1',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.again_submitted', public.submit_doc('Delivery Note', current_setting('test.again')::uuid)::text, true);
select set_config('test.return', (
  public.make_return_doc('Delivery Note', current_setting('test.again')::uuid) ->> 'id'
), true);
select set_config('test.return_submitted', public.submit_doc('Delivery Note', current_setting('test.return')::uuid)::text, true);

select is(
  (
    select (select e.actual_qty = 2 and e.incoming_rate = 5 and not e.is_cancelled
              from public.stock_ledger_entry e
             where e.voucher_id = current_setting('test.return')::uuid)
       and (select i.incoming_rate = 5
              from public.delivery_note_item i
             where i.parent_id = current_setting('test.return')::uuid)
       and (select coalesce(sum(g.debit - g.credit), 0) = 10
              from public.gl_entry g
             where g.voucher_id = current_setting('test.return')::uuid
               and g.account_id = current_setting('test.inv')::uuid
               and not g.is_cancelled)
       and (select coalesce(sum(g.credit - g.debit), 0) = 10
              from public.gl_entry g
             where g.voucher_id = current_setting('test.return')::uuid
               and g.account_id = current_setting('test.cogs')::uuid
               and not g.is_cancelled)
       and (select b.actual_qty = 20
              from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000094d1'
               and b.warehouse_id = current_setting('test.warehouse')::uuid)
  ),
  true,
  'a full return puts the stock back at the original rate'
);

select set_config('test.kit', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000094c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000094d3',
      'qty', 1,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.kit_submitted', public.submit_doc('Delivery Note', current_setting('test.kit')::uuid)::text, true);

select is(
  (
    select (select e.actual_qty = -3 and e.item_id = '20000000-0000-0000-0000-0000000094d1' and not e.is_cancelled
              from public.stock_ledger_entry e
             where e.voucher_id = current_setting('test.kit')::uuid)
       and not exists (
         select 1 from public.stock_ledger_entry e
          where e.voucher_id = current_setting('test.kit')::uuid
            and e.item_id = '20000000-0000-0000-0000-0000000094d3'
       )
       and (select b.actual_qty = 17
              from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000094d1'
               and b.warehouse_id = current_setting('test.warehouse')::uuid)
  ),
  true,
  'a bundle posts the component quantity and does not post the kit'
);

select set_config('test.service', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000094c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000094d2',
      'qty', 1,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.service_submitted', public.submit_doc('Delivery Note', current_setting('test.service')::uuid)::text, true);

select is(
  (
    select not exists (
      select 1 from public.stock_ledger_entry e
       where e.voucher_id = current_setting('test.service')::uuid
    )
  ),
  true,
  'a service item posts no stock'
);

select set_config('test.target', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000094c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'set_target_warehouse_id', current_setting('test.transit')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000094d1',
      'qty', 1,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.target_submitted', public.submit_doc('Delivery Note', current_setting('test.target')::uuid)::text, true);

select is(
  (
    select (select e.actual_qty = -1 and e.outgoing_rate = 5 and not e.is_cancelled
              from public.stock_ledger_entry e
             where e.voucher_id = current_setting('test.target')::uuid
               and e.warehouse_id = current_setting('test.warehouse')::uuid)
       and (select e.actual_qty = 1 and e.incoming_rate = 5 and not e.is_cancelled
              from public.stock_ledger_entry e
             where e.voucher_id = current_setting('test.target')::uuid
               and e.warehouse_id = current_setting('test.transit')::uuid)
       and not exists (
         select 1 from public.gl_entry g
          where g.voucher_id = current_setting('test.target')::uuid and not g.is_cancelled
       )
       and (select b.actual_qty = 16
              from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000094d1'
               and b.warehouse_id = current_setting('test.warehouse')::uuid)
       and (select b.actual_qty = 1
              from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000094d1'
               and b.warehouse_id = current_setting('test.transit')::uuid)
  ),
  true,
  'a target warehouse receives the quantity at the source rate'
);

reset role;
update public.companies
   set enable_stock_delivered_but_not_billed = true,
       stock_delivered_but_not_billed_id = coalesce(
         stock_delivered_but_not_billed_id,
         '20000000-0000-0000-0000-0000000094ca'
       )
 where id = current_setting('test.company')::uuid;
select set_config('test.sdbnb', (
  select c.stock_delivered_but_not_billed_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009401","role":"authenticated"}', true);

select set_config('test.unbilled', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000094c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000094d1',
      'qty', 1,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.unbilled_submitted', public.submit_doc('Delivery Note', current_setting('test.unbilled')::uuid)::text, true);

select is(
  (
    select (select coalesce(sum(g.debit - g.credit), 0) = 5
              from public.gl_entry g
             where g.voucher_id = current_setting('test.unbilled')::uuid
               and g.account_id = current_setting('test.sdbnb')::uuid
               and not g.is_cancelled)
       and (select coalesce(sum(g.debit - g.credit), 0) = 0
              from public.gl_entry g
             where g.voucher_id = current_setting('test.unbilled')::uuid
               and g.account_id = current_setting('test.cogs')::uuid
               and not g.is_cancelled)
  ),
  true,
  'delivered but not billed uses that account instead of cost of goods sold'
);

select throws_ok(
  $$select public.submit_doc('Delivery Note', (
      public.save_doc('Delivery Note', jsonb_build_object(
        'org_id', current_setting('test.org')::uuid,
        'company_id', current_setting('test.company')::uuid,
        'customer_id', '20000000-0000-0000-0000-0000000094c1',
        'selling_price_list_id', current_setting('test.price_list')::uuid,
        'posting_date', current_date::text,
        'set_warehouse_id', current_setting('test.warehouse')::uuid,
        'items', jsonb_build_array(jsonb_build_object(
          'item_id', '20000000-0000-0000-0000-0000000094d4',
          'qty', 1,
          'rate', 10
        ))
      )) ->> 'id'
    )::uuid)$$,
  'P0001',
  'sabb_voucher: Delivery Note does not carry serials yet',
  'a serialized item cannot be delivered without a serial bundle'
);

select * from finish();
rollback;
