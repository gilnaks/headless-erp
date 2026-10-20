-- 0412 stock: app.get_item_details (docs/modules/04-stock.md §3.1).
-- ERPNext: erpnext/stock/get_item_details.py.
-- A read. It does not insert an Item Price. Pricing rules, POS, blanket orders, tax withholding,
-- variants, and product-bundle prefill stay out. Buying Settings are not built; the ERPNext
-- default allows last_purchase_rate on a buying document that has no price.

create or replace function app.get_item_details(p jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid := nullif(p->>'company_id', '')::uuid;
  v_item uuid := nullif(p->>'item_id', '')::uuid;
  v_barcode text := nullif(trim(p->>'barcode'), '');
  v_arg_warehouse uuid := nullif(p->>'warehouse_id', '')::uuid;
  v_qty numeric := nullif(p->>'qty', '')::numeric;
  v_uom uuid := nullif(p->>'uom_id', '')::uuid;
  v_arg_price_list uuid := nullif(p->>'price_list_id', '')::uuid;
  v_customer uuid := nullif(p->>'customer_id', '')::uuid;
  v_supplier uuid := nullif(p->>'supplier_id', '')::uuid;
  v_date date := coalesce(nullif(p->>'transaction_date', '')::date, current_date);
  v_tax_category uuid := nullif(p->>'tax_category_id', '')::uuid;
  v_net_rate numeric := nullif(p->>'net_rate', '')::numeric;
  v_doctype text := coalesce(p->>'doctype', '');
  v_buying boolean;
  v_org uuid;
  v_currency text;
  v_company_warehouse uuid;
  v_company_income uuid;
  v_company_expense uuid;
  v_company_cc uuid;
  v_item_name text;
  v_description text;
  v_stock_uom uuid;
  v_group uuid;
  v_group_path text;
  v_brand uuid;
  v_last_purchase numeric;
  v_weight numeric;
  v_has_serial boolean;
  v_has_batch boolean;
  v_item_warehouse uuid;
  v_item_price_list uuid;
  v_item_income uuid;
  v_item_expense uuid;
  v_item_buy_cc uuid;
  v_item_sell_cc uuid;
  v_group_warehouse uuid;
  v_group_income uuid;
  v_group_expense uuid;
  v_group_buy_cc uuid;
  v_group_sell_cc uuid;
  v_brand_warehouse uuid;
  v_brand_income uuid;
  v_brand_expense uuid;
  v_brand_buy_cc uuid;
  v_brand_sell_cc uuid;
  v_warehouse uuid;
  v_income uuid;
  v_expense uuid;
  v_cc uuid;
  v_price_list uuid;
  v_factor numeric;
  v_uom_name text;
  v_stock_name text;
  v_ignore_uom boolean;
  v_list_rate numeric;
  v_price_currency text;
  v_exchange numeric;
  v_rate numeric;
  v_template uuid;
  v_actual numeric;
  v_projected numeric;
  v_tax jsonb;
begin
  v_buying := lower(coalesce(p->>'transaction_type', '')) = 'buying'
    or v_doctype in (
      'Purchase Order', 'Purchase Receipt', 'Purchase Invoice',
      'Supplier Quotation', 'Request for Quotation'
    );

  if v_item is null and v_barcode is not null then
    select b.parent_id into v_item
      from public.item_barcode b
      join public.item i on i.id = b.parent_id
      join public.companies c on c.org_id = i.org_id and c.id = v_company
     where lower(b.barcode) = lower(v_barcode)
     limit 1;
    if v_item is null then
      raise exception using errcode = 'P0001', message = 'item_details: Barcode was not found';
    end if;
  end if;

  select i.org_id, i.item_name, i.description, i.stock_uom_id, i.item_group_id, g.path::text,
         i.brand_id, i.last_purchase_rate, i.weight_per_unit, i.has_serial_no, i.has_batch_no
    into v_org, v_item_name, v_description, v_stock_uom, v_group, v_group_path,
         v_brand, v_last_purchase, v_weight, v_has_serial, v_has_batch
    from public.item i
    left join public.item_group g on g.id = i.item_group_id
   where i.id = v_item;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'item_details: Item was not found';
  end if;

  select c.default_currency, c.default_warehouse_id, c.default_income_account_id,
         c.default_expense_account_id, c.cost_center_id
    into v_currency, v_company_warehouse, v_company_income, v_company_expense, v_company_cc
    from public.companies c
   where c.id = v_company and c.org_id = v_org;
  if v_currency is null then
    raise exception using errcode = 'P0001', message = 'item_details: Company was not found';
  end if;

  select d.default_warehouse_id, d.default_price_list_id, d.income_account_id, d.expense_account_id,
         d.buying_cost_center_id, d.selling_cost_center_id
    into v_item_warehouse, v_item_price_list, v_item_income, v_item_expense, v_item_buy_cc, v_item_sell_cc
    from public.item_default d
   where d.parent_id = v_item and d.company_id = v_company
   limit 1;

  select d.default_warehouse_id, d.income_account_id, d.expense_account_id,
         d.buying_cost_center_id, d.selling_cost_center_id
    into v_group_warehouse, v_group_income, v_group_expense, v_group_buy_cc, v_group_sell_cc
    from public.item_group_default d
   where d.parent_id = v_group and d.company_id = v_company
   limit 1;

  select d.default_warehouse_id, d.income_account_id, d.expense_account_id,
         d.buying_cost_center_id, d.selling_cost_center_id
    into v_brand_warehouse, v_brand_income, v_brand_expense, v_brand_buy_cc, v_brand_sell_cc
    from public.brand_default d
   where d.parent_id = v_brand and d.company_id = v_company
   limit 1;

  v_warehouse := coalesce(v_arg_warehouse, v_item_warehouse, v_group_warehouse, v_brand_warehouse, v_company_warehouse);
  v_income := coalesce(v_item_income, v_group_income, v_brand_income, v_company_income);
  v_expense := coalesce(v_item_expense, v_group_expense, v_brand_expense, v_company_expense);
  v_cc := coalesce(
    case when v_buying then v_item_buy_cc else v_item_sell_cc end,
    case when v_buying then v_group_buy_cc else v_group_sell_cc end,
    case when v_buying then v_brand_buy_cc else v_brand_sell_cc end,
    v_company_cc
  );
  v_price_list := coalesce(v_arg_price_list, v_item_price_list);

  if v_uom is null or v_uom = v_stock_uom then
    v_uom := v_stock_uom;
    v_factor := 1;
  else
    select u.conversion_factor into v_factor
      from public.item_uom u
     where u.parent_id = v_item and u.uom_id = v_uom;
    if v_factor is null then
      select uom.uom_name into v_uom_name from public.uom uom where uom.id = v_uom;
      select uom.uom_name into v_stock_name from public.uom uom where uom.id = v_stock_uom;
      select f.value into v_factor
        from public.uom_conversion_factor f
       where f.org_id = v_org
         and lower(f.from_uom) = lower(v_uom_name)
         and lower(f.to_uom) = lower(v_stock_name);
      if v_factor is null then
        select case when f.value <> 0 then 1 / f.value else null end into v_factor
          from public.uom_conversion_factor f
         where f.org_id = v_org
           and lower(f.from_uom) = lower(v_stock_name)
           and lower(f.to_uom) = lower(v_uom_name);
      end if;
    end if;
    if v_factor is null then
      raise exception using errcode = 'P0001', message = 'item_details: UOM is not on the item';
    end if;
  end if;

  if v_price_list is not null then
    select pl.price_not_uom_dependent into v_ignore_uom
      from public.price_list pl
     where pl.id = v_price_list and pl.enabled;
    if v_ignore_uom is not null then
      select ip.price_list_rate, ip.currency
        into v_list_rate, v_price_currency
        from public.item_price ip
       where ip.item_id = v_item
         and ip.price_list_id = v_price_list
         and ip.valid_from <= v_date
         and (ip.valid_upto is null or ip.valid_upto >= v_date)
         and (ip.packing_unit = 0 or ip.packing_unit <= coalesce(v_qty, 0))
         and (
           v_ignore_uom
           or ip.uom_id = v_uom
           or ip.uom_id = v_stock_uom
         )
         and (
           (not v_buying and (
             (v_customer is not null and ip.customer_id = v_customer)
             or (ip.customer_id is null and ip.supplier_id is null)
           ))
           or (v_buying and (
             (v_supplier is not null and ip.supplier_id = v_supplier)
             or (ip.customer_id is null and ip.supplier_id is null)
           ))
         )
       order by
         case
           when not v_buying and v_customer is not null and ip.customer_id = v_customer then 0
           when v_buying and v_supplier is not null and ip.supplier_id = v_supplier then 0
           else 1
         end,
         case when v_ignore_uom or ip.uom_id = v_uom then 0 else 1 end,
         ip.packing_unit desc,
         ip.valid_from desc
       limit 1;
    end if;
  end if;

  if v_list_rate is not null and v_price_currency is distinct from v_currency then
    v_exchange := app.get_exchange_rate(
      v_org, v_price_currency, v_currency, v_date,
      case when v_buying then 'buying' else 'selling' end
    );
    if coalesce(v_exchange, 0) = 0 then
      raise exception using errcode = 'P0001', message = 'item_details: Exchange rate is required';
    end if;
    v_list_rate := v_list_rate * v_exchange;
  end if;

  v_rate := v_list_rate;
  if v_rate is null and v_buying then
    v_rate := v_last_purchase;
  end if;

  select picked.item_tax_template_id into v_template
    from (
      select it.item_tax_template_id,
             case when it.tax_category_id = v_tax_category then 0 else 1 end as cat_rank,
             0 as distance,
             it.valid_from,
             0 as src
        from public.item_tax it
        join public.item_tax_template tpl
          on tpl.id = it.item_tax_template_id
         and tpl.company_id = v_company
         and tpl.disabled = false
       where it.parent_id = v_item
         and (it.valid_from is null or it.valid_from <= v_date)
         and (it.tax_category_id is null or it.tax_category_id = v_tax_category)
         and (it.minimum_net_rate is null or (v_net_rate is not null and v_net_rate >= it.minimum_net_rate))
         and (it.maximum_net_rate is null or (v_net_rate is not null and v_net_rate <= it.maximum_net_rate))
      union all
      select gt.item_tax_template_id,
             case when gt.tax_category_id = v_tax_category then 0 else 1 end,
             1000 - extensions.nlevel(g.path),
             gt.valid_from,
             1
        from public.item_group_tax gt
        join public.item_group g on g.id = gt.parent_id
        join public.item_tax_template tpl
          on tpl.id = gt.item_tax_template_id
         and tpl.company_id = v_company
         and tpl.disabled = false
       where v_group_path is not null
         and (g.path::text = v_group_path or v_group_path like g.path::text || '.%')
         and (gt.valid_from is null or gt.valid_from <= v_date)
         and (gt.tax_category_id is null or gt.tax_category_id = v_tax_category)
         and (gt.minimum_net_rate is null or (v_net_rate is not null and v_net_rate >= gt.minimum_net_rate))
         and (gt.maximum_net_rate is null or (v_net_rate is not null and v_net_rate <= gt.maximum_net_rate))
         and not exists (select 1 from public.item_tax mine where mine.parent_id = v_item)
    ) picked
   order by picked.src, picked.cat_rank, picked.distance, picked.valid_from desc nulls last
   limit 1;

  v_tax := app.get_item_tax_map(v_company, v_template, '[]'::jsonb);

  if v_warehouse is not null then
    select b.actual_qty, b.projected_qty into v_actual, v_projected
      from public.bin b
     where b.item_id = v_item and b.warehouse_id = v_warehouse;
  end if;

  return jsonb_build_object(
    'item_id', v_item,
    'item_name', v_item_name,
    'description', v_description,
    'stock_uom_id', v_stock_uom,
    'uom_id', v_uom,
    'conversion_factor', v_factor,
    'stock_qty', coalesce(v_qty, 0) * v_factor,
    'price_list_rate', v_list_rate,
    'rate', v_rate,
    'income_account_id', v_income,
    'expense_account_id', v_expense,
    'cost_center_id', v_cc,
    'warehouse_id', v_warehouse,
    'actual_qty', coalesce(v_actual, 0),
    'projected_qty', coalesce(v_projected, 0),
    'has_serial_no', coalesce(v_has_serial, false),
    'has_batch_no', coalesce(v_has_batch, false),
    'item_tax_template_id', v_template,
    'weight_per_unit', v_weight,
    'item_tax_rate', coalesce(v_tax, '{}'::jsonb)
  );
end;
$$;

create or replace function public.get_item_details(p jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.get_item_details(p);
$$;

revoke all on function app.get_item_details(jsonb) from public, anon;
grant execute on function app.get_item_details(jsonb) to authenticated;
revoke all on function public.get_item_details(jsonb) from public, anon;
grant execute on function public.get_item_details(jsonb) to authenticated;
