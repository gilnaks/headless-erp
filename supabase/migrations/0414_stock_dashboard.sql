-- Stock dashboard cards and charts.
-- ERPNext: erpnext/stock/stock_dashboard/stock/stock.json
-- and erpnext/stock/dashboard_chart_source/warehouse_wise_stock_value/warehouse_wise_stock_value.py.
-- Purchase Receipt and Delivery Note are not tables yet, so those charts return available = false.
-- Oldest Items uses the earliest in-stock ledger date. Stock Ageing is a later report.

create or replace function app.card_stock(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_items int := 0;
  v_warehouses int := 0;
  v_value numeric := 0;
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

  select count(*)::int into v_items
    from public.item i
   where i.org_id = v_org
     and not i.disabled;

  select count(*)::int into v_warehouses
    from public.warehouse w
   where w.org_id = v_org
     and w.company_id = v_company
     and not w.disabled;

  select coalesce(sum(b.stock_value), 0) into v_value
    from public.bin b
    join public.warehouse w on w.id = b.warehouse_id and w.org_id = b.org_id
   where b.org_id = v_org
     and w.company_id = v_company
     and not w.disabled;

  return jsonb_build_object(
    'available', true,
    'active_items', v_items,
    'warehouses', v_warehouses,
    'stock_value', v_value
  );
end;
$$;

create or replace function app.chart_stock(p_chart text, p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_name text;
  v_labels jsonb := '[]'::jsonb;
  v_values jsonb := '[]'::jsonb;
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

  if p_chart in ('purchase_receipt_trends', 'delivery_trends') or p_chart is null then
    return jsonb_build_object('available', false);
  end if;

  if p_chart = 'warehouse_value' then
    v_name := 'Stock Value';
    select coalesce(jsonb_agg(src.label order by src.value desc, src.label), '[]'::jsonb),
           coalesce(jsonb_agg(src.value order by src.value desc, src.label), '[]'::jsonb)
      into v_labels, v_values
      from (
        select w.name as label, sum(b.stock_value) as value
          from public.warehouse w
          join public.bin b on b.warehouse_id = w.id and b.org_id = w.org_id
         where w.org_id = v_org
           and w.company_id = v_company
           and not w.is_group
           and not w.disabled
         group by w.id, w.name
        having sum(b.stock_value) > 0
         order by sum(b.stock_value) desc, w.name
         limit 10
      ) src;
  elsif p_chart = 'oldest_items' then
    v_name := 'Age (Days)';
    select coalesce(jsonb_agg(src.label order by src.value desc, src.label), '[]'::jsonb),
           coalesce(jsonb_agg(src.value order by src.value desc, src.label), '[]'::jsonb)
      into v_labels, v_values
      from (
        select i.item_code as label,
               (current_date - min(s.posting_date))::numeric as value
          from (
            select latest.item_id, latest.warehouse_id
              from (
                select distinct on (s.item_id, s.warehouse_id)
                       s.item_id,
                       s.warehouse_id,
                       s.qty_after_transaction
                  from public.stock_ledger_entry s
                  join public.warehouse w on w.id = s.warehouse_id and w.org_id = s.org_id
                 where s.org_id = v_org
                   and s.company_id = v_company
                   and not s.is_cancelled
                   and w.company_id = v_company
                   and not w.disabled
                 order by s.item_id, s.warehouse_id, s.posting_datetime desc, s.creation_order desc
              ) latest
             where latest.qty_after_transaction > 0
          ) instock
          join public.stock_ledger_entry s
            on s.item_id = instock.item_id
           and s.warehouse_id = instock.warehouse_id
           and s.org_id = v_org
           and not s.is_cancelled
          join public.item i on i.id = instock.item_id and i.org_id = v_org
         where not i.disabled
         group by i.id, i.item_code
         order by min(s.posting_date), i.item_code
         limit 10
      ) src;
  elsif p_chart = 'shortage' then
    v_name := 'Shortage';
    select coalesce(jsonb_agg(src.label order by src.value desc, src.label), '[]'::jsonb),
           coalesce(jsonb_agg(src.value order by src.value desc, src.label), '[]'::jsonb)
      into v_labels, v_values
      from (
        select raw.label, raw.value
          from (
            select i.item_code || ' · ' || w.warehouse_name as label,
                   greatest(
                     case
                       when i.safety_stock is not null and b.projected_qty < i.safety_stock
                         then i.safety_stock - b.projected_qty
                       else 0
                     end,
                     coalesce(levels.shortfall, 0)
                   ) as value
              from public.bin b
              join public.item i on i.id = b.item_id and i.org_id = b.org_id
              join public.warehouse w on w.id = b.warehouse_id and w.org_id = b.org_id
              left join lateral (
                select max(r.warehouse_reorder_level - b.projected_qty) as shortfall
                  from public.item_reorder r
                 where r.parent_id = i.id
                   and r.warehouse_id = b.warehouse_id
                   and b.projected_qty < r.warehouse_reorder_level
              ) levels on true
             where b.org_id = v_org
               and w.company_id = v_company
               and not w.disabled
               and not i.disabled
          ) raw
         where raw.value > 0
         order by raw.value desc, raw.label
         limit 10
      ) src;
  else
    return jsonb_build_object('available', false);
  end if;

  return jsonb_build_object(
    'available', true,
    'chart', jsonb_build_object(
      'type', 'bar',
      'labels', v_labels,
      'datasets', jsonb_build_array(jsonb_build_object('name', v_name, 'values', v_values))
    )
  );
end;
$$;

create or replace function public.card_stock(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.card_stock(p_filters);
$$;

create or replace function public.chart_stock(p_chart text, p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.chart_stock(p_chart, p_filters);
$$;

revoke execute on function app.card_stock(jsonb) from public, anon;
grant execute on function app.card_stock(jsonb) to authenticated;
revoke execute on function public.card_stock(jsonb) from public, anon;
grant execute on function public.card_stock(jsonb) to authenticated;

revoke execute on function app.chart_stock(text, jsonb) from public, anon;
grant execute on function app.chart_stock(text, jsonb) to authenticated;
revoke execute on function public.chart_stock(text, jsonb) from public, anon;
grant execute on function public.chart_stock(text, jsonb) to authenticated;
