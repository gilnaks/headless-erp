-- Stock Ledger report.
-- ERPNext: erpnext/stock/report/stock_ledger/stock_ledger.py
-- and erpnext/stock/report/stock_ledger/stock_ledger.js.
-- One row per non-cancelled stock ledger entry in the date range.
-- There is no opening row. Qty is actual_qty.

create or replace function app.report_stock_ledger(p_filters jsonb)
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
  v_item uuid;
  v_warehouse uuid;
  v_path extensions.ltree;
  v_voucher_type text;
  v_columns jsonb;
  v_rows jsonb := '[]'::jsonb;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'sle_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'sle_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null then
    raise exception using errcode = 'P0001', message = 'sle_dates: From Date and To Date are mandatory';
  end if;
  v_from := (p_filters ->> 'from_date')::date;
  v_to := (p_filters ->> 'to_date')::date;
  if v_from > v_to then
    raise exception using errcode = 'P0001', message = 'sle_dates: From Date must be before To Date';
  end if;

  if nullif(p_filters ->> 'item', '') is not null
     and (p_filters ->> 'item') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_item := (p_filters ->> 'item')::uuid;
  end if;
  if nullif(p_filters ->> 'warehouse', '') is not null
     and (p_filters ->> 'warehouse') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_warehouse := (p_filters ->> 'warehouse')::uuid;
  end if;
  v_voucher_type := nullif(btrim(p_filters ->> 'voucher_type'), '');

  v_columns := jsonb_build_array(
    jsonb_build_object('field', 'posting_date', 'label', 'Date'),
    jsonb_build_object('field', 'item', 'label', 'Item'),
    jsonb_build_object('field', 'item_group', 'label', 'Item Group'),
    jsonb_build_object('field', 'warehouse', 'label', 'Warehouse'),
    jsonb_build_object('field', 'voucher_type', 'label', 'Voucher Type'),
    jsonb_build_object('field', 'voucher', 'label', 'Voucher'),
    jsonb_build_object('field', 'qty', 'label', 'Qty'),
    jsonb_build_object('field', 'incoming_rate', 'label', 'Incoming Rate', 'amount', true),
    jsonb_build_object('field', 'balance_qty', 'label', 'Balance Qty'),
    jsonb_build_object('field', 'valuation_rate', 'label', 'Valuation Rate', 'amount', true),
    jsonb_build_object('field', 'stock_value', 'label', 'Stock Value', 'amount', true),
    jsonb_build_object('field', 'stock_value_difference', 'label', 'Value Difference', 'amount', true)
  );

  if v_warehouse is not null then
    select w.path into v_path
      from public.warehouse w
     where w.id = v_warehouse
       and w.org_id = v_org;
    if v_path is null then
      return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
    end if;
  end if;

  select coalesce(jsonb_agg(src.body order by src.posting_datetime, src.creation_order), '[]'::jsonb)
    into v_rows
    from (
      select s.posting_datetime,
             s.creation_order,
             jsonb_build_object(
               'row_type', 'entry',
               'posting_date', s.posting_date,
               'item', i.item_code,
               'item_group', g.item_group_name,
               'warehouse', w.name,
               'voucher_type', s.voucher_type,
               'voucher', s.voucher_no,
               'qty', s.actual_qty,
               'incoming_rate', s.incoming_rate,
               'balance_qty', s.qty_after_transaction,
               'valuation_rate', s.valuation_rate,
               'stock_value', s.stock_value,
               'stock_value_difference', s.stock_value_difference
             ) as body
        from public.stock_ledger_entry s
        join public.item i on i.id = s.item_id and i.org_id = s.org_id
        join public.item_group g on g.id = i.item_group_id and g.org_id = i.org_id
        join public.warehouse w on w.id = s.warehouse_id and w.org_id = s.org_id
       where s.org_id = v_org
         and s.company_id = v_company
         and not s.is_cancelled
         and s.posting_date between v_from and v_to
         and (v_item is null or s.item_id = v_item)
         and (v_path is null or w.path operator(extensions.<@) v_path)
         and (v_voucher_type is null or s.voucher_type = v_voucher_type)
    ) src;

  return jsonb_build_object('columns', v_columns, 'rows', v_rows);
end;
$$;

create or replace function public.report_stock_ledger(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_stock_ledger(p_filters);
$$;

revoke execute on function app.report_stock_ledger(jsonb) from public, anon;
grant execute on function app.report_stock_ledger(jsonb) to authenticated;
revoke execute on function public.report_stock_ledger(jsonb) from public, anon;
grant execute on function public.report_stock_ledger(jsonb) to authenticated;
