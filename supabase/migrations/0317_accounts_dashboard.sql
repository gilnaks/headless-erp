-- Accounts dashboard cards and the bank-balance chart.
-- Ports the Accounts dashboard in
-- erpnext/accounts/accounts_dashboard/accounts/accounts.json
-- and the Payment Entry number cards. Sales Invoice, Purchase Invoice,
-- ageing, and budget variance are not tables or reports yet, so those
-- widgets return available = false.

create or replace function app.card_sum(p_doctype text, p_field text, p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_from date;
  v_to date;
  v_month_start date;
  v_month_end date;
  v_prev_start date;
  v_prev_end date;
  v_value numeric := 0;
  v_current numeric := 0;
  v_previous numeric := 0;
  v_percent numeric;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'dash_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'dash_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null then
    raise exception using errcode = 'P0001', message = 'dash_dates: From Date and To Date are mandatory';
  end if;
  v_from := (p_filters ->> 'from_date')::date;
  v_to := (p_filters ->> 'to_date')::date;
  if v_to < v_from then
    raise exception using errcode = 'P0001', message = 'dash_dates: To Date cannot be less than From Date';
  end if;

  if p_doctype is distinct from 'payment_entry'
     or p_field not in ('base_received_amount', 'base_paid_amount') then
    return jsonb_build_object('available', false);
  end if;

  v_month_start := date_trunc('month', v_to)::date;
  v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;
  v_prev_end := (v_month_start - interval '1 day')::date;
  v_prev_start := date_trunc('month', v_prev_end)::date;

  select coalesce(sum(case
           when p_field = 'base_received_amount' and pe.payment_type = 'Receive' then pe.base_received_amount
           when p_field = 'base_paid_amount' and pe.payment_type = 'Pay' then pe.base_paid_amount
           else 0
         end) filter (where pe.posting_date between v_from and v_to), 0),
         coalesce(sum(case
           when p_field = 'base_received_amount' and pe.payment_type = 'Receive' then pe.base_received_amount
           when p_field = 'base_paid_amount' and pe.payment_type = 'Pay' then pe.base_paid_amount
           else 0
         end) filter (where pe.posting_date between v_month_start and v_month_end), 0),
         coalesce(sum(case
           when p_field = 'base_received_amount' and pe.payment_type = 'Receive' then pe.base_received_amount
           when p_field = 'base_paid_amount' and pe.payment_type = 'Pay' then pe.base_paid_amount
           else 0
         end) filter (where pe.posting_date between v_prev_start and v_prev_end), 0)
    into v_value, v_current, v_previous
    from public.payment_entry pe
   where pe.company_id = v_company
     and pe.docstatus = 1;

  if v_previous <> 0 then
    v_percent := app.round((v_current - v_previous) / v_previous * 100, 2);
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'available', true,
    'value', app.round(v_value, 2),
    'current', app.round(v_current, 2),
    'previous', app.round(v_previous, 2),
    'percent', v_percent
  ));
end;
$$;

create or replace function public.card_sum(p_doctype text, p_field text, p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.card_sum(p_doctype, p_field, p_filters);
$$;

create or replace function app.chart_timeseries(
  p_doctype text,
  p_field text,
  p_date_field text,
  p_interval text,
  p_points int,
  p_filters jsonb
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_from date;
  v_to date;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'dash_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'dash_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null then
    raise exception using errcode = 'P0001', message = 'dash_dates: From Date and To Date are mandatory';
  end if;
  v_from := (p_filters ->> 'from_date')::date;
  v_to := (p_filters ->> 'to_date')::date;
  if v_to < v_from then
    raise exception using errcode = 'P0001', message = 'dash_dates: To Date cannot be less than From Date';
  end if;

  -- Sales Invoice and Purchase Invoice are not tables yet. The arguments are
  -- part of the signature the dashboard calls; no rows are invented.
  return jsonb_build_object(
    'available', false,
    'doctype', p_doctype,
    'field', p_field,
    'date_field', p_date_field,
    'interval', p_interval,
    'points', p_points
  );
end;
$$;

create or replace function public.chart_timeseries(
  p_doctype text,
  p_field text,
  p_date_field text,
  p_interval text,
  p_points int,
  p_filters jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.chart_timeseries(p_doctype, p_field, p_date_field, p_interval, p_points, p_filters);
$$;

create or replace function app.chart_account_balance_timeline(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_from date;
  v_to date;
  v_account uuid;
  v_mon text[] := array['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  v_labels jsonb := '[]'::jsonb;
  v_values jsonb := '[]'::jsonb;
  v_i int;
  v_month_start date;
  v_month_end date;
  v_balance numeric;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'dash_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id, c.default_bank_account_id
    into v_org, v_account
    from public.companies c
   where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'dash_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null then
    raise exception using errcode = 'P0001', message = 'dash_dates: From Date and To Date are mandatory';
  end if;
  v_from := (p_filters ->> 'from_date')::date;
  v_to := (p_filters ->> 'to_date')::date;
  if v_to < v_from then
    raise exception using errcode = 'P0001', message = 'dash_dates: To Date cannot be less than From Date';
  end if;

  if nullif(p_filters ->> 'account_id', '') is not null then
    if (p_filters ->> 'account_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception using errcode = 'P0001', message = 'dash_account: Account does not belong to the company';
    end if;
    v_account := (p_filters ->> 'account_id')::uuid;
  end if;

  if v_account is null then
    return jsonb_build_object('available', false);
  end if;
  if not exists (
    select 1 from public.account a where a.id = v_account and a.company_id = v_company
  ) then
    raise exception using errcode = 'P0001', message = 'dash_account: Account does not belong to the company';
  end if;

  for v_i in 0..11 loop
    v_month_start := (date_trunc('month', v_to) - ((11 - v_i) * interval '1 month'))::date;
    v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;
    select coalesce(sum(g.debit - g.credit), 0)
      into v_balance
      from public.account node
      join public.account root on root.id = v_account
      left join public.gl_entry g
        on g.account_id = node.id
       and g.company_id = v_company
       and not g.is_cancelled
       and g.posting_date <= v_month_end
     where node.company_id = v_company
       and node.path operator(extensions.<@) root.path;

    v_labels := v_labels || jsonb_build_array(v_mon[extract(month from v_month_end)::int] || ' ' || to_char(v_month_end, 'YYYY'));
    v_values := v_values || jsonb_build_array(app.round(coalesce(v_balance, 0), 2));
  end loop;

  return jsonb_build_object(
    'available', true,
    'account_id', v_account,
    'chart', jsonb_build_object(
      'type', 'line',
      'labels', v_labels,
      'datasets', jsonb_build_array(jsonb_build_object('name', 'Bank Balance', 'values', v_values))
    )
  );
end;
$$;

create or replace function public.chart_account_balance_timeline(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.chart_account_balance_timeline(p_filters);
$$;

revoke execute on function app.card_sum(text, text, jsonb) from public, anon;
grant execute on function app.card_sum(text, text, jsonb) to authenticated;
revoke execute on function public.card_sum(text, text, jsonb) from public, anon;
grant execute on function public.card_sum(text, text, jsonb) to authenticated;

revoke execute on function app.chart_timeseries(text, text, text, text, int, jsonb) from public, anon;
grant execute on function app.chart_timeseries(text, text, text, text, int, jsonb) to authenticated;
revoke execute on function public.chart_timeseries(text, text, text, text, int, jsonb) from public, anon;
grant execute on function public.chart_timeseries(text, text, text, text, int, jsonb) to authenticated;

revoke execute on function app.chart_account_balance_timeline(jsonb) from public, anon;
grant execute on function app.chart_account_balance_timeline(jsonb) to authenticated;
revoke execute on function public.chart_account_balance_timeline(jsonb) from public, anon;
grant execute on function public.chart_account_balance_timeline(jsonb) to authenticated;
