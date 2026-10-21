begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009001', 'salesorder90@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009001","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Sales Order Co", "slug": "sales-order-90", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Sales Order Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009001';
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
  ('20000000-0000-0000-0000-0000000090d1', current_setting('test.org')::uuid, 'SO-90-STK', 'SO-90-STK', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item) values
  ('20000000-0000-0000-0000-0000000090d2', current_setting('test.org')::uuid, 'SO-90-SVC', 'SO-90-SVC', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-0000000090c1', current_setting('test.org')::uuid, 'Acme', 'Acme'),
  ('20000000-0000-0000-0000-0000000090c2', current_setting('test.org')::uuid, 'Tight', 'Tight');
insert into public.customer_credit_limit (id, org_id, parent_id, idx, company_id, credit_limit) values
  ('20000000-0000-0000-0000-0000000090e1', current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000090c2', 1, current_setting('test.company')::uuid, 10);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009001","role":"authenticated"}', true);

select set_config('test.order', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000090c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000090d1',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.submitted', public.submit_doc('Sales Order', current_setting('test.order')::uuid)::text, true);

select is(
  (
    select s.status = 'To Deliver and Bill'
       and s.docstatus = 1
       and s.name like 'SAL-ORD-%'
       and s.grand_total = 20
       and s.net_total = 20
       and s.total = 20
       and s.base_grand_total = 20
       and s.conversion_rate = 1
       and s.customer_name = 'Acme'
       and s.delivery_status = 'Not Delivered'
       and s.billing_status = 'Not Billed'
       and s.per_delivered = 0
       and s.per_billed = 0
       and s.advance_payment_status = 'Not Requested'
       and not s.skip_delivery_note
       and (
         select i.amount = 20 and i.rate = 10 and i.stock_qty = 2
            and i.warehouse_id = current_setting('test.warehouse')::uuid
            and i.delivery_date = current_date
            and i.is_stock_item
           from public.sales_order_item i
          where i.parent_id = s.id
       )
      from public.sales_order s
     where s.id = current_setting('test.order')::uuid
  ),
  true,
  'a submitted sales order is to deliver and bill and the grand total is qty times rate'
);

select throws_ok(
  $$select public.save_doc('Sales Order', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000090c1',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'transaction_date', current_date::text,
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000090d2',
        'qty', 1,
        'rate', 10
      ))
    ))$$,
  'P0001',
  'so_delivery_date: Please enter Delivery Date',
  'a service item still needs a delivery date'
);

select set_config('test.po_order', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000090c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'po_no', 'PO-90',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000090d2',
      'qty', 1,
      'rate', 10
    ))
  )) ->> 'id'
), true);

select throws_ok(
  $$select public.save_doc('Sales Order', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000090c1',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'transaction_date', current_date::text,
      'delivery_date', current_date::text,
      'po_no', 'PO-90',
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000090d2',
        'qty', 1,
        'rate', 10
      ))
    ))$$,
  'P0001',
  (
    select format(
      'so_po: Sales Order %s already exists against Customer''s Purchase Order PO-90. To allow multiple Sales Orders, Enable Allow multiple Sales Orders against a Customer''s Purchase Order in Selling Settings',
      o.name
    )
      from public.sales_order o
     where o.id = current_setting('test.po_order')::uuid
  ),
  'the same customer purchase order is rejected'
);

select throws_ok(
  $$select public.save_doc('Sales Order', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000090c1',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'transaction_date', current_date::text,
      'delivery_date', current_date::text,
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000090d1',
        'qty', 1,
        'rate', 10
      ))
    ))$$,
  'P0001',
  'so_warehouse: Source warehouse required for stock item SO-90-STK',
  'a stock item needs a source warehouse'
);

select set_config('test.tight', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000090c2',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000090d2',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);

select throws_ok(
  $$select public.submit_doc('Sales Order', current_setting('test.tight')::uuid)$$,
  'P0001',
  'so_credit_limit: Credit limit has been crossed for customer Tight (20/10)',
  'submit over the customer credit limit is rejected'
);

select lives_ok(
  $$select public.update_sales_order_status(current_setting('test.order')::uuid, 'Closed')$$,
  'close the submitted order'
);

select throws_ok(
  $$select public.cancel_doc('Sales Order', current_setting('test.order')::uuid)$$,
  'P0001',
  'so_closed: Closed order cannot be cancelled. Unclose to cancel.',
  'a closed order cannot be cancelled'
);

select lives_ok(
  $$select public.update_sales_order_status(current_setting('test.order')::uuid, 'Draft')$$,
  're-open the closed order'
);

select is(
  (
    select s.status = 'To Deliver and Bill' and s.docstatus = 1
      from public.sales_order s
     where s.id = current_setting('test.order')::uuid
  ),
  true,
  're-open returns the order to To Deliver and Bill'
);

select lives_ok(
  $$select public.update_sales_order_status(current_setting('test.order')::uuid, 'On Hold')$$,
  'hold the order'
);

select is(
  (
    select s.status = 'On Hold' and s.docstatus = 1
      from public.sales_order s
     where s.id = current_setting('test.order')::uuid
  ),
  true,
  'hold sets the order On Hold'
);

select * from finish();
rollback;
