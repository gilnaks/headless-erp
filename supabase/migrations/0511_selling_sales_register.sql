-- Sales Register.
-- ERPNext: erpnext/accounts/report/sales_register/sales_register.py
-- and erpnext/accounts/report/sales_register/sales_register.js.
-- Amounts are the company-currency grand total. This invoice has no taxes or rounding.
-- Sales order, delivery note, and warehouse are not stored on the invoice yet.
-- Dynamic income columns, the payment ledger view, mode of payment, and owner stay off.

create or replace function app.report_sales_register(p_filters jsonb)
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
  v_customer uuid;
  v_group uuid;
  v_territory uuid;
  v_item uuid;
  v_columns jsonb;
  v_rows jsonb := '[]'::jsonb;
  inv record;
  it record;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'sreg_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'sreg_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null
     or (p_filters ->> 'from_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
     or (p_filters ->> 'to_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = 'P0001', message = 'sreg_dates: From Date and To Date are mandatory';
  end if;
  begin
    v_from := (p_filters ->> 'from_date')::date;
    v_to := (p_filters ->> 'to_date')::date;
  exception
    when datetime_field_overflow or invalid_datetime_format then
      raise exception using errcode = 'P0001', message = 'sreg_dates: From Date and To Date are mandatory';
  end;
  if v_from > v_to then
    raise exception using errcode = 'P0001', message = 'sreg_dates: From Date cannot be after To Date';
  end if;

  if (p_filters ->> 'customer') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_customer := (p_filters ->> 'customer')::uuid;
  end if;
  if (p_filters ->> 'customer_group') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_group := (p_filters ->> 'customer_group')::uuid;
  end if;
  if (p_filters ->> 'territory') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_territory := (p_filters ->> 'territory')::uuid;
  end if;
  if (p_filters ->> 'item') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_item := (p_filters ->> 'item')::uuid;
  end if;

  v_columns := jsonb_build_array(
    jsonb_build_object('field', 'entity', 'label', 'Voucher'),
    jsonb_build_object('field', 'posting_date', 'label', 'Posting Date'),
    jsonb_build_object('field', 'customer', 'label', 'Customer'),
    jsonb_build_object('field', 'customer_name', 'label', 'Customer Name'),
    jsonb_build_object('field', 'customer_group', 'label', 'Customer Group'),
    jsonb_build_object('field', 'territory', 'label', 'Territory'),
    jsonb_build_object('field', 'tax_id', 'label', 'Tax Id'),
    jsonb_build_object('field', 'receivable_account', 'label', 'Receivable Account'),
    jsonb_build_object('field', 'sales_order', 'label', 'Sales Order'),
    jsonb_build_object('field', 'delivery_note', 'label', 'Delivery Note'),
    jsonb_build_object('field', 'cost_center', 'label', 'Cost Center'),
    jsonb_build_object('field', 'warehouse', 'label', 'Warehouse'),
    jsonb_build_object('field', 'currency', 'label', 'Currency'),
    jsonb_build_object('field', 'net_total', 'label', 'Net Total', 'amount', true),
    jsonb_build_object('field', 'tax_total', 'label', 'Tax Total', 'amount', true),
    jsonb_build_object('field', 'grand_total', 'label', 'Grand Total', 'amount', true),
    jsonb_build_object('field', 'rounded_total', 'label', 'Rounded Total', 'amount', true),
    jsonb_build_object('field', 'qty', 'label', 'Qty', 'amount', true),
    jsonb_build_object('field', 'rate', 'label', 'Rate', 'amount', true),
    jsonb_build_object('field', 'amount', 'label', 'Amount', 'amount', true)
  );

  for inv in
    select s.id, s.name, s.posting_date, s.customer_name, s.base_grand_total, s.conversion_rate,
           cust.name as customer_doc, cg.customer_group_name, terr.territory_name, cust.tax_id,
           acc.name as receivable, cc.name as cost_center, co.default_currency
      from public.sales_invoice s
      join public.companies co on co.id = s.company_id and co.org_id = s.org_id
      join public.customer cust on cust.id = s.customer_id and cust.org_id = s.org_id
      left join public.customer_group cg on cg.id = cust.customer_group_id and cg.org_id = cust.org_id
      left join public.territory terr on terr.id = cust.territory_id and terr.org_id = cust.org_id
      left join public.account acc on acc.id = s.debit_to_id and acc.org_id = s.org_id
      left join public.cost_center cc on cc.id = s.cost_center_id and cc.org_id = s.org_id
     where s.company_id = v_company
       and s.org_id = v_org
       and s.docstatus = 1
       and s.posting_date between v_from and v_to
       and (v_customer is null or s.customer_id = v_customer)
       and (v_item is null or exists (
         select 1 from public.sales_invoice_item i
          where i.parent_id = s.id and i.item_id = v_item
       ))
       and (v_group is null or exists (
         select 1
           from public.customer_group leaf
           join public.customer_group chosen on chosen.id = v_group and chosen.org_id = v_org
          where leaf.id = cust.customer_group_id
            and leaf.org_id = v_org
            and leaf.path operator(extensions.<@) chosen.path
       ))
       and (v_territory is null or exists (
         select 1
           from public.territory leaf
           join public.territory chosen on chosen.id = v_territory and chosen.org_id = v_org
          where leaf.id = cust.territory_id
            and leaf.org_id = v_org
            and leaf.path operator(extensions.<@) chosen.path
       ))
     order by s.posting_date, s.name
  loop
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'row_type', 'invoice',
      'indent', 0,
      'entity', inv.name,
      'posting_date', inv.posting_date,
      'customer', inv.customer_doc,
      'customer_name', inv.customer_name,
      'customer_group', inv.customer_group_name,
      'territory', inv.territory_name,
      'tax_id', inv.tax_id,
      'receivable_account', inv.receivable,
      'sales_order', '',
      'delivery_note', '',
      'cost_center', inv.cost_center,
      'warehouse', '',
      'currency', inv.default_currency,
      'net_total', inv.base_grand_total,
      'tax_total', 0,
      'grand_total', inv.base_grand_total,
      'rounded_total', inv.base_grand_total
    ));

    for it in
      select item.item_code, i.qty, i.rate, app.round(i.amount * inv.conversion_rate, 2) as base_amount
        from public.sales_invoice_item i
        join public.item item on item.id = i.item_id and item.org_id = i.org_id
       where i.parent_id = inv.id
       order by i.idx
    loop
      v_rows := v_rows || jsonb_build_array(jsonb_build_object(
        'row_type', 'entry',
        'indent', 1,
        'entity', it.item_code,
        'sales_order', '',
        'delivery_note', '',
        'warehouse', '',
        'qty', it.qty,
        'rate', it.rate,
        'amount', it.base_amount
      ));
    end loop;
  end loop;

  return jsonb_build_object('columns', v_columns, 'rows', v_rows);
end;
$$;

create or replace function public.report_sales_register(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_sales_register(p_filters);
$$;

revoke execute on function app.report_sales_register(jsonb) from public, anon;
grant execute on function app.report_sales_register(jsonb) to authenticated;
revoke execute on function public.report_sales_register(jsonb) from public, anon;
grant execute on function public.report_sales_register(jsonb) to authenticated;
