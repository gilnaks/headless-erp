begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009701', 'sell97@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000009702', 'sell97-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009701","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Sales Analytics Co", "slug": "sell-an-97", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Sales Analytics Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009701';
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.customers', (
  select g.id::text from public.customer_group g
   where g.org_id = current_setting('test.org')::uuid and g.customer_group_name = 'Commercial'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.price_list', (
  select p.id::text from public.price_list p
   where p.org_id = current_setting('test.org')::uuid and p.price_list_name = 'Standard Selling'
), true);
select set_config('test.field', (
  (array['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'])[extract(month from current_date)::int]
  || '_' || extract(year from current_date)::int::text
), true);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item) values
  ('20000000-0000-0000-0000-0000000097d1', current_setting('test.org')::uuid, 'SA-97-SVC', 'SA-97-SVC', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false);
insert into public.customer (id, org_id, name, customer_name, customer_group_id) values
  ('20000000-0000-0000-0000-0000000097c1', current_setting('test.org')::uuid, 'Acme', 'Acme', current_setting('test.customers')::uuid);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009701","role":"authenticated"}', true);

select set_config('test.order', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000097c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000097d1',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.order_submitted', public.submit_doc('Sales Order', current_setting('test.order')::uuid)::text, true);

select is(
  (
    select (r ->> 'total')::numeric = 20
       and (r ->> current_setting('test.field'))::numeric = 20
       and r ->> 'entity_name' = 'Acme'
      from jsonb_array_elements(
        public.report_sales_analytics(jsonb_build_object(
          'company', current_setting('test.company'),
          'from_date', current_date::text,
          'to_date', current_date::text,
          'tree_type', 'Customer',
          'doc_type', 'Sales Order',
          'value_quantity', 'Value',
          'range', 'Monthly'
        )) -> 'rows'
      ) r
     where r ->> 'entity' = 'Acme'
  ),
  true,
  'a submitted order shows this month and the total for the customer'
);

select is(
  (
    select count(*) = 2
       and bool_and((r ->> 'total')::numeric = 20)
       and bool_or(r ->> 'entity' = 'All Customer Groups' and (r ->> 'indent')::int = 0)
       and bool_or(r ->> 'entity' = 'Commercial' and (r ->> 'indent')::int = 1)
      from jsonb_array_elements(
        public.report_sales_analytics(jsonb_build_object(
          'company', current_setting('test.company'),
          'from_date', current_date::text,
          'to_date', current_date::text,
          'tree_type', 'Customer Group',
          'doc_type', 'Sales Order',
          'value_quantity', 'Value',
          'range', 'Monthly'
        )) -> 'rows'
      ) r
  ),
  true,
  'the customer group and All Customer Groups carry the same amount'
);

select is(
  (
    select (r ->> 'total')::numeric = 2
      from jsonb_array_elements(
        public.report_sales_analytics(jsonb_build_object(
          'company', current_setting('test.company'),
          'from_date', current_date::text,
          'to_date', current_date::text,
          'tree_type', 'Customer',
          'doc_type', 'Sales Order',
          'value_quantity', 'Quantity',
          'range', 'Monthly'
        )) -> 'rows'
      ) r
     where r ->> 'entity' = 'Acme'
  ),
  true,
  'quantity is the stock qty'
);

select throws_ok(
  $$select public.report_sales_analytics(jsonb_build_object(
    'company', current_setting('test.company'),
    'from_date', current_date::text,
    'to_date', current_date::text,
    'tree_type', 'Customer',
    'doc_type', 'Payment Entry',
    'value_quantity', 'Quantity',
    'range', 'Monthly'
  ))$$,
  'P0001',
  'slan_payment_qty: Only Value available for Payment Entry',
  'payment entry quantity is rejected'
);

select throws_ok(
  $$select public.report_sales_analytics(jsonb_build_object(
    'company', current_setting('test.company'),
    'from_date', current_date::text,
    'to_date', current_date::text,
    'tree_type', 'Customer',
    'doc_type', 'Sales Invoice',
    'value_quantity', 'Value',
    'range', 'Monthly'
  ))$$,
  'P0001',
  'slan_doc: Sales Invoice is not built yet',
  'sales invoice is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009702","role":"authenticated"}', true);
select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Sales Analytics Other", "slug": "sell-an-97-b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Sales Analytics Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select throws_ok(
  $$select public.report_sales_analytics(jsonb_build_object(
    'company', current_setting('test.company'),
    'from_date', current_date::text,
    'to_date', current_date::text,
    'tree_type', 'Customer',
    'doc_type', 'Sales Order',
    'value_quantity', 'Value',
    'range', 'Monthly'
  ))$$,
  'P0001',
  'slan_company: Company is mandatory',
  'another organization cannot read the company'
);

select * from finish();
rollback;
