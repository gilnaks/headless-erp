-- Stock Analytics report.
-- ERPNext: erpnext/stock/report/stock_analytics/stock_analytics.py
-- and erpnext/stock/report/stock_analytics/stock_analytics.js.
-- Period columns are the movement inside the period, not a carried balance.
-- Warehouse and item group rows roll up to ancestors. See docs deviation 19.

create or replace function app.report_stock_analytics(p_filters jsonb)
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
  v_value boolean;
  v_range text;
  v_item uuid;
  v_item_group uuid;
  v_warehouse uuid;
  v_brand uuid;
  v_path extensions.ltree;
  v_group_path extensions.ltree;
  v_wh_base int;
  v_grp_base int;
  v_entity_label text;
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
    raise exception using errcode = 'P0001', message = 'sana_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'sana_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null
     or (p_filters ->> 'from_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
     or (p_filters ->> 'to_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = 'P0001', message = 'sana_dates: From Date and To Date are mandatory';
  end if;
  begin
    v_from := (p_filters ->> 'from_date')::date;
    v_to := (p_filters ->> 'to_date')::date;
  exception
    when datetime_field_overflow or invalid_datetime_format then
      raise exception using errcode = 'P0001', message = 'sana_dates: From Date and To Date are mandatory';
  end;
  if v_from > v_to then
    raise exception using errcode = 'P0001', message = 'sana_dates: From Date and To Date are mandatory';
  end if;

  v_tree := btrim(p_filters ->> 'tree_type');
  if v_tree is null or v_tree not in ('Warehouse', 'Item', 'Item Group', 'Brand') then
    raise exception using errcode = 'P0001', message = 'sana_tree: Tree Type is invalid';
  end if;
  if coalesce(btrim(p_filters ->> 'value_quantity'), '') not in ('Value', 'Quantity') then
    raise exception using errcode = 'P0001', message = 'sana_value: Value or Qty is invalid';
  end if;
  v_value := btrim(p_filters ->> 'value_quantity') = 'Value';
  v_range := btrim(p_filters ->> 'range');
  if v_range is null or v_range not in ('Weekly', 'Monthly', 'Quarterly', 'Yearly') then
    raise exception using errcode = 'P0001', message = 'sana_range: Range is invalid';
  end if;

  if nullif(p_filters ->> 'item', '') is not null
     and (p_filters ->> 'item') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_item := (p_filters ->> 'item')::uuid;
  end if;
  if nullif(p_filters ->> 'item_group', '') is not null
     and (p_filters ->> 'item_group') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_item_group := (p_filters ->> 'item_group')::uuid;
  end if;
  if nullif(p_filters ->> 'warehouse', '') is not null
     and (p_filters ->> 'warehouse') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_warehouse := (p_filters ->> 'warehouse')::uuid;
  end if;
  if nullif(p_filters ->> 'brand', '') is not null
     and (p_filters ->> 'brand') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_brand := (p_filters ->> 'brand')::uuid;
  end if;

  v_entity_label := case v_tree
    when 'Item Group' then 'Item Group'
    when 'Warehouse' then 'Warehouse'
    when 'Brand' then 'Brand'
    else 'Item'
  end;
  v_columns := jsonb_build_array(jsonb_build_object('field', 'entity', 'label', v_entity_label));

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

  if v_warehouse is not null then
    select w.path into v_path
      from public.warehouse w
     where w.id = v_warehouse
       and w.company_id = v_company;
    if v_path is null then
      return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
    end if;
  end if;
  if v_item_group is not null then
    select g.path into v_group_path
      from public.item_group g
     where g.id = v_item_group
       and g.org_id = v_org;
    if v_group_path is null then
      return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
    end if;
  end if;
  if v_brand is not null and not exists (
    select 1 from public.brand b where b.id = v_brand and b.org_id = v_org
  ) then
    return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
  end if;
  if v_item is not null and not exists (
    select 1 from public.item i where i.id = v_item and i.org_id = v_org
  ) then
    return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
  end if;

  select case when v_path is null then 1 else extensions.nlevel(v_path) end into v_wh_base;
  select case when v_group_path is null then 1 else extensions.nlevel(v_group_path) end into v_grp_base;

  with periods as (
    select p.field, p.start_date, p.end_date, p.ord
      from jsonb_to_recordset(v_periods) as p(field text, start_date date, end_date date, ord int)
  ),
  moves as (
    select s.item_id,
           s.warehouse_id,
           i.item_group_id,
           i.brand_id,
           pr.field,
           sum(case when v_value then s.stock_value_difference else s.actual_qty end) as measure
      from public.stock_ledger_entry s
      join public.item i on i.id = s.item_id and i.org_id = s.org_id
      join public.warehouse w on w.id = s.warehouse_id and w.org_id = s.org_id
      join public.item_group g on g.id = i.item_group_id and g.org_id = i.org_id
      join periods pr on s.posting_date >= pr.start_date and s.posting_date <= pr.end_date
     where s.org_id = v_org
       and s.company_id = v_company
       and not s.is_cancelled
       and (v_item is null or s.item_id = v_item)
       and (v_brand is null or i.brand_id = v_brand)
       and (v_path is null or w.path operator(extensions.<@) v_path)
       and (v_group_path is null or g.path operator(extensions.<@) v_group_path)
     group by s.item_id, s.warehouse_id, i.item_group_id, i.brand_id, pr.field
  ),
  item_active as (
    select s.item_id
      from (
        select m.item_id, m.field, sum(m.measure) as measure
          from moves m
         group by m.item_id, m.field
      ) s
     group by s.item_id
    having bool_or(s.measure <> 0)
  ),
  wh_active as (
    select s.warehouse_id
      from (
        select m.warehouse_id, m.field, sum(m.measure) as measure
          from moves m
         group by m.warehouse_id, m.field
      ) s
     group by s.warehouse_id
    having bool_or(s.measure <> 0)
  ),
  wh_links as (
    select w_leaf.id as leaf_id, w_anc.id as anc_id
      from wh_active a
      join public.warehouse w_leaf on w_leaf.id = a.warehouse_id
      join public.warehouse w_anc
        on w_leaf.path operator(extensions.<@) w_anc.path
       and w_anc.org_id = w_leaf.org_id
  ),
  grp_active as (
    select s.item_group_id
      from (
        select m.item_group_id, m.field, sum(m.measure) as measure
          from moves m
         group by m.item_group_id, m.field
      ) s
     group by s.item_group_id
    having bool_or(s.measure <> 0)
  ),
  grp_links as (
    select g_leaf.id as leaf_id, g_anc.id as anc_id
      from grp_active a
      join public.item_group g_leaf on g_leaf.id = a.item_group_id
      join public.item_group g_anc
        on g_leaf.path operator(extensions.<@) g_anc.path
       and g_anc.org_id = g_leaf.org_id
  ),
  brand_active as (
    select s.brand_id
      from (
        select m.brand_id, m.field, sum(m.measure) as measure
          from moves m
         where m.brand_id is not null
         group by m.brand_id, m.field
      ) s
     group by s.brand_id
    having bool_or(s.measure <> 0)
  ),
  rolled as (
    select i.item_code as entity,
           0 as indent,
           i.item_code as sort_key,
           pr.field,
           pr.ord,
           coalesce(sum(m.measure), 0) as amount
      from item_active a
      join public.item i on i.id = a.item_id
      join periods pr on true
      left join moves m on m.item_id = a.item_id and m.field = pr.field
     where v_tree = 'Item'
     group by i.item_code, pr.field, pr.ord
    union all
    select g.item_group_name as entity,
           extensions.nlevel(g.path) - v_grp_base as indent,
           g.path::text as sort_key,
           pr.field,
           pr.ord,
           coalesce(sum(m.measure), 0) as amount
      from public.item_group g
      join grp_links links on links.anc_id = g.id
      join periods pr on true
      left join moves m on m.item_group_id = links.leaf_id and m.field = pr.field
     where v_tree = 'Item Group'
       and g.org_id = v_org
       and (v_group_path is null or g.path operator(extensions.<@) v_group_path)
     group by g.item_group_name, g.path, pr.field, pr.ord
    union all
    select w.name as entity,
           extensions.nlevel(w.path) - v_wh_base as indent,
           w.path::text as sort_key,
           pr.field,
           pr.ord,
           coalesce(sum(m.measure), 0) as amount
      from public.warehouse w
      join wh_links links on links.anc_id = w.id
      join periods pr on true
      left join moves m on m.warehouse_id = links.leaf_id and m.field = pr.field
     where v_tree = 'Warehouse'
       and w.company_id = v_company
       and (v_path is null or w.path operator(extensions.<@) v_path)
     group by w.name, w.path, pr.field, pr.ord
    union all
    select b.brand as entity,
           0 as indent,
           b.brand as sort_key,
           pr.field,
           pr.ord,
           coalesce(sum(m.measure), 0) as amount
      from brand_active a
      join public.brand b on b.id = a.brand_id
      join periods pr on true
      left join moves m on m.brand_id = a.brand_id and m.field = pr.field
     where v_tree = 'Brand'
     group by b.brand, pr.field, pr.ord
  )
  select coalesce(jsonb_agg(src.body order by src.sort_key, src.entity), '[]'::jsonb)
    into v_rows
    from (
      select r.sort_key,
             r.entity,
             jsonb_build_object(
               'row_type', 'entry',
               'entity', r.entity,
               'indent', min(r.indent)
             ) || coalesce(jsonb_object_agg(r.field, r.amount), '{}'::jsonb) as body
        from rolled r
       group by r.sort_key, r.entity
    ) src;

  return jsonb_build_object('columns', v_columns, 'rows', v_rows);
end;
$$;

create or replace function public.report_stock_analytics(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_stock_analytics(p_filters);
$$;

revoke execute on function app.report_stock_analytics(jsonb) from public, anon;
grant execute on function app.report_stock_analytics(jsonb) to authenticated;
revoke execute on function public.report_stock_analytics(jsonb) from public, anon;
grant execute on function public.report_stock_analytics(jsonb) to authenticated;
