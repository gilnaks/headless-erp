begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000006901', 'bs69@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006901","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Balance Co", "slug": "bs-69", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Balance Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
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
  'test.fy_prior',
  (public.save_doc('Fiscal Year', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'year_start_date', '2025-01-01',
    'year_end_date', '2025-12-31'
  )) ->> 'id'),
  true
);
select set_config(
  'test.income',
  (select default_income_account_id::text from public.companies where id = current_setting('test.company')::uuid),
  true
);
select set_config(
  'test.cash',
  (select default_cash_account_id::text from public.companies where id = current_setting('test.company')::uuid),
  true
);
select set_config(
  'test.capital',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '3101' and not is_group),
  true
);
select set_config(
  'test.deposit',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '2500' and not is_group),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000006901';

create function pg_temp.both_rejected() returns boolean
language plpgsql
as $$
declare
  v_company boolean := false;
  v_dates boolean := false;
begin
  begin
    perform public.report_balance_sheet('{}'::jsonb);
  exception when others then
    v_company := sqlerrm like '%bs_company%';
  end;
  begin
    perform public.report_balance_sheet(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'filter_based_on', 'Date Range',
      'period_start_date', '2026-12-31',
      'period_end_date', '2026-01-01'
    ));
  exception when others then
    v_dates := sqlerrm like '%To Date cannot be less than From Date%';
  end;
  return v_company and v_dates;
end;
$$;

select is(
  pg_temp.both_rejected(),
  true,
  'a missing company is rejected, and a date range whose to-date is before the from-date is rejected'
);

create function pg_temp.year_order_rejected() returns boolean
language plpgsql
as $$
declare
  v_year boolean := false;
begin
  begin
    perform public.report_balance_sheet(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'from_fiscal_year', current_setting('test.fy')::uuid,
      'to_fiscal_year', current_setting('test.fy_prior')::uuid
    ));
  exception when others then
    v_year := sqlerrm like '%End Year cannot be before Start Year%';
  end;
  return v_year;
end;
$$;

select is(
  pg_temp.year_order_rejected()
  and (
    select (body -> 'columns' -> 1 ->> 'to_date') = '2026-03-31'
      from (
        select public.report_balance_sheet(jsonb_build_object(
          'company', current_setting('test.company')::uuid,
          'filter_based_on', 'Date Range',
          'periodicity', 'Monthly',
          'period_start_date', '2026-03-15',
          'period_end_date', '2026-04-30'
        )) as body
      ) report
  ),
  true,
  'an end fiscal year before the start year is rejected, and a monthly date range starting 15 Mar ends on 31 Mar'
);

select set_config(
  'test.capital_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 1000),
      jsonb_build_object('account_id', current_setting('test.capital')::uuid, 'credit', 1000)
    )
  )) ->> 'id'),
  true
);
select set_config('test.capital_submitted', public.submit_doc('Journal Entry', current_setting('test.capital_journal')::uuid)::text, true);

select set_config(
  'test.sales_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 110),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 100),
      jsonb_build_object('account_id', current_setting('test.deposit')::uuid, 'credit', 10)
    )
  )) ->> 'id'),
  true
);
select set_config('test.sales_submitted', public.submit_doc('Journal Entry', current_setting('test.sales_journal')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_balance_sheet(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid
      )) as body
    )
    select
      (select (r ->> 'dec_2026')::numeric = 1110
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.cash'))
      and (select (r ->> 'dec_2026')::numeric = 1110
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Total Asset (Debit)''')
      and (select (r ->> 'dec_2026')::numeric = 10
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account_id' = current_setting('test.deposit'))
      and (select (r ->> 'dec_2026')::numeric = 10
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Total Liability (Credit)''')
      and (select (r ->> 'dec_2026')::numeric = 1000
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account_id' = current_setting('test.capital'))
      and (select (r ->> 'dec_2026')::numeric = 1000
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Total Equity (Credit)''')
      and (select (r ->> 'dec_2026')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Provisional Profit / Loss (Credit)''')
      and (select (r ->> 'dec_2026')::numeric = 1110
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Total (Credit)''')
      and (select (asset ->> 'dec_2026')::numeric
                = (liability ->> 'dec_2026')::numeric
                + (equity ->> 'dec_2026')::numeric
                + (provisional ->> 'dec_2026')::numeric
             from jsonb_array_elements((select body -> 'rows' from report)) asset,
                  jsonb_array_elements((select body -> 'rows' from report)) liability,
                  jsonb_array_elements((select body -> 'rows' from report)) equity,
                  jsonb_array_elements((select body -> 'rows' from report)) provisional
            where asset ->> 'account' = '''Total Asset (Debit)'''
              and liability ->> 'account' = '''Total Liability (Credit)'''
              and equity ->> 'account' = '''Total Equity (Credit)'''
              and provisional ->> 'account' = '''Provisional Profit / Loss (Credit)''')
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from report)) r
         where r ->> 'account_id' = current_setting('test.income')
            or r ->> 'account' = '''Unclosed Fiscal Years Profit / Loss (Credit)'''
      )
      and (select jsonb_array_length(body -> 'warnings') = 0 from report)
      and exists (
        select 1
          from jsonb_array_elements((select body -> 'summary' from report)) s
         where s ->> 'label' = 'Total Asset'
           and (s ->> 'value')::numeric = 1110
      )
      and (select body -> 'chart' ->> 'type' = 'line' and body -> 'chart' -> 'labels' ->> 0 = '2026' from report)
      and exists (
        select 1
          from jsonb_array_elements((select body -> 'chart' -> 'datasets' from report)) d
         where d ->> 'name' = 'Assets'
           and (d -> 'values' ->> 0)::numeric = 1110
      )
  ),
  true,
  'a journal of 1000 capital and 100 income returns the trees, the profit, the summary, and a line chart'
);

select set_config(
  'test.prior',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2025-06-15',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 200),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 200)
    )
  )) ->> 'id'),
  true
);
select set_config('test.prior_submitted', public.submit_doc('Journal Entry', current_setting('test.prior')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_balance_sheet(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid
      )) as body
    )
    select
      (select (r ->> 'dec_2026')::numeric = 1310
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.cash'))
      and (select (r ->> 'dec_2026')::numeric = 200
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Unclosed Fiscal Years Profit / Loss (Credit)''')
      and (select (r ->> 'dec_2026')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Provisional Profit / Loss (Credit)''')
      and (select body -> 'warnings' ->> 0 = 'Previous Financial Year is not closed' from report)
      and (select (asset ->> 'dec_2026')::numeric
                = (liability ->> 'dec_2026')::numeric
                + (equity ->> 'dec_2026')::numeric
                + (provisional ->> 'dec_2026')::numeric
                + (unclosed ->> 'dec_2026')::numeric
             from jsonb_array_elements((select body -> 'rows' from report)) asset,
                  jsonb_array_elements((select body -> 'rows' from report)) liability,
                  jsonb_array_elements((select body -> 'rows' from report)) equity,
                  jsonb_array_elements((select body -> 'rows' from report)) provisional,
                  jsonb_array_elements((select body -> 'rows' from report)) unclosed
            where asset ->> 'account' = '''Total Asset (Debit)'''
              and liability ->> 'account' = '''Total Liability (Credit)'''
              and equity ->> 'account' = '''Total Equity (Credit)'''
              and provisional ->> 'account' = '''Provisional Profit / Loss (Credit)'''
              and unclosed ->> 'account' = '''Unclosed Fiscal Years Profit / Loss (Credit)''')
  ),
  true,
  'a 2025 sales credit adds the unclosed row and leaves provisional profit at 100'
);

select set_config(
  'test.march',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-03-10',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 30),
      jsonb_build_object('account_id', current_setting('test.capital')::uuid, 'credit', 30)
    )
  )) ->> 'id'),
  true
);
select set_config('test.march_submitted', public.submit_doc('Journal Entry', current_setting('test.march')::uuid)::text, true);

select set_config(
  'test.october',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-20',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 100),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 100)
    )
  )) ->> 'id'),
  true
);
select set_config('test.october_submitted', public.submit_doc('Journal Entry', current_setting('test.october')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_balance_sheet(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid,
        'periodicity', 'Monthly',
        'accumulated_values', false
      )) as body
    )
    select
      (select (r ->> 'mar_2026')::numeric = 30
          and (r ->> 'oct_2026')::numeric = 1210
          and (r ->> 'total')::numeric = (r ->> 'mar_2026')::numeric + (r ->> 'oct_2026')::numeric
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.cash'))
      and exists (
        select 1 from jsonb_array_elements((select body -> 'columns' from report)) c
         where c ->> 'label' = 'Mar 2026'
      )
      and exists (
        select 1 from jsonb_array_elements((select body -> 'columns' from report)) c
         where c ->> 'label' = 'Oct 2026'
      )
      and exists (
        select 1 from jsonb_array_elements((select body -> 'columns' from report)) c
         where c ->> 'field' = 'total'
      )
  ),
  true,
  'monthly columns keep March and October apart, and the Total column adds the cash movements'
);

select set_config(
  'test.before_cancel',
  public.report_balance_sheet(jsonb_build_object(
    'company', current_setting('test.company')::uuid,
    'from_fiscal_year', current_setting('test.fy')::uuid,
    'to_fiscal_year', current_setting('test.fy')::uuid,
    'periodicity', 'Monthly',
    'accumulated_values', true
  ))::text,
  true
);
select set_config('test.cancelled', public.cancel_doc('Journal Entry', current_setting('test.october')::uuid)::text, true);

select is(
  (
    with before_cancel as (
      select current_setting('test.before_cancel')::jsonb as body
    ),
    after_cancel as (
      select public.report_balance_sheet(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid,
        'periodicity', 'Monthly',
        'accumulated_values', true
      )) as body
    )
    select
      (select (r ->> 'mar_2026')::numeric = 30 and (r ->> 'oct_2026')::numeric = 1030
         from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
        where r ->> 'account_id' = current_setting('test.capital'))
      and (select (r ->> 'mar_2026')::numeric = 230 and (r ->> 'oct_2026')::numeric = 1440
             from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
            where r ->> 'account_id' = current_setting('test.cash'))
      and not exists (
        select 1 from jsonb_array_elements((select body -> 'columns' from before_cancel)) c
         where c ->> 'field' = 'total'
      )
      and (select (r ->> 'mar_2026')::numeric = 230 and (r ->> 'oct_2026')::numeric = 1340
             from jsonb_array_elements((select body -> 'rows' from after_cancel)) r
            where r ->> 'account_id' = current_setting('test.cash'))
  ),
  true,
  'accumulated months show a running total, and cancelling the October journal leaves March'
);

select * from finish();
rollback;
