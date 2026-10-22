begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009201', 'mapdoc92@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009201","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Map Doc Co", "slug": "map-doc-92", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Map Doc Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User', 'Stock Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009201';
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
  ('20000000-0000-0000-0000-0000000092d1', current_setting('test.org')::uuid, 'MAP-92-STK', 'MAP-92-STK', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-0000000092c1', current_setting('test.org')::uuid, 'Acme', 'Acme');
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000092c9', current_setting('test.org')::uuid, 'Temporary Opening',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Temporary'
    from public.account a
    join public.companies c on c.default_inventory_account_id = a.id
   where c.id = current_setting('test.company')::uuid;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009201","role":"authenticated"}', true);

select set_config('test.quotation', (
  public.save_doc('Quotation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000092c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'valid_till', (current_date + 30)::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000092d1',
      'qty', 2,
      'rate', 10,
      'warehouse_id', current_setting('test.warehouse')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.quotation_submitted', public.submit_doc('Quotation', current_setting('test.quotation')::uuid)::text, true);
select set_config('test.order', (
  public.map_doc('Quotation', current_setting('test.quotation')::uuid, 'Sales Order') ->> 'id'
), true);

select is(
  (
    select s.docstatus = 0
       and s.name like 'DRAFT-%'
       and s.status = 'Draft'
       and (select count(*) from public.sales_order_item i where i.parent_id = s.id) = 1
       and (
         select i.qty = 2
            and i.rate = 10
            and i.quotation_item_id is not null
            and i.prevdoc_id = current_setting('test.quotation')::uuid
            and i.warehouse_id = current_setting('test.warehouse')::uuid
           from public.sales_order_item i
          where i.parent_id = s.id
       )
       and (
         select qi.ordered_qty = 0
           from public.quotation_item qi
          where qi.parent_id = current_setting('test.quotation')::uuid
       )
      from public.sales_order s
     where s.id = current_setting('test.order')::uuid
  ),
  true,
  'a quotation maps to a draft sales order at the quotation rate'
);

select set_config('test.expired', (
  public.save_doc('Quotation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000092c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', (current_date - 1)::text,
    'valid_till', (current_date - 1)::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000092d1',
      'qty', 1,
      'rate', 10,
      'warehouse_id', current_setting('test.warehouse')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.expired_submitted', public.submit_doc('Quotation', current_setting('test.expired')::uuid)::text, true);
select throws_ok(
  $$select public.map_doc('Quotation', current_setting('test.expired')::uuid, 'Sales Order')$$,
  'P0001',
  'map_expired: Validity period of this quotation has ended.',
  'an expired quotation cannot make a sales order'
);

select set_config('test.order_submitted', public.submit_doc('Sales Order', current_setting('test.order')::uuid)::text, true);
select set_config('test.note', (
  public.map_doc('Sales Order', current_setting('test.order')::uuid, 'Delivery Note') ->> 'id'
), true);

select is(
  (
    select n.docstatus = 0
       and n.name like 'DRAFT-%'
       and (
         select i.qty = 2
            and i.rate = 10
            and i.against_sales_order_id = current_setting('test.order')::uuid
            and i.so_detail_id is not null
            and i.warehouse_id = current_setting('test.warehouse')::uuid
           from public.delivery_note_item i
          where i.parent_id = n.id
       )
       and (
         select oi.delivered_qty = 0
           from public.sales_order_item oi
          where oi.parent_id = current_setting('test.order')::uuid
       )
      from public.delivery_note n
     where n.id = current_setting('test.note')::uuid
  ),
  true,
  'a sales order maps to a draft delivery note and does not mark the order delivered'
);

select set_config('test.held', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000092c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'set_warehouse_id', current_setting('test.warehouse')::uuid,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000092d1',
      'qty', 1,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.held_submitted', public.submit_doc('Sales Order', current_setting('test.held')::uuid)::text, true);
do $$
begin
  perform public.update_sales_order_status(current_setting('test.held')::uuid, 'On Hold');
end $$;
select throws_ok(
  $$select public.map_doc('Sales Order', current_setting('test.held')::uuid, 'Delivery Note')$$,
  'P0001',
  (
    select format('map_status: Sales Order %s is on hold', o.name)
      from public.sales_order o
     where o.id = current_setting('test.held')::uuid
  ),
  'an order on hold cannot make a delivery note'
);

select set_config('test.opening', (
  public.save_doc('Stock Reconciliation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'purpose', 'Opening Stock',
    'posting_date', (current_date - 1)::text,
    'posting_time', '08:00:00',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000092d1',
      'warehouse_id', current_setting('test.warehouse')::uuid,
      'qty', 10, 'valuation_rate', 5
    ))
  )) ->> 'id'
), true);
select set_config('test.opening_submitted', public.submit_doc('Stock Reconciliation', current_setting('test.opening')::uuid)::text, true);
select set_config('test.note_submitted', public.submit_doc('Delivery Note', current_setting('test.note')::uuid)::text, true);
select set_config('test.return', (
  public.make_return_doc('Delivery Note', current_setting('test.note')::uuid) ->> 'id'
), true);

select is(
  (
    select n.docstatus = 0
       and n.is_return
       and n.return_against = current_setting('test.note')::uuid
       and (
         select i.qty = -2
            and i.rate = 10
            and i.dn_detail_id = (
              select s.id from public.delivery_note_item s
               where s.parent_id = current_setting('test.note')::uuid
            )
           from public.delivery_note_item i
          where i.parent_id = n.id
       )
      from public.delivery_note n
     where n.id = current_setting('test.return')::uuid
  ),
  true,
  'a delivery note maps to a draft return for the quantity not yet returned'
);

select set_config('test.return_submitted', public.submit_doc('Delivery Note', current_setting('test.return')::uuid)::text, true);
select is(
  (
    select n.docstatus = 1
       and n.name like 'MAT-DN-RET-%'
       and n.status = 'Return'
       and (
         select e.actual_qty = 2 and not e.is_cancelled
           from public.stock_ledger_entry e
          where e.voucher_id = n.id
       )
       and exists (
         select 1 from public.gl_entry g
          where g.voucher_id = n.id and not g.is_cancelled and g.party_id is null
       )
      from public.delivery_note n
     where n.id = current_setting('test.return')::uuid
  ),
  true,
  'submitting the return names it and posts the stock back'
);

select throws_ok(
  $$select public.make_return_doc('Delivery Note', current_setting('test.note')::uuid)$$,
  'P0001',
  'map_empty: No items with quantity pending',
  'a second return finds nothing left'
);

select * from finish();
rollback;
