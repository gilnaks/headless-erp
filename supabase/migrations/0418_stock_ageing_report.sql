-- Stock Ageing report.
-- ERPNext: erpnext/stock/report/stock_ageing/stock_ageing.py
-- (FIFOSlots, get_average_age, setup_ageing_columns)
-- and erpnext/stock/report/stock_ageing/stock_ageing.js.
-- Remaining qty is replayed from the stock ledger. A same-warehouse
-- voucher pair keeps the consumed slot dates. A different warehouse
-- opens a slot on the transfer date. Buckets are qty only.

create or replace function app.report_stock_ageing(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_to date;
  v_item uuid;
  v_warehouse uuid;
  v_path extensions.ltree;
  v_range text;
  v_bounds int[];
  v_prev int;
  v_columns jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_slots jsonb := '[]'::jsonb;
  v_stash jsonb := '[]'::jsonb;
  v_groups jsonb := '{}'::jsonb;
  v_ready jsonb := '[]'::jsonb;
  v_ord int := 0;
  r record;
  v_left numeric;
  v_had_stash boolean;
  v_idx int;
  v_best int;
  i int;
  v_elem jsonb;
  v_take numeric;
  v_slot_qty numeric;
  v_slot_date date;
  v_new_qty numeric;
  v_key text;
  v_group jsonb;
  v_age int;
  v_bucket int;
  v_n int;
  g record;
  v_code text;
  v_wh_name text;
  v_body jsonb;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'sage_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'sage_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'to_date', '') is null
     or (p_filters ->> 'to_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = 'P0001', message = 'sage_date: As On Date is mandatory';
  end if;
  begin
    v_to := (p_filters ->> 'to_date')::date;
  exception
    when datetime_field_overflow or invalid_datetime_format then
      raise exception using errcode = 'P0001', message = 'sage_date: As On Date is mandatory';
  end;

  if nullif(p_filters ->> 'item', '') is not null
     and (p_filters ->> 'item') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_item := (p_filters ->> 'item')::uuid;
  end if;
  if nullif(p_filters ->> 'warehouse', '') is not null
     and (p_filters ->> 'warehouse') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_warehouse := (p_filters ->> 'warehouse')::uuid;
  end if;

  select s.default_ageing_range into v_range
    from public.accounts_settings s
   where s.org_id = v_org;

  select coalesce(array_agg(t.tok::int order by t.ord), '{}'::int[])
    into v_bounds
    from (
      select u.ord, btrim(u.part) as tok
        from regexp_split_to_table(coalesce(v_range, ''), ',') with ordinality as u(part, ord)
    ) t
   where t.tok ~ '^[0-9]+$';

  if v_bounds is null or cardinality(v_bounds) = 0 then
    v_bounds := array[30, 60, 90];
  end if;

  v_columns := jsonb_build_array(
    jsonb_build_object('field', 'item', 'label', 'Item'),
    jsonb_build_object('field', 'warehouse', 'label', 'Warehouse'),
    jsonb_build_object('field', 'available_qty', 'label', 'Available Qty'),
    jsonb_build_object('field', 'average_age', 'label', 'Average Age')
  );
  v_prev := 0;
  v_n := cardinality(v_bounds);
  for i in 1 .. v_n loop
    v_columns := v_columns || jsonb_build_array(
      jsonb_build_object('field', 'age_' || i, 'label', 'Age (' || v_prev || ' - ' || v_bounds[i] || ')')
    );
    v_prev := v_bounds[i] + 1;
  end loop;
  v_columns := v_columns || jsonb_build_array(
    jsonb_build_object('field', 'age_' || (v_n + 1), 'label', 'Age (' || v_prev || ' - Above)')
  );

  if v_warehouse is not null then
    select w.path into v_path
      from public.warehouse w
     where w.id = v_warehouse
       and w.company_id = v_company;
    if v_path is null then
      return jsonb_build_object('columns', v_columns, 'rows', '[]'::jsonb);
    end if;
  end if;

  for r in
    select s.item_id, s.warehouse_id, s.voucher_id, s.actual_qty, s.posting_date
      from public.stock_ledger_entry s
      join public.warehouse w on w.id = s.warehouse_id and w.org_id = s.org_id
     where s.org_id = v_org
       and s.company_id = v_company
       and not s.is_cancelled
       and s.posting_date <= v_to
       and (v_item is null or s.item_id = v_item)
       and (v_path is null or w.path operator(extensions.<@) v_path)
     order by s.posting_datetime, s.creation_order
  loop
    if r.actual_qty > 0 then
      v_left := r.actual_qty;
      v_had_stash := false;
      loop
        v_idx := null;
        v_best := null;
        if jsonb_array_length(v_stash) > 0 then
          for i in 0 .. jsonb_array_length(v_stash) - 1 loop
            v_elem := v_stash -> i;
            if v_elem ->> 'voucher' is not distinct from r.voucher_id::text
               and v_elem ->> 'item' = r.item_id::text
               and v_elem ->> 'warehouse' = r.warehouse_id::text
               and (v_best is null or (v_elem ->> 'ord')::int < v_best) then
              v_best := (v_elem ->> 'ord')::int;
              v_idx := i;
            end if;
          end loop;
        end if;
        exit when v_idx is null or v_left <= 0;

        v_had_stash := true;
        v_slot_qty := (v_stash -> v_idx ->> 'qty')::numeric;
        v_slot_date := (v_stash -> v_idx ->> 'slot_date')::date;
        if v_slot_qty <= v_left then
          v_take := v_slot_qty;
          v_stash := v_stash - v_idx;
        else
          v_take := v_left;
          v_stash := jsonb_set(
            v_stash,
            array[v_idx::text],
            jsonb_build_object(
              'voucher', v_stash -> v_idx ->> 'voucher',
              'item', v_stash -> v_idx ->> 'item',
              'warehouse', v_stash -> v_idx ->> 'warehouse',
              'qty', v_slot_qty - v_take,
              'slot_date', v_slot_date,
              'ord', (v_stash -> v_idx ->> 'ord')::int
            )
          );
        end if;
        v_ord := v_ord + 1;
        v_slots := v_slots || jsonb_build_array(jsonb_build_object(
          'item', r.item_id,
          'warehouse', r.warehouse_id,
          'qty', v_take,
          'slot_date', v_slot_date,
          'ord', v_ord
        ));
        v_left := v_left - v_take;
      end loop;

      if v_left > 0 and not v_had_stash then
        v_idx := null;
        v_best := null;
        if jsonb_array_length(v_slots) > 0 then
          for i in 0 .. jsonb_array_length(v_slots) - 1 loop
            v_elem := v_slots -> i;
            if v_elem ->> 'item' = r.item_id::text
               and v_elem ->> 'warehouse' = r.warehouse_id::text
               and (v_best is null or (v_elem ->> 'ord')::int < v_best) then
              v_best := (v_elem ->> 'ord')::int;
              v_idx := i;
            end if;
          end loop;
        end if;
        if v_idx is not null and (v_slots -> v_idx ->> 'qty')::numeric <= 0 then
          v_new_qty := (v_slots -> v_idx ->> 'qty')::numeric + r.actual_qty;
          if v_new_qty = 0 then
            v_slots := v_slots - v_idx;
          else
            v_slots := jsonb_set(
              v_slots,
              array[v_idx::text],
              jsonb_build_object(
                'item', r.item_id,
                'warehouse', r.warehouse_id,
                'qty', v_new_qty,
                'slot_date', r.posting_date,
                'ord', (v_slots -> v_idx ->> 'ord')::int
              )
            );
          end if;
        else
          v_ord := v_ord + 1;
          v_slots := v_slots || jsonb_build_array(jsonb_build_object(
            'item', r.item_id,
            'warehouse', r.warehouse_id,
            'qty', v_left,
            'slot_date', r.posting_date,
            'ord', v_ord
          ));
        end if;
      elsif v_left > 0 then
        v_ord := v_ord + 1;
        v_slots := v_slots || jsonb_build_array(jsonb_build_object(
          'item', r.item_id,
          'warehouse', r.warehouse_id,
          'qty', v_left,
          'slot_date', r.posting_date,
          'ord', v_ord
        ));
      end if;
    else
      v_left := abs(r.actual_qty);
      while v_left > 0 loop
        v_idx := null;
        v_best := null;
        if jsonb_array_length(v_slots) > 0 then
          for i in 0 .. jsonb_array_length(v_slots) - 1 loop
            v_elem := v_slots -> i;
            if v_elem ->> 'item' = r.item_id::text
               and v_elem ->> 'warehouse' = r.warehouse_id::text
               and (v_elem ->> 'qty')::numeric > 0
               and (v_best is null or (v_elem ->> 'ord')::int < v_best) then
              v_best := (v_elem ->> 'ord')::int;
              v_idx := i;
            end if;
          end loop;
        end if;

        if v_idx is null then
          v_ord := v_ord + 1;
          v_slots := v_slots || jsonb_build_array(jsonb_build_object(
            'item', r.item_id,
            'warehouse', r.warehouse_id,
            'qty', -v_left,
            'slot_date', r.posting_date,
            'ord', v_ord
          ));
          v_ord := v_ord + 1;
          v_stash := v_stash || jsonb_build_array(jsonb_build_object(
            'voucher', r.voucher_id,
            'item', r.item_id,
            'warehouse', r.warehouse_id,
            'qty', v_left,
            'slot_date', r.posting_date,
            'ord', v_ord
          ));
          v_left := 0;
        else
          v_slot_qty := (v_slots -> v_idx ->> 'qty')::numeric;
          v_slot_date := (v_slots -> v_idx ->> 'slot_date')::date;
          if v_slot_qty <= v_left then
            v_take := v_slot_qty;
            v_slots := v_slots - v_idx;
          else
            v_take := v_left;
            v_slots := jsonb_set(
              v_slots,
              array[v_idx::text],
              jsonb_build_object(
                'item', v_slots -> v_idx ->> 'item',
                'warehouse', v_slots -> v_idx ->> 'warehouse',
                'qty', v_slot_qty - v_take,
                'slot_date', v_slot_date,
                'ord', (v_slots -> v_idx ->> 'ord')::int
              )
            );
          end if;
          v_ord := v_ord + 1;
          v_stash := v_stash || jsonb_build_array(jsonb_build_object(
            'voucher', r.voucher_id,
            'item', r.item_id,
            'warehouse', r.warehouse_id,
            'qty', v_take,
            'slot_date', v_slot_date,
            'ord', v_ord
          ));
          v_left := v_left - v_take;
        end if;
      end loop;
    end if;
  end loop;

  if jsonb_array_length(v_slots) > 0 then
    for i in 0 .. jsonb_array_length(v_slots) - 1 loop
      v_elem := v_slots -> i;
      if (v_elem ->> 'qty')::numeric <= 0 then
        continue;
      end if;
      v_key := (v_elem ->> 'item') || '|' || (v_elem ->> 'warehouse');
      v_age := v_to - (v_elem ->> 'slot_date')::date;
      v_bucket := v_n + 1;
      for v_idx in 1 .. v_n loop
        if v_age <= v_bounds[v_idx] then
          v_bucket := v_idx;
          exit;
        end if;
      end loop;
      if v_groups ? v_key then
        v_group := v_groups -> v_key;
      else
        v_group := jsonb_build_object('qty', 0, 'age_qty', 0);
        for v_idx in 1 .. v_n + 1 loop
          v_group := v_group || jsonb_build_object('age_' || v_idx, 0);
        end loop;
      end if;
      v_group := jsonb_set(v_group, '{qty}', to_jsonb((v_group ->> 'qty')::numeric + (v_elem ->> 'qty')::numeric));
      v_group := jsonb_set(
        v_group,
        '{age_qty}',
        to_jsonb((v_group ->> 'age_qty')::numeric + (v_elem ->> 'qty')::numeric * v_age)
      );
      v_group := jsonb_set(
        v_group,
        array['age_' || v_bucket],
        to_jsonb((v_group ->> ('age_' || v_bucket))::numeric + (v_elem ->> 'qty')::numeric)
      );
      v_groups := jsonb_set(v_groups, array[v_key], v_group);
    end loop;
  end if;

  for g in
    select key, value from jsonb_each(v_groups)
  loop
    select i.item_code, w.name
      into v_code, v_wh_name
      from public.item i
      join public.warehouse w on w.id = split_part(g.key, '|', 2)::uuid and w.org_id = i.org_id
     where i.id = split_part(g.key, '|', 1)::uuid
       and i.org_id = v_org;
    if v_code is null then
      continue;
    end if;
    v_body := jsonb_build_object(
      'row_type', 'entry',
      'item', v_code,
      'warehouse', v_wh_name,
      'available_qty', (g.value ->> 'qty')::numeric,
      'average_age', round((g.value ->> 'age_qty')::numeric / (g.value ->> 'qty')::numeric, 2)
    );
    for v_idx in 1 .. v_n + 1 loop
      v_body := v_body || jsonb_build_object('age_' || v_idx, (g.value ->> ('age_' || v_idx))::numeric);
    end loop;
    v_ready := v_ready || jsonb_build_array(jsonb_build_object(
      'item_code', v_code,
      'warehouse_name', v_wh_name,
      'body', v_body
    ));
  end loop;

  select coalesce(jsonb_agg(x.body order by x.item_code, x.warehouse_name), '[]'::jsonb)
    into v_rows
    from jsonb_to_recordset(v_ready) as x(item_code text, warehouse_name text, body jsonb);

  return jsonb_build_object('columns', v_columns, 'rows', v_rows);
end;
$$;

create or replace function public.report_stock_ageing(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_stock_ageing(p_filters);
$$;

revoke execute on function app.report_stock_ageing(jsonb) from public, anon;
grant execute on function app.report_stock_ageing(jsonb) to authenticated;
revoke execute on function public.report_stock_ageing(jsonb) from public, anon;
grant execute on function public.report_stock_ageing(jsonb) to authenticated;
