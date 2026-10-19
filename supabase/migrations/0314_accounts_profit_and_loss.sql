-- Default Profit and Loss Statement: Income and Expense by period, then profit.
-- Ports execute() in erpnext/accounts/report/profit_and_loss_statement/profit_and_loss_statement.py
-- and get_period_list / get_data / get_chart_data in financial_statements.py.
-- Growth, Margin, cost center, project, finance books, and presentation currency wait.
-- There is no Period Closing Voucher, so ignoring closing entries is a no-op.

create or replace function app.report_profit_and_loss(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_filter text;
  v_periodicity text;
  v_accumulated boolean;
  v_zeros boolean;
  v_from_fy uuid;
  v_to_fy uuid;
  v_range_start date;
  v_range_end date;
  v_months int;
  v_mon text[] := array['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  v_cursor date;
  v_from date;
  v_to date;
  v_bucket date;
  v_label_from date;
  v_label text;
  v_key text;
  v_periods jsonb := '[]'::jsonb;
  v_guard int := 0;
  v_total_col boolean;
  v_income_rows jsonb := '[]'::jsonb;
  v_expense_rows jsonb := '[]'::jsonb;
  v_income_amounts jsonb := '{}'::jsonb;
  v_expense_amounts jsonb := '{}'::jsonb;
  v_has_income boolean := false;
  v_has_expense boolean := false;
  v_rows jsonb := '[]'::jsonb;
  v_columns jsonb;
  v_period jsonb;
  v_inc numeric;
  v_exp numeric;
  v_profit numeric;
  v_income_sum numeric := 0;
  v_expense_sum numeric := 0;
  v_profit_sum numeric := 0;
  v_last_income numeric := 0;
  v_last_expense numeric := 0;
  v_last_profit numeric := 0;
  v_has_profit boolean := false;
  v_income_total jsonb;
  v_expense_total jsonb;
  v_profit_row jsonb;
  v_chart_labels jsonb := '[]'::jsonb;
  v_chart_income jsonb := '[]'::jsonb;
  v_chart_expense jsonb := '[]'::jsonb;
  v_chart_profit jsonb := '[]'::jsonb;
  v_summary_income numeric;
  v_summary_expense numeric;
  v_summary_profit numeric;
  v_income_label text;
  v_expense_label text;
  v_profit_label text;
  v_datasets jsonb := '[]'::jsonb;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'pl_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'pl_company: Company is mandatory';
  end if;

  v_filter := coalesce(nullif(p_filters ->> 'filter_based_on', ''), 'Fiscal Year');
  if v_filter not in ('Fiscal Year', 'Date Range') then
    raise exception using errcode = 'P0001', message = 'pl_filter: Filter Based On must be Fiscal Year or Date Range';
  end if;

  v_periodicity := coalesce(nullif(p_filters ->> 'periodicity', ''), 'Yearly');
  if v_periodicity not in ('Monthly', 'Quarterly', 'Half-Yearly', 'Yearly') then
    raise exception using errcode = 'P0001',
      message = 'pl_periodicity: Periodicity must be Monthly, Quarterly, Half-Yearly, or Yearly';
  end if;

  v_accumulated := coalesce(nullif(p_filters ->> 'accumulated_values', '')::boolean, false);
  v_zeros := coalesce(nullif(p_filters ->> 'show_zero_values', '')::boolean, false);
  v_months := case v_periodicity when 'Yearly' then 12 when 'Half-Yearly' then 6 when 'Quarterly' then 3 else 1 end;

  if v_filter = 'Fiscal Year' then
    if nullif(p_filters ->> 'from_fiscal_year', '') is null
       or (p_filters ->> 'from_fiscal_year') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or nullif(p_filters ->> 'to_fiscal_year', '') is null
       or (p_filters ->> 'to_fiscal_year') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception using errcode = 'P0001', message = 'pl_fiscal_year: Start Year and End Year are mandatory';
    end if;
    v_from_fy := (p_filters ->> 'from_fiscal_year')::uuid;
    v_to_fy := (p_filters ->> 'to_fiscal_year')::uuid;

    select fy.year_start_date into v_range_start
      from public.fiscal_year fy
     where fy.id = v_from_fy and fy.org_id = v_org;
    select fy.year_end_date into v_range_end
      from public.fiscal_year fy
     where fy.id = v_to_fy and fy.org_id = v_org;
    if v_range_start is null or v_range_end is null then
      raise exception using errcode = 'P0001', message = 'pl_fiscal_year: Start Year and End Year are mandatory';
    end if;
    if v_range_end < v_range_start then
      raise exception using errcode = 'P0001', message = 'pl_fiscal_year: End Year cannot be before Start Year';
    end if;
  else
    if nullif(p_filters ->> 'period_start_date', '') is null or nullif(p_filters ->> 'period_end_date', '') is null then
      raise exception using errcode = 'P0001', message = 'pl_dates: From Date and To Date are mandatory';
    end if;
    v_range_start := (p_filters ->> 'period_start_date')::date;
    v_range_end := (p_filters ->> 'period_end_date')::date;
    if v_range_end < v_range_start then
      raise exception using errcode = 'P0001', message = 'pl_dates: To Date cannot be less than From Date';
    end if;
  end if;

  v_cursor := v_range_start;
  loop
    v_guard := v_guard + 1;
    if v_guard > 240 then
      raise exception using errcode = 'P0001', message = 'pl_periodicity: Periodicity must be Monthly, Quarterly, Half-Yearly, or Yearly';
    end if;
    v_from := v_cursor;
    if v_guard = 1 and v_filter = 'Date Range' then
      v_bucket := (date_trunc('month', v_cursor) + make_interval(months => v_months))::date;
    else
      v_bucket := (v_cursor + make_interval(months => v_months))::date;
    end if;
    v_cursor := v_bucket;
    v_to := v_bucket - 1;
    if v_to > v_range_end then
      v_to := v_range_end;
    end if;

    v_key := lower(v_mon[extract(month from v_to)::int]) || '_' || to_char(v_to, 'YYYY');
    if v_periodicity = 'Monthly' and not v_accumulated then
      v_label := v_mon[extract(month from v_to)::int] || ' ' || to_char(v_to, 'YYYY');
    elsif v_periodicity = 'Yearly' and not v_accumulated then
      if extract(year from v_from) = extract(year from v_to) then
        v_label := to_char(v_from, 'YYYY');
      else
        v_label := to_char(v_from, 'YYYY') || '-' || to_char(v_to, 'YYYY');
      end if;
    else
      v_label_from := v_from;
      if v_accumulated then
        select fy.year_start_date into v_label_from
          from public.fiscal_year fy
         where fy.org_id = v_org
           and v_from between fy.year_start_date and fy.year_end_date
         order by fy.year_start_date
         limit 1;
        v_label_from := coalesce(v_label_from, v_from);
      end if;
      if v_periodicity = 'Yearly' then
        if extract(year from v_label_from) = extract(year from v_to) then
          v_label := to_char(v_label_from, 'YYYY');
        else
          v_label := to_char(v_label_from, 'YYYY') || '-' || to_char(v_to, 'YYYY');
        end if;
      else
        v_label := v_mon[extract(month from v_label_from)::int] || ' ' || to_char(v_label_from, 'YY')
                || '-' || v_mon[extract(month from v_to)::int] || ' ' || to_char(v_to, 'YY');
      end if;
    end if;

    v_periods := v_periods || jsonb_build_array(jsonb_build_object(
      'key', v_key,
      'label', v_label,
      'from_date', v_from,
      'to_date', v_to
    ));
    exit when v_to = v_range_end;
  end loop;

  v_total_col := v_periodicity <> 'Yearly' and not v_accumulated;

  with periods as (
    select t.ord, t.value ->> 'key' as key, (t.value ->> 'from_date')::date as from_date, (t.value ->> 'to_date')::date as to_date
      from jsonb_array_elements(v_periods) with ordinality as t(value, ord)
  ),
  accounts as (
    select a.id, a.parent_id, a.path, a.is_group, a.root_type,
           case
             when nullif(a.account_number, '') is not null then a.account_number || ' - ' || a.account_name
             else a.account_name
           end as label,
           extensions.nlevel(a.path) - 1 as indent
      from public.account a
     where a.company_id = v_company
       and a.root_type in ('Income', 'Expense')
  ),
  raw as (
    select a.id, p.key, p.ord, coalesce(sum(g.debit - g.credit), 0) as amount
      from accounts a
      cross join periods p
      left join public.gl_entry g
        on g.account_id = a.id
       and g.company_id = v_company
       and not g.is_cancelled
       and g.posting_date >= v_range_start
       and g.posting_date <= v_range_end
       and (
         (v_accumulated and g.posting_date <= p.to_date)
         or (not v_accumulated and g.posting_date between p.from_date and p.to_date)
       )
     group by a.id, p.key, p.ord
  ),
  rolled as (
    select parent.id, raw.key, raw.ord, sum(raw.amount) as amount
      from accounts parent
      join accounts child
        on child.path operator(extensions.<@) parent.path
       and child.root_type = parent.root_type
      join raw on raw.id = child.id
     group by parent.id, raw.key, raw.ord
  ),
  signed as (
    select r.id, r.key, r.ord,
           case when a.root_type = 'Income' then -r.amount else r.amount end as amount
      from rolled r
      join accounts a on a.id = r.id
  ),
  valued as (
    select distinct s.id
      from signed s
     where abs(s.amount) >= 0.005
  ),
  kept as (
    select a.*
      from accounts a
     where v_zeros
        or exists (
          select 1
            from valued v
            join accounts d on d.id = v.id
           where d.root_type = a.root_type
             and d.path operator(extensions.<@) a.path
        )
  ),
  account_json as (
    select k.root_type,
           k.path,
           jsonb_build_object(
             'row_type', 'account',
             'account_id', k.id,
             'account', k.label,
             'indent', k.indent,
             'is_group', k.is_group
           ) || coalesce((
             select jsonb_object_agg(s.key, app.round(s.amount, 2))
               from signed s
              where s.id = k.id
           ), '{}'::jsonb)
           || case
                when v_total_col then jsonb_build_object(
                  'total', app.round(coalesce((select sum(s.amount) from signed s where s.id = k.id), 0), 2)
                )
                else '{}'::jsonb
              end as row
      from kept k
  ),
  roots as (
    select k.root_type, s.key, s.ord, sum(s.amount) as amount
      from kept k
      join signed s on s.id = k.id
     where k.parent_id is null
     group by k.root_type, s.key, s.ord
  )
  select coalesce((select jsonb_agg(j.row order by j.path) from account_json j where j.root_type = 'Income'), '[]'::jsonb),
         coalesce((select jsonb_agg(j.row order by j.path) from account_json j where j.root_type = 'Expense'), '[]'::jsonb),
         coalesce((
           select jsonb_object_agg(t.root_type, t.amounts)
             from (
               select r.root_type, jsonb_object_agg(r.key, r.amount) as amounts
                 from roots r
                group by r.root_type
             ) t
         ), '{}'::jsonb)
    into v_income_rows, v_expense_rows, v_income_amounts;

  v_has_income := jsonb_array_length(v_income_rows) > 0;
  v_has_expense := jsonb_array_length(v_expense_rows) > 0;
  v_expense_amounts := coalesce(v_income_amounts -> 'Expense', '{}'::jsonb);
  v_income_amounts := coalesce(v_income_amounts -> 'Income', '{}'::jsonb);

  v_columns := jsonb_build_array(jsonb_build_object('field', 'account', 'label', 'Account'));
  v_income_total := jsonb_build_object('row_type', 'total', 'account', '''Total Income (Credit)''');
  v_expense_total := jsonb_build_object('row_type', 'total', 'account', '''Total Expense (Debit)''');
  v_profit_row := jsonb_build_object('row_type', 'total', 'account', '''Profit for the year''', 'warn_if_negative', true);

  for v_period in
    select value from jsonb_array_elements(v_periods)
  loop
    v_key := v_period ->> 'key';
    v_inc := coalesce((v_income_amounts ->> v_key)::numeric, 0);
    v_exp := coalesce((v_expense_amounts ->> v_key)::numeric, 0);
    v_profit := v_inc - v_exp;
    v_income_sum := v_income_sum + v_inc;
    v_expense_sum := v_expense_sum + v_exp;
    v_profit_sum := v_profit_sum + v_profit;
    v_last_income := v_inc;
    v_last_expense := v_exp;
    v_last_profit := v_profit;
    if abs(v_profit) >= 0.005 then
      v_has_profit := true;
    end if;
    v_columns := v_columns || jsonb_build_array(jsonb_build_object(
      'field', v_key,
      'label', v_period ->> 'label',
      'amount', true,
      'to_date', v_period ->> 'to_date'
    ));
    v_income_total := v_income_total || jsonb_build_object(v_key, app.round(v_inc, 2));
    v_expense_total := v_expense_total || jsonb_build_object(v_key, app.round(v_exp, 2));
    v_profit_row := v_profit_row || jsonb_build_object(v_key, app.round(v_profit, 2));
    v_chart_labels := v_chart_labels || jsonb_build_array(v_period ->> 'label');
    v_chart_income := v_chart_income || jsonb_build_array(app.round(v_inc, 2));
    v_chart_expense := v_chart_expense || jsonb_build_array(app.round(v_exp, 2));
    v_chart_profit := v_chart_profit || jsonb_build_array(app.round(v_profit, 2));
  end loop;

  if v_total_col then
    v_columns := v_columns || jsonb_build_array(jsonb_build_object('field', 'total', 'label', 'Total', 'amount', true));
    v_income_total := v_income_total || jsonb_build_object('total', app.round(v_income_sum, 2));
    v_expense_total := v_expense_total || jsonb_build_object('total', app.round(v_expense_sum, 2));
    v_profit_row := v_profit_row || jsonb_build_object('total', app.round(v_profit_sum, 2));
  end if;

  if v_has_income then
    v_rows := v_rows || v_income_rows || jsonb_build_array(v_income_total, jsonb_build_object('row_type', 'blank', 'account', ''));
  end if;
  if v_has_expense then
    v_rows := v_rows || v_expense_rows || jsonb_build_array(v_expense_total, jsonb_build_object('row_type', 'blank', 'account', ''));
  end if;
  if v_has_profit then
    v_rows := v_rows || jsonb_build_array(v_profit_row);
  end if;

  if v_accumulated then
    v_summary_income := v_last_income;
    v_summary_expense := v_last_expense;
    v_summary_profit := v_last_profit;
  else
    v_summary_income := v_income_sum;
    v_summary_expense := v_expense_sum;
    v_summary_profit := v_profit_sum;
  end if;

  if jsonb_array_length(v_periods) = 1 and v_periodicity = 'Yearly' then
    v_income_label := 'Total Income This Year';
    v_expense_label := 'Total Expense This Year';
    v_profit_label := 'Profit This Year';
  else
    v_income_label := 'Total Income';
    v_expense_label := 'Total Expense';
    v_profit_label := 'Net Profit';
  end if;

  if v_has_income then
    v_datasets := v_datasets || jsonb_build_array(jsonb_build_object('name', 'Income', 'values', v_chart_income));
  end if;
  if v_has_expense then
    v_datasets := v_datasets || jsonb_build_array(jsonb_build_object('name', 'Expense', 'values', v_chart_expense));
  end if;
  if v_has_profit then
    v_datasets := v_datasets || jsonb_build_array(jsonb_build_object('name', 'Net Profit/Loss', 'values', v_chart_profit));
  end if;

  return jsonb_build_object(
    'columns', v_columns,
    'rows', v_rows,
    'summary', jsonb_build_array(
      jsonb_build_object('label', v_income_label, 'value', app.round(v_summary_income, 2)),
      jsonb_build_object('label', v_expense_label, 'value', app.round(v_summary_expense, 2)),
      jsonb_build_object('label', v_profit_label, 'value', app.round(v_summary_profit, 2))
    ),
    'chart', jsonb_build_object(
      'type', case when v_accumulated then 'line' else 'bar' end,
      'labels', v_chart_labels,
      'datasets', v_datasets
    ),
    'from_date', v_range_start,
    'to_date', v_range_end
  );
end;
$$;

create or replace function public.report_profit_and_loss(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_profit_and_loss(p_filters);
$$;

revoke execute on function app.report_profit_and_loss(jsonb) from public, anon;
grant execute on function app.report_profit_and_loss(jsonb) to authenticated;
revoke execute on function public.report_profit_and_loss(jsonb) from public, anon;
grant execute on function public.report_profit_and_loss(jsonb) to authenticated;
