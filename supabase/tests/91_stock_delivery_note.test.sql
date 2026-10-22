begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009101', 'deliverynote91@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009101","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Delivery Note Co", "slug": "delivery-note-91", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Delivery Note Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009101';
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
  ('20000000-0000-0000-0000-0000000091d1', current_setting('test.org')::uuid, 'DN-91-STK', 'DN-91-STK', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item) values
  ('20000000-0000-0000-0000-0000000091d2', current_setting('test.org')::uuid, 'DN-91-SVC', 'DN-91-SVC', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false),
  ('20000000-0000-0000-0000-0000000091d3', current_setting('test.org')::uuid, 'DN-91-KIT', 'DN-91-KIT', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-0000000091c1', current_setting('test.org')::uuid, 'Acme', 'Acme'),
  ('20000000-0000-0000-0000-0000000091c2', current_setting('test.org')::uuid, 'Tight', 'Tight');
insert into public.customer_credit_limit (id, org_id, parent_id, idx, company_id, credit_limit) values
  ('20000000-0000-0000-0000-0000000091e2', current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000091c2', 1, current_setting('test.company')::uuid, 10);
insert into public.product_bundle (id, org_id, new_item_id) values
  ('20000000-0000-0000-0000-0000000091e1', current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000091d3');
insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000091e1', 1, '20000000-0000-0000-0000-0000000091d1', 3);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009101","role":"authenticated"}', true);
select set_config('test.bundle_submitted', public.submit_doc('Product Bundle', '20000000-0000-0000-0000-0000000091e1')::text, true);
set constraints all immediate;

select set_config('test.order', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000091c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000091d1',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.order_submitted', public.submit_doc('Sales Order', current_setting('test.order')::uuid)::text, true);
select set_config('test.so_item', (
  select i.id::text from public.sales_order_item i
   where i.parent_id = current_setting('test.order')::uuid
), true);

select set_config('test.note', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000091c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000091d1',
      'qty', 2,
      'rate', 10,
      'against_sales_order_id', current_setting('test.order')::uuid,
      'so_detail_id', current_setting('test.so_item')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.submitted', public.submit_doc('Delivery Note', current_setting('test.note')::uuid)::text, true);

select is(
  (
    select s.status = 'To Bill'
       and s.docstatus = 1
       and s.name like 'MAT-DN-%'
       and s.name not like 'MAT-DN-RET-%'
       and s.grand_total = 20
       and s.net_total = 20
       and s.total = 20
       and s.base_grand_total = 20
       and s.customer_name = 'Acme'
       and s.per_billed = 0
       and s.per_returned = 0
       and s.per_installed = 0
       and (
         select i.amount = 20 and i.rate = 10 and i.stock_qty = 2
            and i.warehouse_id = current_setting('test.warehouse')::uuid
            and i.expense_account_id is not null
            and i.against_sales_order_id = current_setting('test.order')::uuid
           from public.delivery_note_item i
          where i.parent_id = s.id
       )
       and (
         select o.delivered_qty = 2
            and o.returned_qty = 0
            and h.per_delivered = 100
            and h.delivery_status = 'Fully Delivered'
            and h.billing_status = 'Not Billed'
            and h.status = 'To Bill'
           from public.sales_order_item o
           join public.sales_order h on h.id = o.parent_id
          where o.id = current_setting('test.so_item')::uuid
       )
       and not exists (
         select 1 from public.stock_ledger_entry e where e.voucher_id = s.id
       )
       and not exists (
         select 1 from public.gl_entry g where g.voucher_id = s.id
       )
      from public.delivery_note s
     where s.id = current_setting('test.note')::uuid
  ),
  true,
  'a submitted delivery note is to bill, delivers the order, and posts no stock or general ledger'
);

select throws_ok(
  $$select public.save_doc('Delivery Note', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000091c1',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'posting_date', current_date::text,
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000091d1',
        'qty', 1,
        'rate', 10
      ))
    ))$$,
  'P0001',
  'dn_warehouse: Source warehouse required for stock item DN-91-STK',
  'a stock item needs a source warehouse'
);

select throws_ok(
  $$select public.save_doc('Delivery Note', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000091c1',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'posting_date', '2020-01-01',
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000091d2',
        'qty', 1,
        'rate', 10
      ))
    ))$$,
  'P0001',
  'fiscal_year: Date 2020-01-01 is not in any active Fiscal Year',
  'a posting date outside the fiscal year is rejected'
);

select set_config('test.hold', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000091c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000091d2',
      'qty', 1,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.hold_submitted', public.submit_doc('Sales Order', current_setting('test.hold')::uuid)::text, true);
do $$ begin
  perform public.update_sales_order_status(current_setting('test.hold')::uuid, 'On Hold');
end $$;

select throws_ok(
  $$select public.save_doc('Delivery Note', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000091c1',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'posting_date', current_date::text,
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000091d2',
        'qty', 1,
        'rate', 10,
        'against_sales_order_id', current_setting('test.hold')::uuid
      ))
    ))$$,
  'P0001',
  (
    select format('dn_so: Sales Order %s is on hold', o.name)
      from public.sales_order o
     where o.id = current_setting('test.hold')::uuid
  ),
  'an on hold sales order is rejected'
);

select set_config('test.tight', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000091c2',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000091d2',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select throws_ok(
  $$select public.submit_doc('Delivery Note', current_setting('test.tight')::uuid)$$,
  'P0001',
  'dn_credit_limit: Credit limit has been crossed for customer Tight (20/10)',
  'submit over the customer credit limit is rejected'
);

select set_config('test.bundle_note', (
  public.save_doc('Delivery Note', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000091c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000091d3',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select is(
  (
    select p.qty = 6
       and p.warehouse_id = current_setting('test.warehouse')::uuid
       and p.parent_doctype = 'Delivery Note'
      from public.packed_item p
     where p.parent_id = current_setting('test.bundle_note')::uuid
  ),
  true,
  'a product bundle writes packed qty as component qty times stock qty'
);

select set_config('test.quotation', (
  public.save_doc('Quotation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000091c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000091d3',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select is(
  (
    select p.qty = 6 and p.parent_doctype = 'Quotation'
      from public.packed_item p
     where p.parent_id = current_setting('test.quotation')::uuid
  ),
  true,
  'a quotation stores packed rows without showing them'
);

select set_config('test.bundle_order', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000091c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000091d3',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select is(
  (
    select p.qty = 6
       and p.warehouse_id = current_setting('test.warehouse')::uuid
       and p.parent_doctype = 'Sales Order'
      from public.packed_item p
     where p.parent_id = current_setting('test.bundle_order')::uuid
  ),
  true,
  'a sales order stores packed rows without showing them'
);

select lives_ok(
  $$select public.update_delivery_note_status(current_setting('test.note')::uuid, 'Closed')$$,
  'close the submitted note'
);

select throws_ok(
  $$select public.cancel_doc('Delivery Note', current_setting('test.note')::uuid)$$,
  'P0001',
  'dn_closed: Closed delivery note cannot be cancelled. Re-open to cancel.',
  'a closed note cannot be cancelled'
);

select lives_ok(
  $$select public.update_delivery_note_status(current_setting('test.note')::uuid, 'Draft')$$,
  're-open the closed note'
);

select is(
  (
    select s.status = 'To Bill' and s.docstatus = 1
      from public.delivery_note s
     where s.id = current_setting('test.note')::uuid
  ),
  true,
  're-open returns the note to To Bill'
);

select * from finish();
rollback;
