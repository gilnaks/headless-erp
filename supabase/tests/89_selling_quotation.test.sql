begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008901', 'quotation89@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008901","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Quotation Co", "slug": "quotation-89", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Quotation Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Sales User']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000008901';
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
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  ('20000000-0000-0000-0000-0000000089d1', current_setting('test.org')::uuid, 'QTN-89', 'QTN-89', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
insert into public.customer (id, org_id, name, customer_name) values
  ('20000000-0000-0000-0000-0000000089c1', current_setting('test.org')::uuid, 'Acme', 'Acme');
insert into public.customer (id, org_id, name, customer_name, disabled) values
  ('20000000-0000-0000-0000-0000000089c2', current_setting('test.org')::uuid, 'Gone', 'Gone', true);
insert into public.quotation_lost_reason (id, org_id, order_lost_reason) values
  ('20000000-0000-0000-0000-0000000089a1', current_setting('test.org')::uuid, 'Price');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008901","role":"authenticated"}', true);

select set_config('test.quote', (
  public.save_doc('Quotation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000089c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', (current_date - 1)::text,
    'valid_till', (current_date + 30)::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000089d1',
      'qty', 2,
      'rate', 10
    ))
  )) ->> 'id'
), true);
select set_config('test.submitted', public.submit_doc('Quotation', current_setting('test.quote')::uuid)::text, true);

select is(
  (
    select q.status = 'Open'
       and q.docstatus = 1
       and q.name like 'SAL-QTN-%'
       and q.grand_total = 20
       and q.net_total = 20
       and q.total = 20
       and q.base_grand_total = 20
       and q.conversion_rate = 1
       and q.customer_name = 'Acme'
       and q.is_latest_revision
       and (
         select i.amount = 20 and i.rate = 10 and i.stock_qty = 2 and i.ordered_qty = 0
           from public.quotation_item i
          where i.parent_id = q.id
       )
      from public.quotation q
     where q.id = current_setting('test.quote')::uuid
  ),
  true,
  'a submitted quotation is open and the grand total is qty times rate'
);

select throws_ok(
  $$select public.save_doc('Quotation', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000089c1',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'transaction_date', current_date::text,
      'valid_till', (current_date - 1)::text,
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000089d1',
        'qty', 1,
        'rate', 10
      ))
    ))$$,
  'P0001',
  'quotation_date: Valid till date cannot be before transaction date',
  'valid till before the transaction date is rejected'
);

select throws_ok(
  $$select public.save_doc('Quotation', jsonb_build_object(
      'org_id', current_setting('test.org')::uuid,
      'company_id', current_setting('test.company')::uuid,
      'customer_id', '20000000-0000-0000-0000-0000000089c2',
      'selling_price_list_id', current_setting('test.price_list')::uuid,
      'transaction_date', current_date::text,
      'items', jsonb_build_array(jsonb_build_object(
        'item_id', '20000000-0000-0000-0000-0000000089d1',
        'qty', 1,
        'rate', 10
      ))
    ))$$,
  'P0001',
  'quotation_customer: Customer Gone is disabled',
  'a disabled customer is rejected'
);

select set_config('test.revision', (
  public.revise_quotation(current_setting('test.quote')::uuid) ->> 'id'
), true);

select is(
  (
    select rev.name = src.name || '-R1'
       and rev.docstatus = 0
       and rev.status = 'Draft'
       and rev.valid_till is null
       and rev.revision_of = src.id
       and rev.customer_id = src.customer_id
       and rev.company_id = src.company_id
      from public.quotation rev
      join public.quotation src on src.id = current_setting('test.quote')::uuid
     where rev.id = current_setting('test.revision')::uuid
  ),
  true,
  'a revision is named from the root and clears valid till'
);

select set_config(
  'test.revision_submitted',
  public.submit_doc('Quotation', current_setting('test.revision')::uuid)::text,
  true
);

select is(
  (
    select src.is_active = false
       and src.is_latest_revision = false
       and src.status = 'Open'
       and rev.status = 'Open'
       and rev.docstatus = 1
       and rev.is_active
       and rev.is_latest_revision
      from public.quotation rev
      join public.quotation src on src.id = current_setting('test.quote')::uuid
     where rev.id = current_setting('test.revision')::uuid
  ),
  true,
  'submitting a revision deactivates the original and becomes the latest'
);

select throws_ok(
  $$select public.set_quotation_lost(
      current_setting('test.revision')::uuid,
      '00000000-0000-0000-0000-0000000089ff'::uuid,
      null
    )$$,
  'P0001',
  'quotation_lost: Invalid lost reason 00000000-0000-0000-0000-0000000089ff, please create a new lost reason',
  'an unknown lost reason is rejected'
);

select set_config('test.lost', public.set_quotation_lost(
  current_setting('test.revision')::uuid,
  '20000000-0000-0000-0000-0000000089a1'::uuid,
  'too high'
)::text, true);

select is(
  (
    select rev.status = 'Lost'
       and rev.is_active
       and rev.order_lost_reason = 'too high'
       and src.status = 'Lost'
       and src.is_active = false
       and (
         select count(*) = 1
           from public.quotation_lost_reason_detail d
          where d.parent_id = rev.id
            and d.quotation_lost_reason_id = '20000000-0000-0000-0000-0000000089a1'
       )
      from public.quotation rev
      join public.quotation src on src.id = current_setting('test.quote')::uuid
     where rev.id = current_setting('test.revision')::uuid
  ),
  true,
  'set as lost stores the reason and marks the other version lost'
);

select set_config('test.past', (
  public.save_doc('Quotation', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'customer_id', '20000000-0000-0000-0000-0000000089c1',
    'selling_price_list_id', current_setting('test.price_list')::uuid,
    'transaction_date', (current_date - 2)::text,
    'valid_till', (current_date - 1)::text,
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000089d1',
      'qty', 1,
      'rate', 5
    ))
  )) ->> 'id'
), true);
select set_config('test.past_submitted', public.submit_doc('Quotation', current_setting('test.past')::uuid)::text, true);

reset role;
select lives_ok(
  'select app.expire_quotations()',
  'the daily expiry job runs'
);
select is(
  (
    select (select q.status = 'Expired' and q.docstatus = 1
              from public.quotation q
             where q.id = current_setting('test.past')::uuid)
       and (select r.status = 'Lost'
              from public.quotation r
             where r.id = current_setting('test.revision')::uuid)
  ),
  true,
  'a past valid till expires and a lost quotation stays lost'
);

select * from finish();
rollback;
