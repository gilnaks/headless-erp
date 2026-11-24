-- Sales Analytics report.
-- ERPNext: erpnext/selling/report/sales_analytics/sales_analytics.py
-- and erpnext/selling/report/sales_analytics/sales_analytics.js.
-- Value uses base_grand_total and the item amount times the conversion rate.
-- Those documents have no base_net_total. Sales Invoice and Project are not built.
-- The current ERPNext report has no Sales Person branch.

create or replace function app.report_sales_analytics(p_filters jsonb)
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
  v_tree text;
  v_doc text;
  v_value boolean;
  v_range text;
  v_sources text[];
  v_columns jsonb;
  v_periods jsonb := '[]'::jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_months text[] := array['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  v_start date;
  v_end date;
  v_label text;
  v_field text;
  v_col jsonb;
  v_ord int := 0;
  v_guard int := 0;
  v_fy_start date;
  v_fy_end date;
  v_fy_name text;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'slan_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'slan_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null
     or (p_filters ->> 'from_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
     or (p_filters ->> 'to_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = 'P0001', message = 'slan_dates: From Date and To Date are mandatory';
  end if;
  begin
    v_from := (p_filters ->> 'from_date')::date;
    v_to := (p_filters ->> 'to_date')::date;
  exception
    when datetime_field_overflow or invalid_datetime_format then
      raise exception using errcode = 'P0001', message = 'slan_dates: From Date and To Date are mandatory';
  end;
  if v_from > v_to then
    raise exception using errcode = 'P0001', message = 'slan_dates: From Date and To Date are mandatory';
  end if;

  v_tree := btrim(p_filters ->> 'tree_type');
  v_doc := btrim(p_filters ->> 'doc_type');
  if v_tree = 'Sales Person' then
    raise exception using errcode = 'P0001', message = 'slan_tree: Sales Person is not a tree on this report';
  end if;
  if v_tree = 'Project' then
    raise exception using errcode = 'P0001', message = 'slan_tree: Project is not built yet';
  end if;
  if v_tree is null or v_tree not in ('Customer Group', 'Customer', 'Item Group', 'Item', 'Territory', 'Order Type') then
    raise exception using errcode = 'P0001', message = 'slan_tree: Tree Type is invalid';
  end if;
  if v_doc in ('Sales Invoice', 'Sales Invoice (due)') then
    raise exception using errcode = 'P0001', message = 'slan_doc: Sales Invoice is not built yet';
  end if;
  if v_doc is null or v_doc not in ('All', 'Quotation', 'Sales Order', 'Delivery Note', 'Payment Entry') then
    raise exception using errcode = 'P0001', message = 'slan_doc: Based On is invalid';
  end if;
  if coalesce(btrim(p_filters ->> 'value_quantity'), '') not in ('Value', 'Quantity') then
    raise exception using errcode = 'P0001', message = 'slan_value: Value or Qty is invalid';
  end if;
  v_value := btrim(p_filters ->> 'value_quantity') = 'Value';
  v_range := btrim(p_filters ->> 'range');
  if v_range is null or v_range not in ('Weekly', 'Monthly', 'Quarterly', 'Yearly') then
    raise exception using errcode = 'P0001', message = 'slan_range: Range is invalid';
  end if;

  if v_doc = 'All' then
    v_tree := 'Customer';
    v_value := true;
  end if;
  if v_doc = 'Payment Entry' and not v_value then
    raise exception using errcode = 'P0001', message = 'slan_payment_qty: Only Value available for Payment Entry';
  end if;

  v_sources := case v_doc
    when 'All' then array['Quotation', 'Sales Order', 'Delivery Note', 'Payment Entry']
    else array[v_doc]
  end;

  v_columns := jsonb_build_array(jsonb_build_object('field', 'entity', 'label', v_tree));
  if v_tree in ('Customer', 'Item') then
    v_columns := v_columns || jsonb_build_array(jsonb_build_object(
      'field', 'entity_name',
      'label', case when v_tree = 'Item' then 'Item Name' else 'Customer Name' end
    ));
  end if;
  if v_tree = 'Item' then
    v_columns := v_columns || jsonb_build_array(jsonb_build_object('field', 'stock_uom', 'label', 'UOM'));
  end if;

  if v_range = 'Yearly' then
    select fy.year_start_date into v_start
      from public.fiscal_year fy
     where fy.org_id = v_org
       and not fy.disabled
       and fy.year_start_date <= v_from
       and fy.year_end_date >= v_from
       and (
         not exists (select 1 from public.fiscal_year_company c where c.parent_id = fy.id)
         or exists (
           select 1 from public.fiscal_year_company c
            where c.parent_id = fy.id and c.company_id = v_company
         )
       )
     order by fy.year_start_date desc
     limit 1;
    if v_start is null then
      v_start := date_trunc('year', v_from)::date;
    end if;
  elsif v_range = 'Weekly' then
    v_start := date_trunc('week', v_from)::date;
  elsif v_range = 'Quarterly' then
    v_start := date_trunc('quarter', v_from)::date;
  else
    v_start := date_trunc('month', v_from)::date;
  end if;

  while v_start <= v_to and v_guard < 60 loop
    v_guard := v_guard + 1;
    v_fy_start := null;
    v_fy_end := null;
    v_fy_name := null;
    if v_range = 'Yearly' then
      select fy.year_start_date, fy.year_end_date, fy.year
        into v_fy_start, v_fy_end, v_fy_name
        from public.fiscal_year fy
       where fy.org_id = v_org
         and not fy.disabled
         and fy.year_start_date <= v_start
         and fy.year_end_date >= v_start
         and (
           not exists (select 1 from public.fiscal_year_company c where c.parent_id = fy.id)
           or exists (
             select 1 from public.fiscal_year_company c
              where c.parent_id = fy.id and c.company_id = v_company
           )
         )
       order by fy.year_start_date desc
       limit 1;
      if v_fy_end is not null then
        v_end := v_fy_end;
        v_label := v_fy_name;
      else
        v_end := (date_trunc('year', v_start) + interval '1 year' - interval '1 day')::date;
        v_label := extract(year from v_start)::int::text;
      end if;
    elsif v_range = 'Weekly' then
      v_end := v_start + 6;
      v_label := 'Week ' || extract(week from v_end)::int || ' ' || extract(isoyear from v_end)::int;
    elsif v_range = 'Quarterly' then
      v_end := (v_start + interval '3 months' - interval '1 day')::date;
      v_label := 'Quarter ' || (((extract(month from v_end)::int - 1) / 3) + 1) || ' ' || extract(year from v_end)::int;
    else
      v_end := (v_start + interval '1 month' - interval '1 day')::date;
      v_label := v_months[extract(month from v_end)::int] || ' ' || extract(year from v_end)::int;
    end if;
    if v_end > v_to then
      v_end := v_to;
    end if;

    v_ord := v_ord + 1;
    v_field := lower(regexp_replace(v_label, '[^a-zA-Z0-9]+', '_', 'g'));
    if v_range = 'Yearly' then
      v_field := 'fy_' || v_field;
    end if;
    v_periods := v_periods || jsonb_build_array(jsonb_build_object(
      'field', v_field,
      'start_date', v_start,
      'end_date', v_end,
      'ord', v_ord
    ));
    v_col := jsonb_build_object('field', v_field, 'label', v_label);
    if v_value then
      v_col := v_col || jsonb_build_object('amount', true);
    end if;
    v_columns := v_columns || jsonb_build_array(v_col);

    exit when v_end >= v_to;
    v_start := v_end + 1;
  end loop;

  v_col := jsonb_build_object('field', 'total', 'label', 'Total');
  if v_value then
    v_col := v_col || jsonb_build_object('amount', true);
  end if;
  v_columns := v_columns || jsonb_build_array(v_col);

  if v_doc = 'Payment Entry' and v_tree <> 'Customer' then
    return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
  end if;
  if v_tree = 'Order Type' and v_doc not in ('Quotation', 'Sales Order') then
    return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
  end if;

  with periods as (
    select p.field, p.start_date, p.end_date, p.ord
      from jsonb_to_recordset(v_periods) as p(field text, start_date date, end_date date, ord int)
  ),
  facts as (
    select 'Quotation'::text as source,
           case when v_tree = 'Order Type' then q.order_type else c.name end as entity,
           case when v_tree = 'Customer' then q.customer_name else null::text end as entity_name,
           null::text as stock_uom,
           c.customer_group_id,
           c.territory_id,
           null::uuid as item_group_id,
           q.transaction_date as doc_date,
           q.base_grand_total as measure
      from public.quotation q
      join public.customer c on c.id = q.customer_id and c.org_id = q.org_id
     where q.org_id = v_org
       and q.company_id = v_company
       and q.docstatus = 1
       and q.transaction_date between v_from and v_to
       and 'Quotation' = any (v_sources)
       and v_value
       and v_tree in ('Customer', 'Customer Group', 'Territory', 'Order Type')
       and (v_tree <> 'Order Type' or v_doc in ('Quotation', 'Sales Order'))
    union all
    select 'Sales Order'::text,
           case when v_tree = 'Order Type' then o.order_type else c.name end,
           case when v_tree = 'Customer' then o.customer_name else null::text end,
           null::text,
           c.customer_group_id,
           c.territory_id,
           null::uuid,
           o.transaction_date,
           o.base_grand_total
      from public.sales_order o
      join public.customer c on c.id = o.customer_id and c.org_id = o.org_id
     where o.org_id = v_org
       and o.company_id = v_company
       and o.docstatus = 1
       and o.transaction_date between v_from and v_to
       and 'Sales Order' = any (v_sources)
       and v_value
       and v_tree in ('Customer', 'Customer Group', 'Territory', 'Order Type')
       and (v_tree <> 'Order Type' or v_doc in ('Quotation', 'Sales Order'))
    union all
    select 'Delivery Note'::text,
           c.name,
           case when v_tree = 'Customer' then n.customer_name else null::text end,
           null::text,
           c.customer_group_id,
           c.territory_id,
           null::uuid,
           n.posting_date,
           n.base_grand_total
      from public.delivery_note n
      join public.customer c on c.id = n.customer_id and c.org_id = n.org_id
     where n.org_id = v_org
       and n.company_id = v_company
       and n.docstatus = 1
       and n.posting_date between v_from and v_to
       and 'Delivery Note' = any (v_sources)
       and v_value
       and v_tree in ('Customer', 'Customer Group', 'Territory')
    union all
    select 'Payment Entry'::text,
           c.name,
           c.customer_name,
           null::text,
           c.customer_group_id,
           c.territory_id,
           null::uuid,
           pe.posting_date,
           pe.base_received_amount
      from public.payment_entry pe
      join public.customer c on c.id = pe.party_id and c.org_id = pe.org_id
     where pe.org_id = v_org
       and pe.company_id = v_company
       and pe.docstatus = 1
       and pe.is_opening = 'No'
       and pe.party_type = 'Customer'
       and pe.posting_date between v_from and v_to
       and 'Payment Entry' = any (v_sources)
       and v_value
       and v_tree = 'Customer'
    union all
    select 'Quotation'::text,
           case
             when v_tree in ('Item', 'Item Group') then it.item_code
             when v_tree = 'Order Type' then q.order_type
             else c.name
           end,
           case
             when v_tree in ('Item', 'Item Group') then it.item_name
             when v_tree = 'Customer' then q.customer_name
             else null::text
           end,
           case when v_tree = 'Item' then u.uom_name else null::text end,
           c.customer_group_id,
           c.territory_id,
           it.item_group_id,
           q.transaction_date,
           case when v_value then i.amount * q.conversion_rate else i.stock_qty end
      from public.quotation_item i
      join public.quotation q on q.id = i.parent_id and q.org_id = i.org_id
      join public.customer c on c.id = q.customer_id and c.org_id = q.org_id
      join public.item it on it.id = i.item_id and it.org_id = i.org_id
      join public.uom u on u.id = it.stock_uom_id and u.org_id = it.org_id
     where q.org_id = v_org
       and q.company_id = v_company
       and q.docstatus = 1
       and q.transaction_date between v_from and v_to
       and 'Quotation' = any (v_sources)
       and (
         (not v_value and v_tree in ('Customer', 'Customer Group', 'Territory', 'Order Type'))
         or v_tree in ('Item', 'Item Group')
       )
       and (v_tree <> 'Order Type' or v_doc in ('Quotation', 'Sales Order'))
    union all
    select 'Sales Order'::text,
           case
             when v_tree in ('Item', 'Item Group') then it.item_code
             when v_tree = 'Order Type' then o.order_type
             else c.name
           end,
           case
             when v_tree in ('Item', 'Item Group') then it.item_name
             when v_tree = 'Customer' then o.customer_name
             else null::text
           end,
           case when v_tree = 'Item' then u.uom_name else null::text end,
           c.customer_group_id,
           c.territory_id,
           it.item_group_id,
           o.transaction_date,
           case when v_value then i.amount * o.conversion_rate else i.stock_qty end
      from public.sales_order_item i
      join public.sales_order o on o.id = i.parent_id and o.org_id = i.org_id
      join public.customer c on c.id = o.customer_id and c.org_id = o.org_id
      join public.item it on it.id = i.item_id and it.org_id = i.org_id
      join public.uom u on u.id = it.stock_uom_id and u.org_id = it.org_id
     where o.org_id = v_org
       and o.company_id = v_company
       and o.docstatus = 1
       and o.transaction_date between v_from and v_to
       and 'Sales Order' = any (v_sources)
       and (
         (not v_value and v_tree in ('Customer', 'Customer Group', 'Territory', 'Order Type'))
         or v_tree in ('Item', 'Item Group')
       )
       and (v_tree <> 'Order Type' or v_doc in ('Quotation', 'Sales Order'))
    union all
    select 'Delivery Note'::text,
           case when v_tree in ('Item', 'Item Group') then it.item_code else c.name end,
           case
             when v_tree in ('Item', 'Item Group') then it.item_name
             when v_tree = 'Customer' then n.customer_name
             else null::text
           end,
           case when v_tree = 'Item' then u.uom_name else null::text end,
           c.customer_group_id,
           c.territory_id,
           it.item_group_id,
           n.posting_date,
           case when v_value then i.amount * n.conversion_rate else i.stock_qty end
      from public.delivery_note_item i
      join public.delivery_note n on n.id = i.parent_id and n.org_id = i.org_id
      join public.customer c on c.id = n.customer_id and c.org_id = n.org_id
      join public.item it on it.id = i.item_id and it.org_id = i.org_id
      join public.uom u on u.id = it.stock_uom_id and u.org_id = it.org_id
     where n.org_id = v_org
       and n.company_id = v_company
       and n.docstatus = 1
       and n.posting_date between v_from and v_to
       and 'Delivery Note' = any (v_sources)
       and (
         (not v_value and v_tree in ('Customer', 'Customer Group', 'Territory'))
         or v_tree in ('Item', 'Item Group')
       )
  ),
  flat_keys as (
    select f.source,
           f.entity,
           max(f.entity_name) as entity_name,
           max(f.stock_uom) as stock_uom
      from facts f
      join periods pr on f.doc_date >= pr.start_date and f.doc_date <= pr.end_date
     where v_tree in ('Customer', 'Item', 'Order Type')
     group by f.source, f.entity
    having sum(f.measure) <> 0
  ),
  flat_rows as (
    select k.source,
           k.entity,
           k.entity_name,
           k.stock_uom,
           0 as indent,
           k.entity as sort_key,
           pr.field,
           pr.ord,
           coalesce(sum(f.measure), 0) as amount
      from flat_keys k
      join periods pr on true
      left join facts f
        on f.source = k.source
       and f.entity = k.entity
       and f.doc_date >= pr.start_date
       and f.doc_date <= pr.end_date
     group by k.source, k.entity, k.entity_name, k.stock_uom, pr.field, pr.ord
  ),
  cg_active as (
    select s.customer_group_id
      from (
        select f.customer_group_id, pr.field, sum(f.measure) as measure
          from facts f
          join periods pr on f.doc_date >= pr.start_date and f.doc_date <= pr.end_date
         where v_tree = 'Customer Group'
           and f.customer_group_id is not null
         group by f.customer_group_id, pr.field
      ) s
     group by s.customer_group_id
    having bool_or(s.measure <> 0)
  ),
  cg_links as (
    select leaf.id as leaf_id, anc.id as anc_id
      from cg_active a
      join public.customer_group leaf on leaf.id = a.customer_group_id
      join public.customer_group anc
        on leaf.path operator(extensions.<@) anc.path
       and anc.org_id = leaf.org_id
  ),
  terr_active as (
    select s.territory_id
      from (
        select f.territory_id, pr.field, sum(f.measure) as measure
          from facts f
          join periods pr on f.doc_date >= pr.start_date and f.doc_date <= pr.end_date
         where v_tree = 'Territory'
           and f.territory_id is not null
         group by f.territory_id, pr.field
      ) s
     group by s.territory_id
    having bool_or(s.measure <> 0)
  ),
  terr_links as (
    select leaf.id as leaf_id, anc.id as anc_id
      from terr_active a
      join public.territory leaf on leaf.id = a.territory_id
      join public.territory anc
        on leaf.path operator(extensions.<@) anc.path
       and anc.org_id = leaf.org_id
  ),
  ig_active as (
    select s.item_group_id
      from (
        select f.item_group_id, pr.field, sum(f.measure) as measure
          from facts f
          join periods pr on f.doc_date >= pr.start_date and f.doc_date <= pr.end_date
         where v_tree = 'Item Group'
           and f.item_group_id is not null
         group by f.item_group_id, pr.field
      ) s
     group by s.item_group_id
    having bool_or(s.measure <> 0)
  ),
  ig_links as (
    select leaf.id as leaf_id, anc.id as anc_id
      from ig_active a
      join public.item_group leaf on leaf.id = a.item_group_id
      join public.item_group anc
        on leaf.path operator(extensions.<@) anc.path
       and anc.org_id = leaf.org_id
  ),
  group_rows as (
    select g.customer_group_name as entity,
           extensions.nlevel(g.path) - 1 as indent,
           g.path::text as sort_key,
           pr.field,
           pr.ord,
           coalesce(sum(f.measure), 0) as amount
      from public.customer_group g
      join cg_links links on links.anc_id = g.id
      join periods pr on true
      left join facts f
        on f.customer_group_id = links.leaf_id
       and f.doc_date >= pr.start_date
       and f.doc_date <= pr.end_date
     where v_tree = 'Customer Group'
       and g.org_id = v_org
     group by g.customer_group_name, g.path, pr.field, pr.ord
    union all
    select t.territory_name,
           extensions.nlevel(t.path) - 1,
           t.path::text,
           pr.field,
           pr.ord,
           coalesce(sum(f.measure), 0)
      from public.territory t
      join terr_links links on links.anc_id = t.id
      join periods pr on true
      left join facts f
        on f.territory_id = links.leaf_id
       and f.doc_date >= pr.start_date
       and f.doc_date <= pr.end_date
     where v_tree = 'Territory'
       and t.org_id = v_org
     group by t.territory_name, t.path, pr.field, pr.ord
    union all
    select g.item_group_name,
           extensions.nlevel(g.path) - 1,
           g.path::text,
           pr.field,
           pr.ord,
           coalesce(sum(f.measure), 0)
      from public.item_group g
      join ig_links links on links.anc_id = g.id
      join periods pr on true
      left join facts f
        on f.item_group_id = links.leaf_id
       and f.doc_date >= pr.start_date
       and f.doc_date <= pr.end_date
     where v_tree = 'Item Group'
       and g.org_id = v_org
     group by g.item_group_name, g.path, pr.field, pr.ord
  ),
  grouped as (
    select ''::text as source,
           r.entity,
           null::text as entity_name,
           null::text as stock_uom,
           min(r.indent) as indent,
           r.sort_key,
           r.field,
           r.ord,
           sum(r.amount) as amount
      from group_rows r
     group by r.entity, r.sort_key, r.field, r.ord
  ),
  grouped_keep as (
    select entity
      from grouped
     group by entity
    having sum(amount) <> 0
  ),
  shown as (
    select case r.source
             when 'Quotation' then 1
             when 'Sales Order' then 2
             when 'Delivery Note' then 3
             when 'Payment Entry' then 4
             else 0
           end as source_ord,
           1 as kind,
           r.sort_key,
           r.source,
           r.entity,
           r.entity_name,
           r.stock_uom,
           r.indent,
           r.field,
           r.amount
      from flat_rows r
    union all
    select 0, 1, g.sort_key, g.source, g.entity, g.entity_name, g.stock_uom, g.indent, g.field, g.amount
      from grouped g
      join grouped_keep k on k.entity = g.entity
  )
  select coalesce(jsonb_agg(src.body order by src.source_ord, src.kind, src.sort_key), '[]'::jsonb)
    into v_rows
    from (
      select case source
               when 'Quotation' then 1
               when 'Sales Order' then 2
               when 'Delivery Note' then 3
               when 'Payment Entry' then 4
               else 0
             end as source_ord,
             0 as kind,
             source as sort_key,
             jsonb_build_object('row_type', 'heading', 'entity', source, 'indent', 0) as body
        from flat_keys
       where v_doc = 'All'
       group by source
      union all
      select s.source_ord,
             s.kind,
             s.sort_key,
             jsonb_build_object(
               'row_type', 'entry',
               'entity', s.entity,
               'entity_name', s.entity_name,
               'stock_uom', s.stock_uom,
               'indent', s.indent,
               'total', sum(s.amount)
             ) || coalesce(jsonb_object_agg(s.field, s.amount), '{}'::jsonb)
        from shown s
       group by s.source_ord, s.kind, s.sort_key, s.entity, s.entity_name, s.stock_uom, s.indent
    ) src;

  return jsonb_build_object('columns', v_columns, 'rows', v_rows);
end;
$$;

create or replace function public.report_sales_analytics(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_sales_analytics(p_filters);
$$;

revoke execute on function app.report_sales_analytics(jsonb) from public, anon;
grant execute on function app.report_sales_analytics(jsonb) to authenticated;
revoke execute on function public.report_sales_analytics(jsonb) from public, anon;
grant execute on function public.report_sales_analytics(jsonb) to authenticated;
