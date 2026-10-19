begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000006701', 'party67@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006701","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Party Co", "slug": "party-67", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Party Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
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
  'test.receivable',
  (select default_receivable_account_id::text from public.companies where id = current_setting('test.company')::uuid),
  true
);
select set_config(
  'test.income',
  (select default_income_account_id::text from public.companies where id = current_setting('test.company')::uuid),
  true
);
select set_config(
  'test.capital',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '3101' and not is_group),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager', 'Sales Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000006701';

create function pg_temp.both_rejected() returns boolean
language plpgsql
as $$
declare
  v_company boolean := false;
  v_dates boolean := false;
begin
  begin
    perform public.report_trial_balance_for_party('{}'::jsonb);
  exception when others then
    v_company := sqlerrm like '%tbp_company%';
  end;
  begin
    perform public.report_trial_balance_for_party(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'fiscal_year', current_setting('test.fy')::uuid,
      'party_type', 'Customer',
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

create function pg_temp.party_type_rejected() returns boolean
language plpgsql
as $$
declare
  v_blank boolean := false;
  v_other boolean := false;
begin
  begin
    perform public.report_trial_balance_for_party(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'fiscal_year', current_setting('test.fy')::uuid
    ));
  exception when others then
    v_blank := sqlerrm like '%Party Type is required%';
  end;
  begin
    perform public.report_trial_balance_for_party(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'fiscal_year', current_setting('test.fy')::uuid,
      'party_type', 'Employee'
    ));
  exception when others then
    v_other := sqlerrm like '%Party Type must be Customer or Supplier%';
  end;
  return v_blank and v_other;
end;
$$;

select is(
  pg_temp.party_type_rejected(),
  true,
  'a blank party type is rejected, and a party type other than Customer or Supplier is rejected'
);

select is(
  (
    with report as (
      select public.report_trial_balance_for_party(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'party_type', 'Customer',
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
  'test.acme',
  (public.save_doc('Customer', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'customer_name', 'Acme'
  )) ->> 'id'),
  true
);
select set_config(
  'test.quiet',
  (public.save_doc('Customer', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'customer_name', 'Quiet'
  )) ->> 'id'),
  true
);
select set_config(
  'test.journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', current_setting('test.receivable')::uuid,
        'party_type', 'Customer',
        'party_id', current_setting('test.acme')::uuid,
        'debit', 100
      ),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 100)
    )
  )) ->> 'id'),
  true
);
select set_config('test.journal_submitted', public.submit_doc('Journal Entry', current_setting('test.journal')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_trial_balance_for_party(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'party_type', 'Customer',
        'from_date', '2026-01-01',
        'to_date', '2026-12-31'
      )) as body
    )
    select
      (select (r ->> 'closing_debit')::numeric = 100 and (r ->> 'debit')::numeric = 100 and (r ->> 'opening_debit')::numeric = 0
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'party_id' = current_setting('test.acme'))
      and (select (r ->> 'debit')::numeric = 100
             and (r ->> 'closing_debit')::numeric = 100
             and (r ->> 'credit')::numeric = 0
             and (r ->> 'closing_credit')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'row_type' = 'total')
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from report)) r
         where r ->> 'party_id' = current_setting('test.quiet')
      )
  ),
  true,
  'a journal of 100 returns Acme and a totals row, and a customer with no rows is absent'
);

select set_config(
  'test.mid',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-03-01',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', current_setting('test.receivable')::uuid,
        'party_type', 'Customer',
        'party_id', current_setting('test.acme')::uuid,
        'debit', 40
      ),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 40)
    )
  )) ->> 'id'),
  true
);
select set_config('test.mid_submitted', public.submit_doc('Journal Entry', current_setting('test.mid')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_trial_balance_for_party(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'party_type', 'Customer',
        'from_date', '2026-07-01',
        'to_date', '2026-12-31'
      )) as body
    )
    select (select (r ->> 'opening_debit')::numeric = 40 and (r ->> 'debit')::numeric = 100
              from jsonb_array_elements((select body -> 'rows' from report)) r
             where r ->> 'party_id' = current_setting('test.acme'))
  ),
  true,
  'a journal inside the year but before from_date is opening, not period'
);

select set_config(
  'test.nil',
  (public.save_doc('Customer', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'customer_name', 'Nil'
  )) ->> 'id'),
  true
);
select set_config(
  'test.opening',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'voucher_type', 'Opening Entry',
    'posting_date', '2026-08-01',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', current_setting('test.receivable')::uuid,
        'party_type', 'Customer',
        'party_id', current_setting('test.acme')::uuid,
        'debit', 70
      ),
      jsonb_build_object('account_id', current_setting('test.capital')::uuid, 'credit', 70)
    )
  )) ->> 'id'),
  true
);
select set_config('test.opening_submitted', public.submit_doc('Journal Entry', current_setting('test.opening')::uuid)::text, true);
select set_config(
  'test.net_zero',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-09-01',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', current_setting('test.receivable')::uuid,
        'party_type', 'Customer',
        'party_id', current_setting('test.nil')::uuid,
        'debit', 10
      ),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 10)
    )
  )) ->> 'id'),
  true
);
select set_config('test.net_zero_submitted', public.submit_doc('Journal Entry', current_setting('test.net_zero')::uuid)::text, true);
select set_config(
  'test.net_zero_credit',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-09-02',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'debit', 10),
      jsonb_build_object(
        'account_id', current_setting('test.receivable')::uuid,
        'party_type', 'Customer',
        'party_id', current_setting('test.nil')::uuid,
        'credit', 10
      )
    )
  )) ->> 'id'),
  true
);
select set_config('test.net_zero_credit_submitted', public.submit_doc('Journal Entry', current_setting('test.net_zero_credit')::uuid)::text, true);
select set_config(
  'test.before_cancel',
  public.report_trial_balance_for_party(jsonb_build_object(
    'company', current_setting('test.company')::uuid,
    'fiscal_year', current_setting('test.fy')::uuid,
    'party_type', 'Customer',
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
      select public.report_trial_balance_for_party(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'fiscal_year', current_setting('test.fy')::uuid,
        'party_type', 'Customer',
        'from_date', '2026-01-01',
        'to_date', '2026-12-31'
      )) as body
    )
    select
      (select (r ->> 'opening_debit')::numeric = 70 and (r ->> 'debit')::numeric = 140
         from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
        where r ->> 'party_id' = current_setting('test.acme'))
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
         where r ->> 'party_id' = current_setting('test.nil')
      )
      and (select (r ->> 'debit')::numeric = 40
             from jsonb_array_elements((select body -> 'rows' from after_cancel)) r
            where r ->> 'party_id' = current_setting('test.acme'))
  ),
  true,
  'an Opening Entry stays in opening, a net-zero customer is absent, and cancelling removes the in-range journal'
);

select * from finish();
rollback;
