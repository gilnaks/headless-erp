-- Default indirect Cash Flow statement.
-- Ports execute(), get_cash_flow_accounts(), get_account_type_based_gl_data(),
-- and show_opening_and_closing_balance() in
-- erpnext/accounts/report/cash_flow/cash_flow.py,
-- and get_net_profit_loss() in profit_and_loss_statement.py.
-- Cost center, project, finance books, presentation currency, dimensions, and
-- report templates wait. There is no Period Closing Voucher.

create or replace function app.report_cash_flow(p_filters jsonb)
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
  v_opening boolean;
  v_ignore boolean := false;
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
  v_income jsonb := '{}'::jsonb;
  v_expense jsonb := '{}'::jsonb;
  v_depreciation jsonb := '{}'::jsonb;
  v_receivable jsonb := '{}'::jsonb;
  v_payable jsonb := '{}'::jsonb;
  v_stock jsonb := '{}'::jsonb;
  v_fixed jsonb := '{}'::jsonb;
  v_equity jsonb := '{}'::jsonb;
  v_period jsonb;
  v_profit numeric;
  v_dep numeric;
  v_recv numeric;
  v_pay numeric;
  v_inv numeric;
  v_asset numeric;
  v_eq numeric;
  v_ops numeric;
  v_invest numeric;
  v_finance numeric;
  v_net numeric;
  v_has_profit boolean := false;
  v_profit_sum numeric := 0;
  v_dep_sum numeric := 0;
  v_recv_sum numeric := 0;
  v_pay_sum numeric := 0;
  v_inv_sum numeric := 0;
  v_asset_sum numeric := 0;
  v_eq_sum numeric := 0;
  v_ops_sum numeric := 0;
  v_invest_sum numeric := 0;
  v_finance_sum numeric := 0;
  v_net_sum numeric := 0;
  v_last_ops numeric := 0;
  v_last_invest numeric := 0;
  v_last_finance numeric := 0;
  v_last_net numeric := 0;
  v_columns jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_blank jsonb := jsonb_build_object('row_type', 'blank', 'section', '');
  v_profit_row jsonb;
  v_dep_row jsonb;
  v_recv_row jsonb;
  v_pay_row jsonb;
  v_inv_row jsonb;
  v_asset_row jsonb;
  v_eq_row jsonb;
  v_ops_row jsonb;
  v_invest_row jsonb;
  v_finance_row jsonb;
  v_net_row jsonb;
  v_open_amount numeric := 0;
  v_running numeric := 0;
  v_open_cell numeric;
  v_close_cell numeric;
  v_open_row jsonb;
  v_close_row jsonb;
  v_chart_labels jsonb := '[]'::jsonb;
  v_chart_ops jsonb := '[]'::jsonb;
  v_chart_invest jsonb := '[]'::jsonb;
  v_chart_finance jsonb := '[]'::jsonb;
  v_summary_ops numeric;
  v_summary_invest numeric;
  v_summary_finance numeric;
  v_summary_net numeric;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'cf_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'cf_company: Company is mandatory';
  end if;

  v_filter := coalesce(nullif(p_filters ->> 'filter_based_on', ''), 'Fiscal Year');
  if v_filter not in ('Fiscal Year', 'Date Range') then
    raise exception using errcode = 'P0001', message = 'cf_filter: Filter Based On must be Fiscal Year or Date Range';
  end if;

  v_periodicity := coalesce(nullif(p_filters ->> 'periodicity', ''), 'Yearly');
  if v_periodicity not in ('Monthly', 'Quarterly', 'Half-Yearly', 'Yearly') then
    raise exception using errcode = 'P0001',
      message = 'cf_periodicity: Periodicity must be Monthly, Quarterly, Half-Yearly, or Yearly';
  end if;

  v_accumulated := coalesce(nullif(p_filters ->> 'accumulated_values', '')::boolean, true);
  v_opening := coalesce(nullif(p_filters ->> 'show_opening_and_closing_balance', '')::boolean, false);
  v_months := case v_periodicity when 'Yearly' then 12 when 'Half-Yearly' then 6 when 'Quarterly' then 3 else 1 end;

  select s.ignore_is_opening_check_for_reporting
    into v_ignore
    from public.accounts_settings s
   where s.org_id = v_org;
  v_ignore := coalesce(v_ignore, false);

  if v_filter = 'Fiscal Year' then
    if nullif(p_filters ->> 'from_fiscal_year', '') is null
       or (p_filters ->> 'from_fiscal_year') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or nullif(p_filters ->> 'to_fiscal_year', '') is null
       or (p_filters ->> 'to_fiscal_year') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception using errcode = 'P0001', message = 'cf_fiscal_year: Start Year and End Year are mandatory';
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
      raise exception using errcode = 'P0001', message = 'cf_fiscal_year: Start Year and End Year are mandatory';
    end if;
    if v_range_end < v_range_start then
      raise exception using errcode = 'P0001', message = 'cf_fiscal_year: End Year cannot be before Start Year';
    end if;
  else
    if nullif(p_filters ->> 'period_start_date', '') is null or nullif(p_filters ->> 'period_end_date', '') is null then
      raise exception using errcode = 'P0001', message = 'cf_dates: From Date and To Date are mandatory';
    end if;
    v_range_start := (p_filters ->> 'period_start_date')::date;
    v_range_end := (p_filters ->> 'period_end_date')::date;
    if v_range_end < v_range_start then
      raise exception using errcode = 'P0001', message = 'cf_dates: To Date cannot be less than From Date';
    end if;
  end if;

  v_cursor := v_range_start;
  loop
    v_guard := v_guard + 1;
    if v_guard > 240 then
      raise exception using errcode = 'P0001', message = 'cf_periodicity: Periodicity must be Monthly, Quarterly, Half-Yearly, or Yearly';
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
    select t.ord,
           t.value ->> 'key' as key,
           (t.value ->> 'from_date')::date as from_date,
           (t.value ->> 'to_date')::date as to_date
      from jsonb_array_elements(v_periods) with ordinality as t(value, ord)
  ),
  windows as (
    select p.ord, p.key, p.from_date, p.to_date,
           coalesce((
             select fy.year_start_date
               from public.fiscal_year fy
              where fy.org_id = v_org
                and p.to_date between fy.year_start_date and fy.year_end_date
              order by fy.year_start_date
              limit 1
           ), p.from_date) as fy_start
      from periods p
  ),
  moves as (
    select w.key,
           coalesce(sum(g.credit - g.debit) filter (where a.root_type = 'Income' and not a.is_group), 0) as income,
           coalesce(sum(g.debit - g.credit) filter (where a.root_type = 'Expense' and not a.is_group), 0) as expense,
           coalesce(sum(g.credit - g.debit) filter (where a.account_type = 'Depreciation' and not a.is_group), 0) as depreciation,
           coalesce(sum(g.credit - g.debit) filter (where a.account_type = 'Receivable' and not a.is_group), 0) as receivable,
           coalesce(sum(g.credit - g.debit) filter (where a.account_type = 'Payable' and not a.is_group), 0) as payable,
           coalesce(sum(g.credit - g.debit) filter (where a.account_type = 'Stock' and not a.is_group), 0) as stock,
           coalesce(sum(g.credit - g.debit) filter (where a.account_type = 'Fixed Asset' and not a.is_group), 0) as fixed_asset,
           coalesce(sum(g.credit - g.debit) filter (where a.account_type = 'Equity' and not a.is_group), 0) as equity
      from windows w
      left join public.gl_entry g
        on g.company_id = v_company
       and not g.is_cancelled
       and (v_ignore or not g.is_opening)
       and g.posting_date <= w.to_date
       and g.posting_date >= case when v_accumulated then w.fy_start else w.from_date end
      left join public.account a
        on a.id = g.account_id
       and a.company_id = v_company
     group by w.key
  )
  select coalesce(jsonb_object_agg(m.key, m.income), '{}'::jsonb),
         coalesce(jsonb_object_agg(m.key, m.expense), '{}'::jsonb),
         coalesce(jsonb_object_agg(m.key, -m.depreciation), '{}'::jsonb),
         coalesce(jsonb_object_agg(m.key, m.receivable), '{}'::jsonb),
         coalesce(jsonb_object_agg(m.key, m.payable), '{}'::jsonb),
         coalesce(jsonb_object_agg(m.key, m.stock), '{}'::jsonb),
         coalesce(jsonb_object_agg(m.key, m.fixed_asset), '{}'::jsonb),
         coalesce(jsonb_object_agg(m.key, m.equity), '{}'::jsonb)
    into v_income, v_expense, v_depreciation, v_receivable, v_payable, v_stock, v_fixed, v_equity
    from moves m;

  for v_period in
    select value from jsonb_array_elements(v_periods)
  loop
    v_key := v_period ->> 'key';
    v_profit := coalesce((v_income ->> v_key)::numeric, 0) - coalesce((v_expense ->> v_key)::numeric, 0);
    if abs(v_profit) >= 0.005 then
      v_has_profit := true;
    end if;
    v_profit_sum := v_profit_sum + v_profit;
    v_dep_sum := v_dep_sum + coalesce((v_depreciation ->> v_key)::numeric, 0);
    v_recv_sum := v_recv_sum + coalesce((v_receivable ->> v_key)::numeric, 0);
    v_pay_sum := v_pay_sum + coalesce((v_payable ->> v_key)::numeric, 0);
    v_inv_sum := v_inv_sum + coalesce((v_stock ->> v_key)::numeric, 0);
    v_asset_sum := v_asset_sum + coalesce((v_fixed ->> v_key)::numeric, 0);
    v_eq_sum := v_eq_sum + coalesce((v_equity ->> v_key)::numeric, 0);
  end loop;

  v_columns := jsonb_build_array(jsonb_build_object('field', 'section', 'label', 'Section'));
  v_profit_row := jsonb_build_object('row_type', 'total', 'section', '''Profit for the year''', 'indent', 1, 'warn_if_negative', true);
  v_dep_row := jsonb_build_object('row_type', 'account', 'section', 'Depreciation', 'indent', 1);
  v_recv_row := jsonb_build_object('row_type', 'account', 'section', 'Net Change in Accounts Receivable', 'indent', 1);
  v_pay_row := jsonb_build_object('row_type', 'account', 'section', 'Net Change in Accounts Payable', 'indent', 1);
  v_inv_row := jsonb_build_object('row_type', 'account', 'section', 'Net Change in Inventory', 'indent', 1);
  v_asset_row := jsonb_build_object('row_type', 'account', 'section', 'Net Change in Fixed Asset', 'indent', 1);
  v_eq_row := jsonb_build_object('row_type', 'account', 'section', 'Net Change in Equity', 'indent', 1);
  v_ops_row := jsonb_build_object('row_type', 'total', 'section', '''Net Cash from Operations''');
  v_invest_row := jsonb_build_object('row_type', 'total', 'section', '''Net Cash from Investing''');
  v_finance_row := jsonb_build_object('row_type', 'total', 'section', '''Net Cash from Financing''');
  v_net_row := jsonb_build_object('row_type', 'total', 'section', '''Net Change in Cash''');

  if v_opening then
    select coalesce(sum(g.debit - g.credit), 0)
      into v_open_amount
      from public.gl_entry g
      join public.account a on a.id = g.account_id
     where g.company_id = v_company
       and a.company_id = v_company
       and not a.is_group
       and a.account_type in ('Cash', 'Bank')
       and not g.is_cancelled
       and (
         g.posting_date < v_range_start
         or (not v_ignore and g.is_opening)
       );
    v_open_amount := coalesce(v_open_amount, 0);
    v_running := v_open_amount;
    v_open_row := jsonb_build_object('row_type', 'total', 'section', 'Opening');
    v_close_row := jsonb_build_object('row_type', 'total', 'section', 'Closing (Opening + Total)');
  end if;

  for v_period in
    select value from jsonb_array_elements(v_periods)
  loop
    v_key := v_period ->> 'key';
    v_profit := coalesce((v_income ->> v_key)::numeric, 0) - coalesce((v_expense ->> v_key)::numeric, 0);
    v_dep := coalesce((v_depreciation ->> v_key)::numeric, 0);
    v_recv := coalesce((v_receivable ->> v_key)::numeric, 0);
    v_pay := coalesce((v_payable ->> v_key)::numeric, 0);
    v_inv := coalesce((v_stock ->> v_key)::numeric, 0);
    v_asset := coalesce((v_fixed ->> v_key)::numeric, 0);
    v_eq := coalesce((v_equity ->> v_key)::numeric, 0);
    v_ops := case when v_has_profit then v_profit else 0 end + v_dep + v_recv + v_pay + v_inv;
    v_invest := v_asset;
    v_finance := v_eq;
    v_net := v_ops + v_invest + v_finance;
    v_ops_sum := v_ops_sum + v_ops;
    v_invest_sum := v_invest_sum + v_invest;
    v_finance_sum := v_finance_sum + v_finance;
    v_net_sum := v_net_sum + v_net;
    v_last_ops := v_ops;
    v_last_invest := v_invest;
    v_last_finance := v_finance;
    v_last_net := v_net;

    v_columns := v_columns || jsonb_build_array(jsonb_build_object(
      'field', v_key,
      'label', v_period ->> 'label',
      'amount', true,
      'to_date', v_period ->> 'to_date'
    ));
    v_profit_row := v_profit_row || jsonb_build_object(v_key, app.round(v_profit, 2));
    v_dep_row := v_dep_row || jsonb_build_object(v_key, app.round(v_dep, 2));
    v_recv_row := v_recv_row || jsonb_build_object(v_key, app.round(v_recv, 2));
    v_pay_row := v_pay_row || jsonb_build_object(v_key, app.round(v_pay, 2));
    v_inv_row := v_inv_row || jsonb_build_object(v_key, app.round(v_inv, 2));
    v_asset_row := v_asset_row || jsonb_build_object(v_key, app.round(v_asset, 2));
    v_eq_row := v_eq_row || jsonb_build_object(v_key, app.round(v_eq, 2));
    v_ops_row := v_ops_row || jsonb_build_object(v_key, app.round(v_ops, 2));
    v_invest_row := v_invest_row || jsonb_build_object(v_key, app.round(v_invest, 2));
    v_finance_row := v_finance_row || jsonb_build_object(v_key, app.round(v_finance, 2));
    v_net_row := v_net_row || jsonb_build_object(v_key, app.round(v_net, 2));
    v_chart_labels := v_chart_labels || jsonb_build_array(v_period ->> 'label');
    v_chart_ops := v_chart_ops || jsonb_build_array(app.round(v_ops, 2));
    v_chart_invest := v_chart_invest || jsonb_build_array(app.round(v_invest, 2));
    v_chart_finance := v_chart_finance || jsonb_build_array(app.round(v_finance, 2));

    if v_opening then
      v_open_cell := v_running;
      v_running := v_running + v_net;
      v_close_cell := v_running;
      v_open_row := v_open_row || jsonb_build_object(v_key, app.round(v_open_cell, 2));
      v_close_row := v_close_row || jsonb_build_object(v_key, app.round(v_close_cell, 2));
    end if;
  end loop;

  if v_total_col then
    v_columns := v_columns || jsonb_build_array(jsonb_build_object('field', 'total', 'label', 'Total', 'amount', true));
    v_profit_row := v_profit_row || jsonb_build_object('total', app.round(v_profit_sum, 2));
    v_dep_row := v_dep_row || jsonb_build_object('total', app.round(v_dep_sum, 2));
    v_recv_row := v_recv_row || jsonb_build_object('total', app.round(v_recv_sum, 2));
    v_pay_row := v_pay_row || jsonb_build_object('total', app.round(v_pay_sum, 2));
    v_inv_row := v_inv_row || jsonb_build_object('total', app.round(v_inv_sum, 2));
    v_asset_row := v_asset_row || jsonb_build_object('total', app.round(v_asset_sum, 2));
    v_eq_row := v_eq_row || jsonb_build_object('total', app.round(v_eq_sum, 2));
    v_ops_row := v_ops_row || jsonb_build_object('total', app.round(v_ops_sum, 2));
    v_invest_row := v_invest_row || jsonb_build_object('total', app.round(v_invest_sum, 2));
    v_finance_row := v_finance_row || jsonb_build_object('total', app.round(v_finance_sum, 2));
    v_net_row := v_net_row || jsonb_build_object('total', app.round(v_net_sum, 2));
    if v_opening then
      v_open_row := v_open_row || jsonb_build_object('total', app.round(v_open_amount, 2));
      v_close_row := v_close_row || jsonb_build_object('total', app.round(v_running, 2));
    end if;
  end if;

  v_rows := v_rows || jsonb_build_array(jsonb_build_object(
    'row_type', 'section', 'section', '''Cash Flow from Operations''', 'indent', 0
  ));
  if v_has_profit then
    v_rows := v_rows || jsonb_build_array(v_profit_row);
  end if;
  v_rows := v_rows || jsonb_build_array(v_dep_row, v_recv_row, v_pay_row, v_inv_row, v_ops_row, v_blank);
  v_rows := v_rows || jsonb_build_array(jsonb_build_object(
    'row_type', 'section', 'section', '''Cash Flow from Investing''', 'indent', 0
  ));
  v_rows := v_rows || jsonb_build_array(v_asset_row, v_invest_row, v_blank);
  v_rows := v_rows || jsonb_build_array(jsonb_build_object(
    'row_type', 'section', 'section', '''Cash Flow from Financing''', 'indent', 0
  ));
  v_rows := v_rows || jsonb_build_array(v_eq_row, v_finance_row, v_blank, v_net_row);

  if v_opening then
    v_rows := v_rows || jsonb_build_array(v_open_row, v_net_row, v_close_row, v_blank);
  end if;

  if v_accumulated then
    v_summary_ops := v_last_ops;
    v_summary_invest := v_last_invest;
    v_summary_finance := v_last_finance;
    v_summary_net := v_last_net;
  else
    v_summary_ops := v_ops_sum;
    v_summary_invest := v_invest_sum;
    v_summary_finance := v_finance_sum;
    v_summary_net := v_net_sum;
  end if;

  return jsonb_build_object(
    'columns', v_columns,
    'rows', v_rows,
    'summary', jsonb_build_array(
      jsonb_build_object('label', 'Net Cash from Operations', 'value', app.round(v_summary_ops, 2)),
      jsonb_build_object('label', 'Net Cash from Investing', 'value', app.round(v_summary_invest, 2)),
      jsonb_build_object('label', 'Net Cash from Financing', 'value', app.round(v_summary_finance, 2)),
      jsonb_build_object('label', 'Net Change in Cash', 'value', app.round(v_summary_net, 2))
    ),
    'chart', jsonb_build_object(
      'type', 'bar',
      'labels', v_chart_labels,
      'datasets', jsonb_build_array(
        jsonb_build_object('name', 'Net Cash from Operations', 'values', v_chart_ops),
        jsonb_build_object('name', 'Net Cash from Investing', 'values', v_chart_invest),
        jsonb_build_object('name', 'Net Cash from Financing', 'values', v_chart_finance)
      )
    ),
    'from_date', v_range_start,
    'to_date', v_range_end
  );
end;
$$;

create or replace function public.report_cash_flow(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_cash_flow(p_filters);
$$;

revoke execute on function app.report_cash_flow(jsonb) from public, anon;
grant execute on function app.report_cash_flow(jsonb) to authenticated;
revoke execute on function public.report_cash_flow(jsonb) from public, anon;
grant execute on function public.report_cash_flow(jsonb) to authenticated;
