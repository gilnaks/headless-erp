begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000006801', 'pl68@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006801","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Profit Co", "slug": "pl-68", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Profit Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
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
  'test.expense',
  (select id::text from public.account where company_id = current_setting('test.company')::uuid and account_number = '5500' and not is_group),
  true
);
select set_config(
  'test.unused',
  (select id::text from public.account
    where company_id = current_setting('test.company')::uuid
      and root_type = 'Expense'
      and not is_group
      and id <> current_setting('test.expense')::uuid
    limit 1),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000006801';

create function pg_temp.both_rejected() returns boolean
language plpgsql
as $$
declare
  v_company boolean := false;
  v_dates boolean := false;
begin
  begin
    perform public.report_profit_and_loss('{}'::jsonb);
  exception when others then
    v_company := sqlerrm like '%pl_company%';
  end;
  begin
    perform public.report_profit_and_loss(jsonb_build_object(
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
    perform public.report_profit_and_loss(jsonb_build_object(
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
        select public.report_profit_and_loss(jsonb_build_object(
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
  'test.journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 60),
      jsonb_build_object('account_id', current_setting('test.expense')::uuid, 'debit', 40),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 100)
    )
  )) ->> 'id'),
  true
);
select set_config('test.journal_submitted', public.submit_doc('Journal Entry', current_setting('test.journal')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_profit_and_loss(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid
      )) as body
    )
    select
      (select (r ->> 'dec_2026')::numeric = 100 and r ->> 'account' like '%Sales%'
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.income'))
      and (select count(*) >= 2
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'is_group' = 'true'
              and (r ->> 'dec_2026')::numeric = 100)
      and (select (r ->> 'dec_2026')::numeric = 100
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Total Income (Credit)''')
      and (select (r ->> 'dec_2026')::numeric = 40
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Total Expense (Debit)''')
      and (select (r ->> 'dec_2026')::numeric = 60
             from jsonb_array_elements((select body -> 'rows' from report)) r
            where r ->> 'account' = '''Profit for the year''')
      and exists (
        select 1
          from jsonb_array_elements((select body -> 'summary' from report)) s
         where s ->> 'label' = 'Total Income This Year'
           and (s ->> 'value')::numeric = 100
      )
      and (select body -> 'chart' ->> 'type' = 'bar' and body -> 'chart' -> 'labels' ->> 0 = '2026' from report)
      and exists (
        select 1
          from jsonb_array_elements((select body -> 'chart' -> 'datasets' from report)) d
         where d ->> 'name' = 'Income'
           and (d -> 'values' ->> 0)::numeric = 100
      )
      and not exists (
        select 1
          from jsonb_array_elements((select body -> 'rows' from report)) r
         where r ->> 'account_id' in (current_setting('test.cash'), current_setting('test.unused'))
      )
  ),
  true,
  'a journal of 100 income and 40 expense returns the tree, the profit, the yearly summary, and a bar chart'
);

select set_config(
  'test.prior',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2025-06-15',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 25),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 25)
    )
  )) ->> 'id'),
  true
);
select set_config('test.prior_submitted', public.submit_doc('Journal Entry', current_setting('test.prior')::uuid)::text, true);

select is(
  (
    select (r ->> 'dec_2026')::numeric = 60
      from jsonb_array_elements(public.report_profit_and_loss(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid
      )) -> 'rows') r
     where r ->> 'account' = '''Profit for the year'''
  ),
  true,
  'a sales credit from the prior fiscal year does not change the 2026 profit'
);

select set_config(
  'test.march',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-03-10',
    'accounts', jsonb_build_array(
      jsonb_build_object('account_id', current_setting('test.cash')::uuid, 'debit', 30),
      jsonb_build_object('account_id', current_setting('test.income')::uuid, 'credit', 30)
    )
  )) ->> 'id'),
  true
);
select set_config('test.march_submitted', public.submit_doc('Journal Entry', current_setting('test.march')::uuid)::text, true);

select is(
  (
    with report as (
      select public.report_profit_and_loss(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid,
        'periodicity', 'Monthly'
      )) as body
    )
    select
      (select (r ->> 'mar_2026')::numeric = 30
          and (r ->> 'oct_2026')::numeric = 100
          and (r ->> 'total')::numeric = 130
         from jsonb_array_elements((select body -> 'rows' from report)) r
        where r ->> 'account_id' = current_setting('test.income'))
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
  'monthly columns keep March and October apart, and the Total column adds them'
);

select set_config(
  'test.before_cancel',
  public.report_profit_and_loss(jsonb_build_object(
    'company', current_setting('test.company')::uuid,
    'from_fiscal_year', current_setting('test.fy')::uuid,
    'to_fiscal_year', current_setting('test.fy')::uuid,
    'periodicity', 'Monthly',
    'accumulated_values', true
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
      select public.report_profit_and_loss(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_fiscal_year', current_setting('test.fy')::uuid,
        'to_fiscal_year', current_setting('test.fy')::uuid,
        'periodicity', 'Monthly',
        'accumulated_values', true
      )) as body
    )
    select
      (select (r ->> 'mar_2026')::numeric = 30 and (r ->> 'oct_2026')::numeric = 130
         from jsonb_array_elements((select body -> 'rows' from before_cancel)) r
        where r ->> 'account_id' = current_setting('test.income'))
      and not exists (
        select 1 from jsonb_array_elements((select body -> 'columns' from before_cancel)) c
         where c ->> 'field' = 'total'
      )
      and (select (r ->> 'mar_2026')::numeric = 30 and (r ->> 'oct_2026')::numeric = 30
             from jsonb_array_elements((select body -> 'rows' from after_cancel)) r
            where r ->> 'account_id' = current_setting('test.income'))
  ),
  true,
  'accumulated months show a running total, and cancelling the October journal leaves March'
);

select * from finish();
rollback;
