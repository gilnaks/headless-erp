begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000003401', 'payment34@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000003401","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Payment Co", "slug": "payment-34", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Payment Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.company',
  (select id::text from public.companies where org_id = current_setting('test.org')::uuid limit 1),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager', 'Sales Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000003401';

select set_config(
  'test.pe',
  (public.save_doc('Payment Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'payment_type', 'Internal Transfer',
    'paid_from_account_id', (select default_cash_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_to_account_id', (select default_bank_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_amount', 100,
    'received_amount', 100,
    'reference_no', 'TR-1',
    'reference_date', '2026-10-16'
  )) ->> 'id'),
  true
);
select set_config('test.submitted', public.submit_doc('Payment Entry', current_setting('test.pe')::uuid)::text, true);

select is(
  (select count(*)::int from public.gl_entry where voucher_id = current_setting('test.pe')::uuid and not is_cancelled),
  2,
  'an internal transfer posts two open general ledger rows'
);
select is(
  (select sum(debit) = sum(credit) from public.gl_entry where voucher_id = current_setting('test.pe')::uuid and not is_cancelled),
  true,
  'posted debits equal credits'
);
select ok(
  (select name like 'ACC-PAY-2026-%' and docstatus = 1 from public.payment_entry where id = current_setting('test.pe')::uuid),
  'submit names the payment ACC-PAY-.YYYY.- and marks it submitted'
);

select set_config(
  'test.bad',
  (public.save_doc('Payment Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'payment_type', 'Internal Transfer',
    'paid_from_account_id', (select default_cash_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_to_account_id', (select default_bank_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_amount', 100,
    'received_amount', 90,
    'reference_no', 'TR-2',
    'reference_date', '2026-10-16'
  )) ->> 'id'),
  true
);
select throws_like(
  $$select public.submit_doc('Payment Entry', current_setting('test.bad')::uuid)$$,
  '%Difference Amount must be zero%',
  'a payment whose difference is not zero is rejected'
);

select set_config('test.cancelled', public.cancel_doc('Payment Entry', current_setting('test.pe')::uuid)::text, true);
select is(
  (select count(*)::int from public.gl_entry where voucher_id = current_setting('test.pe')::uuid),
  4,
  'cancel keeps the original rows and inserts the mirrored rows'
);
select is(
  (select bool_and(is_cancelled) from public.gl_entry where voucher_id = current_setting('test.pe')::uuid),
  true,
  'cancel flags every general ledger row, including the reversal'
);

select set_config(
  'test.customer',
  (public.save_doc('Customer', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'customer_name', 'Acme'
  )) ->> 'id'),
  true
);
select set_config(
  'test.je',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (select default_receivable_account_id from public.companies where id = current_setting('test.company')::uuid),
        'party_type', 'Customer',
        'party_id', current_setting('test.customer')::uuid,
        'debit', 100
      ),
      jsonb_build_object(
        'account_id', (select default_income_account_id from public.companies where id = current_setting('test.company')::uuid),
        'credit', 100
      )
    )
  )) ->> 'id'),
  true
);
select set_config('test.je_submitted', public.submit_doc('Journal Entry', current_setting('test.je')::uuid)::text, true);

select is(
  jsonb_array_length(public.get_outstanding_reference_documents(
    current_setting('test.company')::uuid,
    'Customer',
    current_setting('test.customer')::uuid,
    (select default_receivable_account_id from public.companies where id = current_setting('test.company')::uuid),
    100
  )),
  1,
  'outstanding references include the posted journal'
);

select set_config(
  'test.receive',
  (public.save_doc('Payment Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'payment_type', 'Receive',
    'party_type', 'Customer',
    'party_id', current_setting('test.customer')::uuid,
    'paid_from_account_id', (select default_receivable_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_to_account_id', (select default_cash_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_amount', 100,
    'received_amount', 100,
    'references', jsonb_build_array(jsonb_build_object(
      'reference_doctype', 'Journal Entry',
      'reference_id', current_setting('test.je')::uuid,
      'allocated_amount', 100,
      'account_id', (select default_receivable_account_id from public.companies where id = current_setting('test.company')::uuid)
    ))
  )) ->> 'id'),
  true
);
select set_config('test.receive_submitted', public.submit_doc('Payment Entry', current_setting('test.receive')::uuid)::text, true);

select is(
  (select coalesce(sum(amount), 0) = 0 from public.payment_ledger_entry
    where against_voucher_id = current_setting('test.je')::uuid and not delinked),
  true,
  'allocating the payment clears the journal outstanding'
);

select * from finish();
rollback;
