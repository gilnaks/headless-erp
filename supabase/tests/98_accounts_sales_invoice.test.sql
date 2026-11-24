begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009801', 'salesinvoice98@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000009802', 'salesinvoice98b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009801","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Sales Invoice Co", "slug": "sales-invoice-98", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Sales Invoice Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Accounts User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000009801';
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
  ('20000000-0000-0000-0000-000000009801', current_setting('test.org')::uuid, 'SI-98-SVC', 'SI-98-SVC', current_setting('test.group')::uuid, current_setting('test.nos')::uuid, false);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-000000009802', current_setting('test.org')::uuid, 'Acme', 'Acme');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009801","role":"authenticated"}', true);

select set_config('test.invoice', (
  public.save_doc('Sales Invoice', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-000000009802',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'due_date', current_date::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-000000009801',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.submitted', public.submit_doc('Sales Invoice', current_setting('test.invoice')::uuid)::text, true);

select is(
  (
    select s.status = 'Unpaid'
       and s.docstatus = 1
       and s.name like 'ACC-SINV-%'
       and s.grand_total = 20
       and s.base_grand_total = 20
       and s.outstanding_amount = 20
       and s.due_date = current_date
       and s.debit_to_id = c.default_receivable_account_id
       and i.amount = 20
       and i.income_account_id = c.default_income_account_id
       and d.debit = 20
       and d.party_type = 'Customer'
       and d.party_id = s.customer_id
       and d.against_voucher_id = s.id
       and d.due_date = s.due_date
       and not d.is_cancelled
       and cr.credit = 20
       and not cr.is_cancelled
      from public.sales_invoice s
      join public.companies c on c.id = s.company_id
      join public.sales_invoice_item i on i.parent_id = s.id
      join public.gl_entry d on d.voucher_id = s.id and d.account_id = s.debit_to_id
      join public.gl_entry cr on cr.voucher_id = s.id and cr.account_id = i.income_account_id
     where s.id = current_setting('test.invoice')::uuid
  ),
  true,
  'a submitted invoice debits the receivable and credits income'
);

select throws_ok(
  $$select public.save_doc('Sales Invoice', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-000000009802',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'posting_date', current_date::text,
    'due_date', (current_date - 1)::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-000000009801',
      'qty', 1,
      'rate', 5
    ))
  ))$$,
  'P0001',
  'si_due_date: Due Date cannot be before Posting Date',
  'a due date before the posting date is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009802","role":"authenticated"}', true);
select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Sales Invoice Other", "slug": "sales-invoice-98b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Sales Invoice Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select is(
  (select count(*) from public.sales_invoice where id = current_setting('test.invoice')::uuid),
  0::bigint,
  'another organization cannot read the invoice'
);

select * from finish();
rollback;
