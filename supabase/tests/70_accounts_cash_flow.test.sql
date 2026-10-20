begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007001', 'cf70@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007001","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Cash Flow Co", "slug": "cf-70", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Cash Flow Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
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
  'test.land',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '1701' and not is_group),
  true
);
select set_config(
  'test.receivable',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '1301' and not is_group),
  true
);
select set_config(
  'test.depreciation',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '5116' and not is_group),
  true
);
select set_config(
  'test.accum',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '1801' and not is_group),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager', 'Sales Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007001';

select set_config(
  'test.customer',
  (public.save_doc('Customer', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'customer_name', 'Acme'
  )) ->> 'id'),
  true
);

create function pg_temp.filters_rejected() returns boolean
language plpgsql
as $$
declare
  v_company boolean := false;
  v_dates boolean := false;
  v_year boolean := false;
begin
  begin
    perform public.report_cash_flow('{}'::jsonb);
  exception when others then
    v_company := sqlerrm like '%cf_company%';
  end;
  begin
    perform public.report_cash_flow(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'filter_based_on', 'Date Range',
      'period_start_date', '2026-12-31',
      'period_end_date', '2026-01-01'
    ));
  exception when others then
    v_dates := sqlerrm like '%To Date cannot be less than From Date%';
  end;
  begin
    perform public.report_cash_flow(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'from_fiscal_year', current_setting('test.fy')::uuid,
      'to_fiscal_year', current_setting('test.fy_prior')::uuid
    ));
  exception when others then
    v_year := sqlerrm like '%End Year cannot be before Start Year%';
  end;
  return v_company and v_dates and v_year;
end;
$$;

select is(
  pg_temp.filters_rejected()
  and (
    select (body -> 'columns' -> 1 ->> 'to_date') = '2026-03-31'
      from (
        select public.report_cash_flow(jsonb_build_object(
          'company', current_setting('test.company')::uuid,
          'filter_based_on', 'Date Range',
          'periodicity', 'Monthly',
          'period_start_date', '2026-03-15',
          'period_end_date', '2026-04-30'
        )) as body
      ) report
  ),
  true,
  'a missing company, a reversed date range, and a reversed fiscal year are rejected, and a monthly date range starting 15 Mar ends on 31 Mar'
);

select set_config(
  'test.sale',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 500),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 500)
    )
  )) ->> 'id'),
  true
);
select set_config('test.sale_submitted', public.submit_doc('Journal Entry', current_setting('test.sale')::uuid)::text, true);

select set_config(
  'test.land_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.land')::uuid, 'debit', 80),
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'credit', 80)
    )
  )) ->> 'id'),
  true
);
select set_config('test.land_submitted', public.submit_doc('Journal Entry', current_setting('test.land_journal')::uuid)::text, true);

select set_config(
  'test.receivable_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', current_setting('test.receivable')::uuid,
        'party_type', 'Customer',
        'party_id', current_setting('test.customer')::uuid,
        'debit', 30
      ),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 30)
    )
  )) ->> 'id'),
  true
);
select set_config('test.receivable_submitted', public.submit_doc('Journal Entry', current_setting('test.receivable_journal')::uuid)::text, true);

select set_config(
  'test.depreciation_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.depreciation')::uuid, 'debit', 40),
      jsonb_build_object('account_id', current_setting('test.accum')::uuid, 'credit', 40)
    )
  )) ->> 'id'),
  true
);
select set_config('test.depreciation_submitted', public.submit_doc('Journal Entry', current_setting('test.depreciation_journal')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_cash_flow(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid
      )) as body
    )
    select
      (select (r ->> 'dec_2026')::numeric = 490
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'section' = '''Profit for the year''')
      and (select (r ->> 'dec_2026')::numeric = 40
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Depreciation')
      and (select (r ->> 'dec_2026')::numeric = -30
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Net Change in Accounts Receivable')
      and (select (r ->> 'dec_2026')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Net Change in Accounts Payable')
      and (select (r ->> 'dec_2026')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Net Change in Inventory')
      and (select (r ->> 'dec_2026')::numeric = 500
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = '''Net Cash from Operations''')
      and (select (r ->> 'dec_2026')::numeric = -80
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Net Change in Fixed Asset')
      and (select (r ->> 'dec_2026')::numeric = -80
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = '''Net Cash from Investing''')
      and (select (r ->> 'dec_2026')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Net Change in Equity')
      and (select (r ->> 'dec_2026')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = '''Net Cash from Financing''')
      and (select (r ->> 'dec_2026')::numeric = 420
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = '''Net Change in Cash''')
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from report)) r
         where r ->> 'section' like '1101%'
      )
      and (select body -> 'chart' ->> 'type' = 'bar' from report)
      and (select (body -> 'chart' -> 'datasets' -> 0 -> 'values' -> 0)::numeric = 500 from report)
      and (select (s ->> 'value')::numeric = 420
             from jsonb_array_elements((select body -> 'summary' from report)) s
            where s ->> 'label' = 'Net Change in Cash')
  ),
  true,
  'a yearly statement adds back depreciation, subtracts the receivable and the fixed asset, and leaves cash itself off the rows'
);

select set_config(
  'test.prior',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2025-06-01',
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
      select public.report_cash_flow(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid,
        'show_opening_and_closing_balance', true
      )) as body
    )
    select
      (select (r ->> 'dec_2026')::numeric = 490
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'section' = '''Profit for the year''')
      and (select count(*) = 2 and bool_and((r ->> 'dec_2026')::numeric = 420)
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = '''Net Change in Cash''')
      and (select (r ->> 'dec_2026')::numeric = 200
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Opening')
      and (select (r ->> 'dec_2026')::numeric = 620
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Closing (Opening + Total)')
  ),
  true,
  'opening cash from the prior year is 200 and closing cash is 620, while the 2026 movement stays 420'
);

select set_config(
  'test.march',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-03-10',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 25),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 25)
    )
  )) ->> 'id'),
  true
);
select set_config('test.march_submitted', public.submit_doc('Journal Entry', current_setting('test.march')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_cash_flow(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid,
        'periodicity', 'Monthly',
        'accumulated_values', false
      )) as body
    )
    select
      (select (r ->> 'mar_2026')::numeric = 25
          and (r ->> 'oct_2026')::numeric = 490
          and (r ->> 'total')::numeric = 515
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'section' = '''Profit for the year''')
      and (select (r ->> 'mar_2026')::numeric = 0
              and (r ->> 'oct_2026')::numeric = -80
              and (r ->> 'total')::numeric = -80
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = 'Net Change in Fixed Asset')
      and (select (r ->> 'mar_2026')::numeric = 25
              and (r ->> 'oct_2026')::numeric = 420
              and (r ->> 'total')::numeric = 445
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'section' = '''Net Change in Cash''')
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
  'monthly columns keep the March sale apart from October, and the Total column adds the movements'
);

select set_config(
  'test.before_cancel',
  public.report_cash_flow(jsonb_build_object(
    'company', current_setting('test.company')::uuid,
    'from_fiscal_year', current_setting('test.fy')::uuid,
    'to_fiscal_year', current_setting('test.fy')::uuid
  ))::text,
  true
);
select set_config('test.cancelled', public.cancel_doc('Journal Entry', current_setting('test.land_journal')::uuid)::text, true);

select is(
  (
    with before_cancel as (
      select current_setting('test.before_cancel')::jsonb as body
    ),
    after_cancel as (
      select public.report_cash_flow(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid
      )) as body
    )
    select
      (select (r ->> 'dec_2026')::numeric = -80
         from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
        where r ->> 'section' = '''Net Cash from Investing''')
      and (select (r ->> 'dec_2026')::numeric = 445
             from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
            where r ->> 'section' = '''Net Change in Cash''')
      and (select (r ->> 'dec_2026')::numeric = 0
             from jsonb_array_elements((select body -> 'rows' from after_cancel)) r
            where r ->> 'section' = '''Net Cash from Investing''')
      and (select (r ->> 'dec_2026')::numeric = 525
             from jsonb_array_elements((select body -> 'rows' from after_cancel)) r
            where r ->> 'section' = '''Net Change in Cash''')
      and (select (r ->> 'dec_2026')::numeric = 515
             from jsonb_array_elements((select body -> 'rows' from after_cancel)) r
            where r ->> 'section' = '''Profit for the year''')
  ),
  true,
  'cancelling the fixed-asset purchase removes the investing outflow and raises net change in cash'
);

select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Cash Flow Other", "slug": "cf-70-b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Cash Flow Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.other_company',
  (select id::text from public.companies where org_id = current_setting('test.other')::uuid limit 1),
  true
);
select set_config(
  'test.other_fy',
  (select id::text from public.fiscal_year where org_id = current_setting('test.other')::uuid and year_start_date = '2026-01-01'),
  true
);

select is(
  (
    with report as (
      select public.report_cash_flow(jsonb_build_object(
        'company', current_setting('test.other_company')::uuid,
        'from_fiscal_year', current_setting('test.other_fy')::uuid,
        'to_fiscal_year', current_setting('test.other_fy')::uuid
      )) as body
    )
    select
      (select (r ->> 'dec_2026')::numeric = 0
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'section' = '''Net Change in Cash''')
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from report)) r
         where r ->> 'section' = '''Profit for the year'''
      )
  ),
  true,
  'another organization sees no profit row and a net change of zero'
);

select * from finish();
rollback;
