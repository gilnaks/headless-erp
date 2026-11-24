begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009601', 'sell96@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000009602', 'sell96-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009601","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Selling Dashboard Co", "slug": "sell-dash-96", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Selling Dashboard Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009601';
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.price_list', (
  select p.id::text from public.price_list p
   where p.org_id = current_setting('test.org')::uuid and p.price_list_name = 'Standard Selling'
), true);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item) values
  ('20000000-0000-0000-0000-0000000096d1', current_setting('test.org')::uuid, 'SD-96-SVC', 'SD-96-SVC', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false);
insert into public.customer (id, org_id, name, customer_name, disabled) values
  ('20000000-0000-0000-0000-0000000096c1', current_setting('test.org')::uuid, 'Acme', 'Acme', false),
  ('20000000-0000-0000-0000-0000000096c2', current_setting('test.org')::uuid, 'Dormant', 'Dormant', true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009601","role":"authenticated"}', true);

select is(
  (
    select (c ->> 'annual_sales')::numeric = 0
       and (c ->> 'to_deliver')::int = 0
       and (c ->> 'to_bill')::int = 0
       and (c ->> 'active_customers')::int = 1
      from public.card_selling(jsonb_build_object('company', current_setting('test.company'))) c
  ),
  true,
  'a company with no orders counts the active customer and leaves the order cards at zero'
);

select set_config('test.order', (
  public.save_doc('Sales Order', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000096c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', current_date::text,
    'delivery_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000096d1',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.order_submitted', public.submit_doc('Sales Order', current_setting('test.order')::uuid)::text, true);

select is(
  (
    select (c ->> 'annual_sales')::numeric = 20
       and (c ->> 'to_deliver')::int = 1
       and (c ->> 'to_bill')::int = 1
       and (c ->> 'active_customers')::int = 1
      from public.card_selling(jsonb_build_object('company', current_setting('test.company'))) c
  ),
  true,
  'a submitted order counts as annual sales and as both to deliver and to bill'
);

select is(
  (
    select (c -> 'chart' -> 'labels') = jsonb_build_array('Amount to Bill', 'Billed Amount')
       and (c -> 'chart' -> 'datasets' -> 0 -> 'values' ->> 0)::numeric = 20
       and (c -> 'chart' -> 'datasets' -> 0 -> 'values' ->> 1)::numeric = 0
      from public.chart_selling('sales_order_analysis', jsonb_build_object('company', current_setting('test.company'))) c
  ),
  true,
  'open orders are amount to bill and billed amount stays zero'
);

select is(
  (
    select (public.chart_selling('sales_order_trends', f) ->> 'available') = 'false'
       and (public.chart_selling('top_customers', f) ->> 'available') = 'false'
       and (public.chart_selling('item_wise_annual_sales', f) ->> 'available') = 'false'
      from (select jsonb_build_object('company', current_setting('test.company')) as f) s
  ),
  true,
  'the three report charts are unavailable'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009602","role":"authenticated"}', true);
select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Selling Dashboard Other", "slug": "sell-dash-96-b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Selling Dashboard Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select throws_ok(
  $$select public.card_selling(jsonb_build_object('company', current_setting('test.company')))$$,
  'P0001',
  'dash_company: Company is mandatory',
  'another organization cannot read the company'
);

select * from finish();
rollback;
