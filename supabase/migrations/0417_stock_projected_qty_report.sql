-- Stock Projected Qty report.
-- ERPNext: erpnext/stock/report/stock_projected_qty/stock_projected_qty.py
-- and erpnext/stock/report/stock_projected_qty/stock_projected_qty.js.
-- One row per bin. Quantities are the stored bin values. Shortage uses that
-- warehouse's reorder level when it is above projected qty.

create or replace function app.report_stock_projected_qty(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_filters jsonb := coalesce(p_filters, '{}'::jsonb);
  v_company uuid;
  v_org uuid;
  v_item uuid;
  v_warehouse uuid;
  v_path extensions.ltree;
  v_columns jsonb;
  v_rows jsonb := '[]'::jsonb;
begin
  if nullif(v_filters ->> 'company', '') is not null
     and (v_filters ->> 'company') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_company := (v_filters ->> 'company')::uuid;
  end if;
  if nullif(v_filters ->> 'item', '') is not null
     and (v_filters ->> 'item') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_item := (v_filters ->> 'item')::uuid;
  end if;
  if nullif(v_filters ->> 'warehouse', '') is not null
     and (v_filters ->> 'warehouse') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_warehouse := (v_filters ->> 'warehouse')::uuid;
  end if;

  v_columns := jsonb_build_array(
    jsonb_build_object('field', 'item', 'label', 'Item'),
    jsonb_build_object('field', 'warehouse', 'label', 'Warehouse'),
    jsonb_build_object('field', 'actual_qty', 'label', 'Actual Qty'),
    jsonb_build_object('field', 'ordered_qty', 'label', 'Ordered Qty'),
    jsonb_build_object('field', 'indented_qty', 'label', 'Requested Qty'),
    jsonb_build_object('field', 'reserved_qty', 'label', 'Reserved Qty'),
    jsonb_build_object('field', 'planned_qty', 'label', 'Planned Qty'),
    jsonb_build_object('field', 'projected_qty', 'label', 'Projected Qty'),
    jsonb_build_object('field', 'reorder_level', 'label', 'Reorder Level'),
    jsonb_build_object('field', 'shortage_qty', 'label', 'Shortage Qty')
  );

  if v_company is not null then
    select c.org_id into v_org from public.companies c where c.id = v_company;
    if v_org is null then
      return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
    end if;
  end if;

  if v_warehouse is not null then
    select w.path into v_path
      from public.warehouse w
     where w.id = v_warehouse
       and (v_company is null or w.company_id = v_company);
    if v_path is null then
      return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
    end if;
  end if;

  select coalesce(jsonb_agg(src.body order by src.item_code, src.warehouse_name), '[]'::jsonb)
    into v_rows
    from (
      select i.item_code,
             w.name as warehouse_name,
             jsonb_build_object(
               'row_type', 'entry',
               'item', i.item_code,
               'warehouse', w.name,
               'actual_qty', b.actual_qty,
               'ordered_qty', b.ordered_qty,
               'indented_qty', b.indented_qty,
               'reserved_qty', b.reserved_qty,
               'planned_qty', b.planned_qty,
               'projected_qty', b.projected_qty,
               'reorder_level', coalesce(re.warehouse_reorder_level, 0),
               'shortage_qty', case
                 when (coalesce(re.warehouse_reorder_level, 0) <> 0 or coalesce(re.warehouse_reorder_qty, 0) <> 0)
                  and coalesce(re.warehouse_reorder_level, 0) > b.projected_qty
                 then coalesce(re.warehouse_reorder_level, 0) - b.projected_qty
                 else 0
               end
             ) as body
        from public.bin b
        join public.item i on i.id = b.item_id and i.org_id = b.org_id
        join public.warehouse w on w.id = b.warehouse_id and w.org_id = b.org_id
        left join lateral (
          select r.warehouse_reorder_level, r.warehouse_reorder_qty
            from public.item_reorder r
           where r.org_id = b.org_id
             and r.parent_id = b.item_id
             and r.warehouse_id = b.warehouse_id
           order by r.idx desc
           limit 1
        ) re on true
       where i.is_stock_item
         and not i.disabled
         and i.end_of_life > current_date
         and (v_company is null or w.company_id = v_company)
         and (v_item is null or b.item_id = v_item)
         and (v_path is null or w.path operator(extensions.<@) v_path)
    ) src;

  return jsonb_build_object('columns', v_columns, 'rows', v_rows);
end;
$$;

create or replace function public.report_stock_projected_qty(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_stock_projected_qty(p_filters);
$$;

revoke execute on function app.report_stock_projected_qty(jsonb) from public, anon;
grant execute on function app.report_stock_projected_qty(jsonb) to authenticated;
revoke execute on function public.report_stock_projected_qty(jsonb) from public, anon;
grant execute on function public.report_stock_projected_qty(jsonb) to authenticated;
