begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009901', 'salesregister99@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000009902', 'salesregister99b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009901","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Sales Register Co", "slug": "sales-register-99", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Sales Register Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Accounts User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009901';
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
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item) values
  ('20000000-0000-0000-0000-000000009901', current_setting('test.org')::uuid, 'SI-99-SVC', 'SI-99-SVC', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-000000009902', current_setting('test.org')::uuid, 'Acme', 'Acme');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009901","role":"authenticated"}', true);

select set_config('test.invoice', (
  public.save_doc('Sales Invoice', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-000000009902',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'due_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-000000009901',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.submitted', public.submit_doc('Sales Invoice', current_setting('test.invoice')::uuid)::text, true);
select set_config('test.draft', (
  public.save_doc('Sales Invoice', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-000000009902',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'due_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-000000009901',
      'qty', 1,
      'rate', 5
    ))
  )) ->> 'id'
), true);

select is(
  (
    select count(*) filter (where r ->> 'row_type' = 'invoice') = 1
       and bool_or(
         r ->> 'row_type' = 'invoice'
         and r ->> 'customer' = 'Acme'
         and r ->> 'entity' like 'ACC-SINV-%'
         and (r ->> 'grand_total')::numeric = 20
         and (r ->> 'net_total')::numeric = 20
         and (r ->> 'tax_total')::numeric = 0
         and (r ->> 'rounded_total')::numeric = 20
         and (r ->> 'indent')::int = 0
       )
       and bool_or(
         r ->> 'row_type' = 'entry'
         and r ->> 'entity' = 'SI-99-SVC'
         and (r ->> 'amount')::numeric = 20
         and (r ->> 'indent')::int = 1
       )
       and not bool_or(coalesce(r ->> 'entity', '') like 'DRAFT-%')
      from jsonb_array_elements(
        public.report_sales_register(jsonb_build_object(
          'company', current_setting('test.company'),
          'from_date', current_date::text,
          'to_date', current_date::text
        )) -> 'rows'
      ) r
  ),
  true,
  'a submitted invoice and its item row appear, and a draft does not'
);

select throws_ok(
  $$select public.report_sales_register(jsonb_build_object(
    'company', current_setting('test.company'),
    'from_date', (current_date + 1)::text,
    'to_date', current_date::text
  ))$$,
  'P0001',
  'sreg_dates: From Date cannot be after To Date',
  'a from date after the to date is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009902","role":"authenticated"}', true);
select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Sales Register Other", "slug": "sales-register-99b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Sales Register Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select throws_ok(
  $$select public.report_sales_register(jsonb_build_object(
    'company', current_setting('test.company'),
    'from_date', current_date::text,
    'to_date', current_date::text
  ))$$,
  'P0001',
  'sreg_company: Company is mandatory',
  'another organization cannot read the company'
);

select * from finish();
rollback;
