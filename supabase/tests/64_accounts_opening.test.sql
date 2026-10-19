begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000006401', 'opening64@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006401","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Opening Co", "slug": "opening-64", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Opening Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
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
   and user_id = '00000000-0000-0000-0000-000000006401';

select set_config(
  'test.pl',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'voucher_type', 'Opening Entry',
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '4101' and not is_group
        ),
        'debit', 100
      ),
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '1101' and not is_group
        ),
        'credit', 100
      )
    )
  )) ->> 'id'),
  true
);
select throws_like(
  $$select public.submit_doc('Journal Entry', current_setting('test.pl')::uuid)$$,
  '%gl_opening_pl%',
  'an Opening Entry that debits Sales is rejected'
);

select set_config(
  'test.open',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'voucher_type', 'Opening Entry',
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '1101' and not is_group
        ),
        'debit', 100
      ),
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '3101' and not is_group
        ),
        'credit', 100
      )
    )
  )) ->> 'id'),
  true
);
select set_config('test.submitted', public.submit_doc('Journal Entry', current_setting('test.open')::uuid)::text, true);
select is(
  (
    select count(*) = 2 and bool_and(is_opening) and bool_and(not is_cancelled)
      from public.gl_entry
     where voucher_id = current_setting('test.open')::uuid
  ),
  true,
  'a balanced Opening Entry of 100 posts open rows with is_opening'
);

update public.account
   set account_type = 'Round Off for Opening'
 where company_id = current_setting('test.company')::uuid
   and account_number = '3101'
   and not is_group;
update public.companies
   set round_off_for_opening_id = (
     select id from public.account
      where company_id = current_setting('test.company')::uuid and account_number = '3101' and not is_group
   )
 where id = current_setting('test.company')::uuid;

select set_config(
  'test.diff',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'voucher_type', 'Opening Entry',
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '1101' and not is_group
        ),
        'debit', 100.01
      ),
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '1201' and not is_group
        ),
        'credit', 100
      )
    )
  )) ->> 'id'),
  true
);
select set_config('test.diff_submitted', public.submit_doc('Journal Entry', current_setting('test.diff')::uuid)::text, true);
select is(
  (
    select account_id = (
             select round_off_for_opening_id from public.companies where id = current_setting('test.company')::uuid
           )
       and credit = 0.01
       and is_opening
       and not exists (
         select 1
           from public.gl_entry other
          where other.voucher_id = current_setting('test.diff')::uuid
            and other.account_id = (
              select round_off_account_id from public.companies where id = current_setting('test.company')::uuid
            )
       )
      from public.gl_entry
     where voucher_id = current_setting('test.diff')::uuid
       and remarks = 'Round Off'
       and not is_cancelled
  ),
  true,
  'a 0.01 difference posts to Round Off for Opening and not the normal Round Off account'
);

update public.companies
   set round_off_for_opening_id = null
 where id = current_setting('test.company')::uuid;
select set_config(
  'test.blank',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'voucher_type', 'Opening Entry',
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '1101' and not is_group
        ),
        'debit', 100.01
      ),
      jsonb_build_object(
        'account_id', (
          select id from public.account
           where company_id = current_setting('test.company')::uuid and account_number = '1201' and not is_group
        ),
        'credit', 100
      )
    )
  )) ->> 'id'),
  true
);
select throws_like(
  $$select public.submit_doc('Journal Entry', current_setting('test.blank')::uuid)$$,
  '%gl_round_off_opening%',
  'a blank Round Off for Opening account rejects the difference and leaves the normal Round Off account unused'
);

select * from finish();
rollback;
