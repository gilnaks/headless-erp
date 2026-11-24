-- Selling dashboard cards and charts.
-- ERPNext: erpnext/selling/selling_dashboard/selling/selling.json
-- and the Annual Sales, Sales Orders to Deliver, Sales Orders to Bill,
-- and Active Customers number cards.
-- Sales Order Trends and Top Customers are Sales Analytics charts.
-- Item-wise Annual Sales reads Sales Invoices. Those three return available = false.
-- Annual Sales uses base_grand_total; the order has no base_net_total column.

create or replace function app.card_selling(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_annual numeric := 0;
  v_deliver int := 0;
  v_bill int := 0;
  v_customers int := 0;
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

  select coalesce(sum(o.base_grand_total), 0) into v_annual
    from public.sales_order o
   where o.org_id = v_org
     and o.company_id = v_company
     and o.docstatus = 1
     and o.status is distinct from 'Closed'
     and o.updated_at >= date_trunc('year', current_timestamp)
     and o.updated_at < date_trunc('year', current_timestamp) + interval '1 year';

  select count(*)::int into v_deliver
    from public.sales_order o
   where o.org_id = v_org
     and o.company_id = v_company
     and o.docstatus = 1
     and o.status in ('To Deliver and Bill', 'To Deliver');

  select count(*)::int into v_bill
    from public.sales_order o
   where o.org_id = v_org
     and o.company_id = v_company
     and o.docstatus = 1
     and o.status in ('To Deliver and Bill', 'To Bill');

  select count(*)::int into v_customers
    from public.customer c
   where c.org_id = v_org
     and not c.disabled;

  return jsonb_build_object(
    'available', true,
    'annual_sales', v_annual,
    'to_deliver', v_deliver,
    'to_bill', v_bill,
    'active_customers', v_customers
  );
end;
$$;

create or replace function app.chart_selling(p_chart text, p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_to_bill numeric := 0;
  v_billed numeric := 0;
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

  if p_chart is distinct from 'sales_order_analysis' then
    return jsonb_build_object('available', false);
  end if;

  select coalesce(sum(o.base_grand_total), 0) into v_to_bill
    from public.sales_order o
   where o.org_id = v_org
     and o.company_id = v_company
     and o.docstatus = 1
     and o.status in ('To Deliver and Bill', 'To Deliver', 'To Bill')
     and o.transaction_date <= current_date;

  select coalesce(sum(i.billed_amt), 0) into v_billed
    from public.sales_order_item i
    join public.sales_order o on o.id = i.parent_id and o.org_id = i.org_id
   where o.org_id = v_org
     and o.company_id = v_company
     and o.docstatus = 1
     and o.status in ('To Deliver and Bill', 'To Deliver', 'To Bill')
     and o.transaction_date <= current_date;

  return jsonb_build_object(
    'available', true,
    'chart', jsonb_build_object(
      'type', 'bar',
      'labels', jsonb_build_array('Amount to Bill', 'Billed Amount'),
      'datasets', jsonb_build_array(jsonb_build_object(
        'name', 'Amount',
        'values', jsonb_build_array(v_to_bill, v_billed)
      ))
    )
  );
end;
$$;

create or replace function public.card_selling(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.card_selling(p_filters);
$$;

create or replace function public.chart_selling(p_chart text, p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.chart_selling(p_chart, p_filters);
$$;

revoke execute on function app.card_selling(jsonb) from public, anon;
grant execute on function app.card_selling(jsonb) to authenticated;
revoke execute on function public.card_selling(jsonb) from public, anon;
grant execute on function public.card_selling(jsonb) to authenticated;

revoke execute on function app.chart_selling(text, jsonb) from public, anon;
grant execute on function app.chart_selling(text, jsonb) to authenticated;
revoke execute on function public.chart_selling(text, jsonb) from public, anon;
grant execute on function public.chart_selling(text, jsonb) to authenticated;
