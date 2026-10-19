begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000006601', 'trial66@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006601","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Trial Co", "slug": "trial-66", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Trial Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.company',
  (select id::text from public.companies where org_id = current_setting('test.org')::uuid limit 1),
  true
);
select set_config(
  'test.fy',
  (select id::text from public.fiscal_year where org_id = current_setting('test.org')::uuid and year_start_date = '2026-01-01'),
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
select set_config(
  'test.bank',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '1201' and not is_group),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000006601';

create function pg_temp.both_rejected() returns boolean
language plpgsql
as $$
declare
  v_company boolean := false;
  v_dates boolean := false;
begin
  begin
    perform public.report_trial_balance('{}'::jsonb);
  exception when others then
    v_company := sqlerrm like '%tb_company%';
  end;
  begin
    perform public.report_trial_balance(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'fiscal_year', current_setting('test.fy')::uuid,
      'from_date', '2026-12-31',
      'to_date', '2026-01-01'
    ));
  exception when others then
    v_dates := sqlerrm like '%From Date cannot be greater than To Date%';
  end;
  return v_company and v_dates;
end;
$$;

select is(
  pg_temp.both_rejected(),
  true,
  'a missing company is rejected, and a from-date after the to-date is rejected'
);

select is(
  (
    with report as (
      select public.report_trial_balance(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'from_date', '2025-06-01',
        'to_date', '2026-06-30'
      )) as body
    )
    select (select body ->> 'from_date' = '2026-01-01' from report)
       and exists (
         select 1
           from jsonb_array_elements_text((select body -> 'warnings' from report)) warning
          where warning like '%Assuming From Date = 2026-01-01%'
       )
  ),
  true,
  'a date before the fiscal year is clamped, and the warning names the year start'
);

select set_config(
  'test.journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 100),
      jsonb_build_object('account_id', current_setting('test.sales')::uuid, 'credit', 100)
    )
  )) ->> 'id'),
  true
);
select set_config('test.journal_submitted', public.submit_doc('Journal Entry', current_setting('test.journal')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_trial_balance(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'from_date', '2026-01-01',
        'to_date', '2026-12-31'
      )) as body
    )
    select
      (select (r ->> 'closing_debit')::numeric = 100 and (r ->> 'closing_credit')::numeric = 0
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.cash'))
      and (select (r ->> 'closing_credit')::numeric = 100 and (r ->> 'closing_debit')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account_id' = current_setting('test.sales'))
      and (select (r ->> 'closing_debit')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account_id' = current_setting('test.cash_group'))
      and (select (r ->> 'debit')::numeric = 100
             and (r ->> 'credit')::numeric = 100
             and (r ->> 'closing_debit')::numeric = 100
             and (r ->> 'closing_credit')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'row_type' = 'total')
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from report)) r
         where r ->> 'account_id' = current_setting('test.bank')
      )
  ),
  true,
  'a journal of 100 returns cash, sales, the Cash group, and a balanced total, and a zero account is absent'
);

select set_config(
  'test.mid',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-03-01',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 40),
      jsonb_build_object('account_id', current_setting('test.sales')::uuid, 'credit', 40)
    )
  )) ->> 'id'),
  true
);
select set_config('test.mid_submitted', public.submit_doc('Journal Entry', current_setting('test.mid')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_trial_balance(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'from_date', '2026-07-01',
        'to_date', '2026-12-31'
      )) as body
    )
    select
      (select (r ->> 'opening_debit')::numeric = 40 and (r ->> 'debit')::numeric = 100
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.cash'))
      and (select (r ->> 'opening_credit')::numeric = 40 and (r ->> 'credit')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account_id' = current_setting('test.sales'))
  ),
  true,
  'a journal inside the year but before from_date is opening for the balance-sheet and income accounts'
);

select set_config(
  'test.fy_prior',
  (public.save_doc('Fiscal Year', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'year_start_date', '2025-01-01',
    'year_end_date', '2025-12-31'
  )) ->> 'id'),
  true
);
select set_config(
  'test.prior',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2025-12-15',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 25),
      jsonb_build_object('account_id', current_setting('test.sales')::uuid, 'credit', 25)
    )
  )) ->> 'id'),
  true
);
select set_config('test.prior_submitted', public.submit_doc('Journal Entry', current_setting('test.prior')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_trial_balance(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'from_date', '2026-01-01',
        'to_date', '2026-12-31'
      )) as body
    )
    select
      (select (r ->> 'opening_debit')::numeric = 25
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.cash'))
      and (select (r ->> 'opening_credit')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account_id' = current_setting('test.sales'))
  ),
  true,
  'a journal before the year start is opening for Cash and is not opening for Sales'
);

select set_config(
  'test.opening',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'voucher_type', 'Opening Entry',
    'posting_date', '2026-08-01',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 70),
      jsonb_build_object('account_id', current_setting('test.capital')::uuid, 'credit', 70)
    )
  )) ->> 'id'),
  true
);
select set_config('test.opening_submitted', public.submit_doc('Journal Entry', current_setting('test.opening')::uuid)::text, true);
select set_config(
  'test.before_cancel',
  public.report_trial_balance(jsonb_build_object(
    'company', current_setting('test.company')::uuid,
    'fiscal_year', current_setting('test.fy')::uuid,
    'from_date', '2026-01-01',
    'to_date', '2026-12-31'
  ))::text,
  true
);
select set_config('test.cancelled', public.cancel_doc('Journal Entry', current_setting('test.journal')::uuid)::text, true);

select is(
  (
    with before_cancel as (
      select current_setting('test.before_cancel')::jsonb as body
    ),
    after_cancel as (
      select public.report_trial_balance(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'from_date', '2026-01-01',
        'to_date', '2026-12-31'
      )) as body
    )
    select
      (select (r ->> 'opening_debit')::numeric = 95 and (r ->> 'debit')::numeric = 140
         from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
        where r ->> 'account_id' = current_setting('test.cash'))
      and (select (r ->> 'opening_credit')::numeric = 70 and (r ->> 'debit')::numeric = 0 and (r ->> 'credit')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
            where r ->> 'account_id' = current_setting('test.capital'))
      and (select (r ->> 'debit')::numeric = 40
             from jsonb_array_elements((select body -> 'rows' from after_cancel)) r
            where r ->> 'account_id' = current_setting('test.cash'))
  ),
  true,
  'an Opening Entry stays in the opening columns, and cancelling the in-range journal removes it'
);

select * from finish();
rollback;
