begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000006501', 'ledger65@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006501","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Ledger Co", "slug": "ledger-65", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Ledger Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.company',
  (select id::text from public.companies where org_id = current_setting('test.org')::uuid limit 1),
  true
);
select set_config(
  'test.cash',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '1101' and not is_group),
  true
);
select set_config(
  'test.cash_group',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '1100' and is_group),
  true
);
select set_config(
  'test.sales',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '4101' and not is_group),
  true
);
select set_config(
  'test.capital',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '3101' and not is_group),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000006501';

select throws_like(
  $$select public.report_general_ledger('{}'::jsonb)$$,
  '%gl_company%',
  'a missing company is rejected'
);
select throws_like(
  $$select public.report_general_ledger(jsonb_build_object(
    'company', current_setting('test.company')::uuid,
    'from_date', '2026-10-31',
    'to_date', '2026-10-01'
  ))$$,
  '%From Date must be before To Date%',
  'a from-date after the to-date is rejected'
);

select set_config(
  'test.opening',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'voucher_type', 'Opening Entry',
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 100),
      jsonb_build_object('account_id', current_setting('test.capital')::uuid, 'credit', 100)
    )
  )) ->> 'id'),
  true
);
select set_config('test.opening_submitted', public.submit_doc('Journal Entry', current_setting('test.opening')::uuid)::text, true);

select is(
  (
    with hidden as (
      select public.report_general_ledger(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_date', '2026-10-01',
        'to_date', '2026-10-31'
      )) as body
    ),
    shown as (
      select public.report_general_ledger(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_date', '2026-10-01',
        'to_date', '2026-10-31',
        'show_opening_entries', true
      )) as body
    )
    select
      (select count(*) from jsonb_array_elements((select body -> 'rows' from hidden)) r where r ->> 'row_type' = 'entry') = 0
      and (select (r ->> 'debit')::numeric = 100 and (r ->> 'credit')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from hidden)) r
            where r ->> 'row_type' = 'opening')
      and (select count(*) from jsonb_array_elements((select body -> 'rows' from shown)) r where r ->> 'row_type' = 'entry') = 2
      and (select (r ->> 'debit')::numeric = 0 and (r ->> 'credit')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from shown)) r
            where r ->> 'row_type' = 'opening')
  ),
  true,
  'an Opening Entry inside the range stays in Opening until show_opening_entries'
);

select set_config(
  'test.journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 40),
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 60),
      jsonb_build_object('account_id', current_setting('test.sales')::uuid, 'credit', 100)
    )
  )) ->> 'id'),
  true
);
select set_config('test.journal_submitted', public.submit_doc('Journal Entry', current_setting('test.journal')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_general_ledger(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_date', '2026-10-01',
        'to_date', '2026-10-31'
      )) as body
    ),
    filtered as (
      select public.report_general_ledger(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_date', '2026-10-01',
        'to_date', '2026-10-31',
        'account', jsonb_build_array(current_setting('test.cash_group')::uuid)
      )) as body
    )
    select
      (select count(*) from jsonb_array_elements((select body -> 'rows' from report)) r where r ->> 'row_type' = 'entry') = 2
      and (select (r ->> 'debit')::numeric = 100 and (r ->> 'credit')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'row_type' = 'total')
      and (select (r ->> 'balance')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'row_type' = 'closing')
      and (select (r ->> 'balance')::numeric
             from jsonb_array_elements((select body -> 'rows' from report)) with ordinality as t(r, n)
            where r ->> 'row_type' = 'entry'
            order by n
            limit 1) = 100
      and (select count(*) from jsonb_array_elements((select body -> 'rows' from filtered)) r where r ->> 'row_type' = 'entry') = 1
      and (select (r ->> 'debit')::numeric = 100 and (r ->> 'account') like '%Cash on Hand%'
             from jsonb_array_elements((select body -> 'rows' from filtered)) r
            where r ->> 'row_type' = 'entry')
  ),
  true,
  'a journal of 100 returns two consolidated rows, a closing balance of 0, and only cash under the Cash group'
);

select set_config(
  'test.prior',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-09-01',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 100),
      jsonb_build_object('account_id', current_setting('test.sales')::uuid, 'credit', 100)
    )
  )) ->> 'id'),
  true
);
select set_config('test.prior_submitted', public.submit_doc('Journal Entry', current_setting('test.prior')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_general_ledger(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_date', '2026-10-01',
        'to_date', '2026-10-31'
      )) as body
    )
    select
      (select (r ->> 'debit')::numeric = 200 and (r ->> 'credit')::numeric = 200
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'row_type' = 'opening')
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from report)) r
         where r ->> 'row_type' = 'entry'
           and r ->> 'voucher_id' = current_setting('test.prior')
      )
  ),
  true,
  'a journal dated before the range appears only in Opening'
);

select set_config('test.cancelled', public.cancel_doc('Journal Entry', current_setting('test.journal')::uuid)::text, true);
select is(
  (
    select count(*) = 0
      from jsonb_array_elements(public.report_general_ledger(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_date', '2026-10-01',
        'to_date', '2026-10-31'
      )) -> 'rows') r
     where r ->> 'row_type' = 'entry'
       and r ->> 'voucher_id' = current_setting('test.journal')
  ),
  true,
  'cancelling the in-range journal removes it from the report'
);

select * from finish();
rollback;
