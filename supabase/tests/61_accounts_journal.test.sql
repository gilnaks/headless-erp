begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000003301', 'journal33@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000003301","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Journal Co", "slug": "journal-33", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Journal Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.company',
  (select id::text from public.companies where org_id = current_setting('test.org')::uuid limit 1),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000003301';

select set_config(
  'test.je',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-15',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (select id from public.account where company_id = current_setting('test.company')::uuid and account_type = 'Cash' and not is_group order by name limit 1),
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
select set_config('test.submitted', public.submit_doc('Journal Entry', current_setting('test.je')::uuid)::text, true);

select is(
  (select count(*)::int from public.gl_entry where voucher_id = current_setting('test.je')::uuid and not is_cancelled),
  2,
  'a balanced journal posts two open general ledger rows'
);
select is(
  (select sum(debit) = sum(credit) from public.gl_entry where voucher_id = current_setting('test.je')::uuid and not is_cancelled),
  true,
  'posted debits equal credits'
);
select ok(
  (select name like 'ACC-JV-2026-%' and docstatus = 1 from public.journal_entry where id = current_setting('test.je')::uuid),
  'submit names the journal ACC-JV-.YYYY.- and marks it submitted'
);

select set_config(
  'test.bad',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-15',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (select id from public.account where company_id = current_setting('test.company')::uuid and account_type = 'Cash' and not is_group order by name limit 1),
        'debit', 100
      ),
      jsonb_build_object(
        'account_id', (select default_income_account_id from public.companies where id = current_setting('test.company')::uuid),
        'credit', 90
      )
    )
  )) ->> 'id'),
  true
);
select throws_like(
  $$select public.submit_doc('Journal Entry', current_setting('test.bad')::uuid)$$,
  '%Total Debit must be equal to Total Credit%',
  'a journal whose debit and credit differ is rejected'
);

select set_config('test.cancelled', public.cancel_doc('Journal Entry', current_setting('test.je')::uuid)::text, true);
select is(
  (select count(*)::int from public.gl_entry where voucher_id = current_setting('test.je')::uuid),
  4,
  'cancel keeps the original rows and inserts the mirrored rows'
);
select is(
  (select bool_and(is_cancelled) from public.gl_entry where voucher_id = current_setting('test.je')::uuid),
  true,
  'cancel flags every general ledger row, including the reversal'
);
select ok(
  (select docstatus = 2 from public.journal_entry where id = current_setting('test.je')::uuid)
  and exists (
    select 1 from public.gl_entry
     where voucher_id = current_setting('test.je')::uuid and remarks like 'On cancellation of ACC-JV-2026-%'
  ),
  'the voucher is Cancelled and the reversal names it'
);
delete from public.gl_entry where voucher_id = current_setting('test.je')::uuid;
select is(
  (select count(*)::int from public.gl_entry where voucher_id = current_setting('test.je')::uuid),
  4,
  'a member cannot delete general ledger rows'
);
select throws_like(
  $$select public.save_doc('Journal Entry', jsonb_build_object('id', current_setting('test.je')::uuid, 'user_remark', 'changed after submit'))$$,
  '%cancelled_readonly%',
  'a cancelled journal cannot be saved again'
);

select * from finish();
rollback;
