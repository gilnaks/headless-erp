begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009301', 'prevdoc93@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009301","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Prev Doc Co", "slug": "prevdoc-93", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Prev Doc Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User', 'Stock Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009301';
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
select set_config('test.price_list', (
  select p.id::text from public.price_list p
   where p.org_id = current_setting('test.org')::uuid and p.price_list_name = 'Standard Selling'
), true);
select set_config('test.warehouse', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Stores'
), true);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  ('20000000-0000-0000-0000-0000000093d1', current_setting('test.org')::uuid, 'PREV-93-STK', 'PREV-93-STK', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-0000000093c1', current_setting('test.org')::uuid, 'Acme', 'Acme');
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000093c9', current_setting('test.org')::uuid, 'Temporary Opening',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Temporary'
    from public.account a
    join public.companies c on c.default_inventory_account_id = a.id
   where c.id = current_setting('test.company')::uuid;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009301","role":"authenticated"}', true);

select set_config('test.quotation', (
  public.save_doc('Quotation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000093c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'valid_till', (current_date + 30)::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000093d1',
      'qty', 2,
      'rate', 10,
      'warehouse_id', current_setting('test.warehouse')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.quotation_submitted', public.submit_doc('Quotation', current_setting('test.quotation')::uuid)::text, true);
select set_config('test.qi', (
  select i.id::text from public.quotation_item i
   where i.parent_id = current_setting('test.quotation')::uuid
), true);

select set_config('test.partial', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000093c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000093d1',
      'qty', 1,
      'rate', 10,
      'prevdoc_id', current_setting('test.quotation')::uuid,
      'quotation_item_id', current_setting('test.qi')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.partial_submitted', public.submit_doc('Sales Order', current_setting('test.partial')::uuid)::text, true);

select is(
  (
    select q.status = 'Partially Ordered'
       and (
         select i.ordered_qty = 1
           from public.quotation_item i
          where i.id = current_setting('test.qi')::uuid
       )
      from public.quotation q
     where q.id = current_setting('test.quotation')::uuid
  ),
  true,
  'a partial order marks the quotation partially ordered'
);

select set_config('test.partial_cancelled', public.cancel_doc('Sales Order', current_setting('test.partial')::uuid)::text, true);

select is(
  (
    select q.status = 'Open'
       and (
         select i.ordered_qty = 0
           from public.quotation_item i
          where i.id = current_setting('test.qi')::uuid
       )
      from public.quotation q
     where q.id = current_setting('test.quotation')::uuid
  ),
  true,
  'cancelling the order returns the quotation to open'
);

select set_config('test.order', (
  public.map_doc('Quotation', current_setting('test.quotation')::uuid, 'Sales Order') ->> 'id'
), true);
select set_config('test.order_submitted', public.submit_doc('Sales Order', current_setting('test.order')::uuid)::text, true);

select is(
  (
    select q.status = 'Ordered'
       and (
         select i.ordered_qty = i.stock_qty and i.stock_qty = 2
           from public.quotation_item i
          where i.id = current_setting('test.qi')::uuid
       )
      from public.quotation q
     where q.id = current_setting('test.quotation')::uuid
  ),
  true,
  'a full order marks the quotation ordered'
);

select throws_ok(
  $$select public.map_doc('Quotation', current_setting('test.quotation')::uuid, 'Sales Order')$$,
  'P0001',
  'map_empty: No items with quantity pending',
  'a fully ordered quotation has nothing left to map'
);

select throws_ok(
  $$select public.cancel_doc('Quotation', current_setting('test.quotation')::uuid)$$,
  'P0001',
  (
    select format('quotation_ordered: Quotation %s is linked to Sales Order %s', q.name, s.name)
      from public.quotation q
      join public.sales_order s on s.id = current_setting('test.order')::uuid
     where q.id = current_setting('test.quotation')::uuid
  ),
  'a quotation with a submitted sales order cannot be cancelled'
);

select set_config('test.detail', (
  select i.id::text from public.sales_order_item i
   where i.parent_id = current_setting('test.order')::uuid
), true);
select set_config('test.opening', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Opening Stock',
    'posting_date', (current_date - 1)::text,
    'posting_time', '08:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000093d1',
      'warehouse_id', current_setting('test.warehouse')::uuid,
      'qty', 10, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select set_config('test.opening_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.opening')::uuid)::text, true);

select set_config('test.note', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000093c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000093d1',
      'qty', 2,
      'rate', 10,
      'against_sales_order_id', current_setting('test.order')::uuid,
      'so_detail_id', current_setting('test.detail')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.note_submitted', public.submit_doc('Delivery Note', current_setting('test.note')::uuid)::text, true);

select is(
  (
    select s.status = 'To Bill'
       and s.per_delivered = 100
       and s.per_billed = 0
       and s.delivery_status = 'Fully Delivered'
       and s.billing_status = 'Not Billed'
       and (
         select i.delivered_qty = 2 and i.returned_qty = 0
           from public.sales_order_item i
          where i.id = current_setting('test.detail')::uuid
       )
       and (
         select e.actual_qty = -2 and not e.is_cancelled
           from public.stock_ledger_entry e
          where e.voucher_id = current_setting('test.note')::uuid
       )
       and exists (
         select 1 from public.gl_entry g
          where g.voucher_id = current_setting('test.note')::uuid and not g.is_cancelled and g.party_id is null
       )
      from public.sales_order s
     where s.id = current_setting('test.order')::uuid
  ),
  true,
  'a full delivery note bills the order next and posts stock and the general ledger'
);

select throws_ok(
  $$select public.submit_doc('Delivery Note', (
      public.save_doc('Delivery Note', jsonb_build_object(
        'org_id', current_setting('test.org')::uuid,
        'company_id', current_setting('test.company')::uuid,
        'customer_id', '20000000-0000-0000-0000-0000000093c1',
        'selling_price_list_id', current_setting('test.price_list')::uuid,
        'posting_date', current_date::text,
        'set_warehouse_id', current_setting('test.warehouse')::uuid,
        'items', jsonb_build_array(jsonb_build_object(
          'item_id', '20000000-0000-0000-0000-0000000093d1',
          'qty', 1,
          'rate', 10,
          'against_sales_order_id', current_setting('test.order')::uuid,
          'so_detail_id', current_setting('test.detail')::uuid
        ))
      )) ->> 'id'
    )::uuid)$$,
  'P0001',
  'over_delivery: Delivered quantity for item PREV-93-STK is over the allowance',
  'one extra quantity is over the delivery allowance'
);

select set_config('test.return', (
  public.make_return_doc('Delivery Note', current_setting('test.note')::uuid) ->> 'id'
), true);
select set_config('test.return_submitted', public.submit_doc('Delivery Note', current_setting('test.return')::uuid)::text, true);

select is(
  (
    select n.status = 'Return Issued'
       and n.per_returned = 100
       and (
         select i.returned_qty = 2
           from public.delivery_note_item i
          where i.parent_id = n.id
       )
       and (
         select s.status = 'To Deliver and Bill'
            and s.per_delivered = 0
            and s.delivery_status = 'Not Delivered'
            and (
              select oi.delivered_qty = 0 and oi.returned_qty = 2
                from public.sales_order_item oi
               where oi.id = current_setting('test.detail')::uuid
            )
           from public.sales_order s
          where s.id = current_setting('test.order')::uuid
       )
       and (
         select r.status = 'Return' and r.name like 'MAT-DN-RET-%'
           from public.delivery_note r
          where r.id = current_setting('test.return')::uuid
       )
       and (
         select e.actual_qty = 2 and not e.is_cancelled
           from public.stock_ledger_entry e
          where e.voucher_id = current_setting('test.return')::uuid
       )
       and exists (
         select 1 from public.gl_entry g
          where g.voucher_id = current_setting('test.return')::uuid and not g.is_cancelled
       )
      from public.delivery_note n
     where n.id = current_setting('test.note')::uuid
  ),
  true,
  'a full return issues the note and returns the order to deliver and bill'
);

select * from finish();
rollback;
