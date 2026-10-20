-- 0403 stock: perpetual inventory GL for receipt, issue, transfer, and reconciliation.
-- ERPNext: erpnext/stock/services/base_stock_gl_composer.py,
-- erpnext/stock/doctype/stock_entry/services/gl_composer.py,
-- erpnext/stock/doctype/stock_reconciliation/services/gl_composer.py,
-- erpnext/stock/stock_ledger.py (a changed stock_value_difference reposts GL).
-- docs/modules/04-stock.md §3.3, §4. The contra account is stored on the stock row
-- because the voucher table does not exist yet.

alter table public.stock_ledger_entry
  add column if not exists expense_account_id uuid,
  add column if not exists cost_center_id uuid,
  add column if not exists is_opening boolean not null default false;

alter table public.stock_ledger_entry
  add constraint stock_ledger_entry_expense_account_fk
    foreign key (org_id, expense_account_id) references public.account (org_id, id),
  add constraint stock_ledger_entry_cost_center_fk
    foreign key (org_id, cost_center_id) references public.cost_center (org_id, id);

create index if not exists sle_expense_account_idx
  on public.stock_ledger_entry (org_id, expense_account_id);
create index if not exists sle_cost_center_idx
  on public.stock_ledger_entry (org_id, cost_center_id);

------------------------------------------------------------------------------------------------------------------------
-- Post the open stock-value difference of one voucher. A matching open set is left alone.
-- A different set cancels only the previous stock GL rows and inserts the new pair.
------------------------------------------------------------------------------------------------------------------------

create or replace function app.make_stock_gl_entries(p_voucher_type text, p_voucher_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_company uuid;
  v_perpetual boolean;
  v_inv uuid;
  v_adj uuid;
  v_temp uuid;
  v_cc uuid;
  v_same boolean;
  v_entries jsonb;
  r record;
  v_stock uuid;
  v_contra uuid;
  v_line_cc uuid;
  v_report text;
  v_stock_name text;
  v_contra_name text;
begin
  select s.org_id, s.company_id, c.enable_perpetual_inventory,
         c.default_inventory_account_id, c.stock_adjustment_account_id, c.cost_center_id
    into v_org, v_company, v_perpetual, v_inv, v_adj, v_cc
    from public.stock_ledger_entry s
    join public.companies c on c.id = s.company_id and c.org_id = s.org_id
   where s.voucher_type = p_voucher_type and s.voucher_id = p_voucher_id
   order by s.creation_order
   limit 1;
  if not found then
    return;
  end if;
  if not app.is_member(v_org) then
    raise exception using errcode = 'P0001', message = 'sl_permission: You cannot post stock for this organization';
  end if;
  if not v_perpetual then
    return;
  end if;

  select a.id into v_temp
    from public.account a
   where a.org_id = v_org and a.company_id = v_company and a.account_type = 'Temporary' and not a.is_group
   order by a.name
   limit 1;

  drop table if exists pg_temp._stock_gl_line;
  create temp table _stock_gl_line (
    account_id uuid,
    cost_center_id uuid,
    net numeric,
    posting_date date,
    voucher_no text,
    voucher_detail_id uuid,
    is_opening boolean,
    against text
  ) on commit drop;

  for r in
    select s.stock_value_difference, s.expense_account_id, s.cost_center_id, s.is_opening,
           s.posting_date, s.voucher_no, s.voucher_detail_id, s.warehouse_id,
           coalesce(w.account_id, v_inv) as stock_account, w.name as wh_name
      from public.stock_ledger_entry s
      join public.warehouse w on w.id = s.warehouse_id and w.org_id = s.org_id
     where s.org_id = v_org and s.voucher_type = p_voucher_type and s.voucher_id = p_voucher_id
       and not s.is_cancelled and s.stock_value_difference <> 0
     order by s.posting_datetime, s.creation_order
  loop
    v_stock := r.stock_account;
    v_contra := coalesce(r.expense_account_id, case when r.is_opening then v_temp else v_adj end);
    if v_stock is null then
      raise exception using errcode = 'P0001',
        message = format('sl_gl_account: Warehouse %s needs an inventory account', r.wh_name);
    end if;
    if v_contra is null then
      raise exception using errcode = 'P0001',
        message = format('sl_gl_account: Set an expense account for %s', r.voucher_no);
    end if;
    select a.name into v_stock_name from public.account a where a.id = v_stock and a.org_id = v_org;
    select a.name, a.report_type into v_contra_name, v_report
      from public.account a where a.id = v_contra and a.org_id = v_org;
    v_line_cc := case
      when v_report = 'Profit and Loss' then coalesce(r.cost_center_id, v_cc)
      else null
    end;
    insert into _stock_gl_line (
      account_id, cost_center_id, net, posting_date, voucher_no, voucher_detail_id, is_opening, against
    ) values
      (v_stock, null, r.stock_value_difference, r.posting_date, r.voucher_no, r.voucher_detail_id, r.is_opening, v_contra_name),
      (v_contra, v_line_cc, -r.stock_value_difference, r.posting_date, r.voucher_no, r.voucher_detail_id, r.is_opening, v_stock_name);
  end loop;

  select not exists (
    select 1
      from (
        select account_id, cost_center_id, app.round(sum(net), 2) as net
          from _stock_gl_line
         group by account_id, cost_center_id
        having app.round(sum(net), 2) <> 0
      ) w
      full outer join (
        select account_id, cost_center_id, app.round(sum(debit - credit), 2) as net
          from public.gl_entry
         where org_id = v_org and voucher_type = p_voucher_type and voucher_id = p_voucher_id
           and not is_cancelled and remarks = 'Accounting Entry for Stock'
         group by account_id, cost_center_id
        having app.round(sum(debit - credit), 2) <> 0
      ) h on h.account_id = w.account_id
         and h.cost_center_id is not distinct from w.cost_center_id
     where w.net is distinct from h.net
  ) into v_same;
  if v_same then
    return;
  end if;

  drop table if exists pg_temp._stock_gl_old;
  create temp table _stock_gl_old on commit drop as
  select * from public.gl_entry
   where org_id = v_org and voucher_type = p_voucher_type and voucher_id = p_voucher_id
     and not is_cancelled and remarks = 'Accounting Entry for Stock';

  update public.gl_entry set is_cancelled = true
   where id in (select id from _stock_gl_old);

  insert into public.gl_entry (
    org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id, project_id,
    debit, credit, account_currency, debit_in_account_currency, credit_in_account_currency, against,
    against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, voucher_detail_id, voucher_subtype,
    remarks, is_opening, is_advance, due_date, is_cancelled, transaction_currency, transaction_exchange_rate,
    debit_in_transaction_currency, credit_in_transaction_currency, advance_voucher_type, advance_voucher_id, is_system_generated
  )
  select org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id, project_id,
         credit, debit, account_currency, credit_in_account_currency, debit_in_account_currency, against,
         against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, voucher_detail_id, voucher_subtype,
         'On cancellation of ' || voucher_no, is_opening, is_advance, due_date, true, transaction_currency, transaction_exchange_rate,
         credit_in_transaction_currency, debit_in_transaction_currency, advance_voucher_type, advance_voucher_id, is_system_generated
    from _stock_gl_old;

  select jsonb_agg(jsonb_build_object(
           'company_id', v_company,
           'posting_date', posting_date,
           'account_id', account_id,
           'cost_center_id', cost_center_id,
           'debit', net,
           'voucher_type', p_voucher_type,
           'voucher_id', p_voucher_id,
           'voucher_no', voucher_no,
           'voucher_detail_id', voucher_detail_id,
           'remarks', 'Accounting Entry for Stock',
           'is_opening', is_opening,
           'against', against,
           'is_system_generated', true
         ) order by posting_date, voucher_no)
    into v_entries
    from _stock_gl_line;
  if v_entries is null then
    return;
  end if;
  if not exists (
    select 1 from _stock_gl_line
     group by account_id, cost_center_id
    having app.round(sum(net), 2) <> 0
  ) then
    return;
  end if;
  perform app.make_gl_entries(v_entries, '{"merge": true}'::jsonb);
end;
$$;


create or replace function app.repost_item_valuation(p_item uuid, p_warehouse uuid, p_from timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_method text;
  v_allow boolean;
  v_precision int := 3;
  v_item_code text;
  v_wh_name text;
  v_qty numeric := 0;
  v_value numeric := 0;
  v_rate numeric := 0;
  v_queue jsonb := '[]'::jsonb;
  r record;
  v_actual numeric;
  v_in_rate numeric;
  v_new_qty numeric;
  v_new_value numeric;
  v_new_rate numeric;
  v_new_queue jsonb;
  v_diff numeric;
  v_out_rate numeric;
  v_need numeric;
  v_out_value numeric;
  v_bqty numeric;
  v_brate numeric;
  v_take numeric;
  v_left numeric;
  v_last numeric;
  v_rest numeric;
  v_neg numeric;
  v_i int;
  v_len int;
begin
  select i.org_id, i.item_code, w.name,
         coalesce(nullif(i.valuation_method, ''), nullif(c.valuation_method, ''), nullif(s.valuation_method, ''), 'FIFO'),
         i.allow_negative_stock or coalesce(s.allow_negative_stock, false)
    into v_org, v_item_code, v_wh_name, v_method, v_allow
    from public.item i
    join public.warehouse w on w.id = p_warehouse and w.org_id = i.org_id
    join public.companies c on c.id = w.company_id and c.org_id = i.org_id
    join public.stock_settings s on s.org_id = i.org_id
   where i.id = p_item;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'sl_item: Item and warehouse are required';
  end if;
  if v_method not in ('FIFO', 'Moving Average') then
    raise exception using errcode = 'P0001',
      message = format('sl_valuation: Valuation method %s is not supported', v_method);
  end if;

  select nullif(float_precision, '')::int into v_precision
    from public.system_settings where org_id = v_org;
  v_precision := coalesce(v_precision, 3);

  select qty_after_transaction, stock_value, valuation_rate, stock_queue
    into v_qty, v_value, v_rate, v_queue
    from public.stock_ledger_entry
   where item_id = p_item and warehouse_id = p_warehouse and not is_cancelled
     and posting_datetime < p_from
   order by posting_datetime desc, creation_order desc
   limit 1;
  v_qty := coalesce(v_qty, 0);
  v_value := coalesce(v_value, 0);
  v_rate := coalesce(v_rate, 0);
  v_queue := coalesce(v_queue, '[]'::jsonb);

  drop table if exists pg_temp._repost_touch;
  create temp table _repost_touch (voucher_type text, voucher_id uuid) on commit drop;

  perform set_config('app.sl_write', '1', true);
  for r in
    select id, actual_qty, incoming_rate, voucher_type, voucher_id, stock_value_difference
      from public.stock_ledger_entry
     where item_id = p_item and warehouse_id = p_warehouse and not is_cancelled
       and posting_datetime >= p_from
     order by posting_datetime, creation_order
     for update
  loop
    v_actual := r.actual_qty;
    v_in_rate := app.round(coalesce(r.incoming_rate, 0), v_precision);
    v_out_rate := 0;
    v_new_queue := v_queue;

    if v_actual = 0 then
      raise exception using errcode = 'P0001', message = 'sl_qty: Actual qty cannot be zero';
    end if;

    if v_method = 'Moving Average' then
      if v_actual > 0 then
        v_new_qty := app.round(v_qty + v_actual, v_precision);
        v_new_value := app.round(v_value + (v_actual * v_in_rate), v_precision);
        v_new_rate := case when v_new_qty = 0 then 0 else app.round(v_new_value / v_new_qty, v_precision) end;
      else
        v_new_rate := v_rate;
        v_new_qty := app.round(v_qty + v_actual, v_precision);
        v_new_value := app.round(v_new_qty * v_new_rate, v_precision);
        v_out_rate := v_new_rate;
      end if;
      v_new_queue := case
        when v_new_qty = 0 then '[]'::jsonb
        else jsonb_build_array(jsonb_build_array(v_new_qty, v_new_rate))
      end;
    else
      if v_actual > 0 then
        v_rest := v_actual;
        if jsonb_array_length(v_new_queue) > 0 and (v_new_queue -> 0 ->> 0)::numeric < 0 then
          v_neg := - (v_new_queue -> 0 ->> 0)::numeric;
          if v_rest >= v_neg then
            v_new_queue := v_new_queue - 0;
            v_rest := app.round(v_rest - v_neg, v_precision);
          else
            v_new_queue := jsonb_set(
              v_new_queue, array['0', '0'],
              to_jsonb(app.round((v_new_queue -> 0 ->> 0)::numeric + v_rest, v_precision))
            );
            v_rest := 0;
          end if;
        end if;
        if v_rest > 0 then
          v_len := jsonb_array_length(v_new_queue);
          if v_len > 0 and app.round((v_new_queue -> (v_len - 1) ->> 1)::numeric, v_precision) = v_in_rate then
            v_new_queue := jsonb_set(
              v_new_queue, array[(v_len - 1)::text, '0'],
              to_jsonb(app.round((v_new_queue -> (v_len - 1) ->> 0)::numeric + v_rest, v_precision))
            );
          else
            v_new_queue := v_new_queue || jsonb_build_array(jsonb_build_array(v_rest, v_in_rate));
          end if;
        end if;
      else
        v_need := app.round(-v_actual, v_precision);
        v_out_value := 0;
        v_last := v_rate;
        while v_need > 0 and jsonb_array_length(v_new_queue) > 0 and (v_new_queue -> 0 ->> 0)::numeric > 0 loop
          v_bqty := (v_new_queue -> 0 ->> 0)::numeric;
          v_brate := (v_new_queue -> 0 ->> 1)::numeric;
          v_last := v_brate;
          v_take := least(v_bqty, v_need);
          v_out_value := v_out_value + (v_take * v_brate);
          v_need := app.round(v_need - v_take, v_precision);
          v_left := app.round(v_bqty - v_take, v_precision);
          if v_left = 0 then
            v_new_queue := v_new_queue - 0;
          else
            v_new_queue := jsonb_set(v_new_queue, array['0', '0'], to_jsonb(v_left));
          end if;
        end loop;
        if v_need > 0 then
          v_out_value := v_out_value + (v_need * v_last);
          if jsonb_array_length(v_new_queue) > 0
             and (v_new_queue -> 0 ->> 0)::numeric < 0
             and app.round((v_new_queue -> 0 ->> 1)::numeric, v_precision) = app.round(v_last, v_precision) then
            v_new_queue := jsonb_set(
              v_new_queue, array['0', '0'],
              to_jsonb(app.round((v_new_queue -> 0 ->> 0)::numeric - v_need, v_precision))
            );
          else
            v_new_queue := jsonb_build_array(jsonb_build_array(app.round(-v_need, v_precision), v_last)) || v_new_queue;
          end if;
        end if;
        v_out_rate := app.round(v_out_value / (-v_actual), v_precision);
      end if;

      v_new_qty := 0;
      v_new_value := 0;
      for v_i in 0 .. jsonb_array_length(v_new_queue) - 1 loop
        v_new_qty := v_new_qty + (v_new_queue -> v_i ->> 0)::numeric;
        v_new_value := v_new_value + ((v_new_queue -> v_i ->> 0)::numeric * (v_new_queue -> v_i ->> 1)::numeric);
      end loop;
      v_new_qty := app.round(v_new_qty, v_precision);
      v_new_value := app.round(v_new_value, v_precision);
      if v_new_qty = 0 then
        v_new_rate := 0;
        v_new_value := 0;
        v_new_queue := '[]'::jsonb;
      else
        v_new_rate := app.round(v_new_value / v_new_qty, v_precision);
      end if;
    end if;

    if v_new_qty < 0 and not v_allow then
      raise exception using errcode = 'P0001',
        message = format('negative_stock: Insufficient stock for %s in %s', v_item_code, v_wh_name);
    end if;

    v_diff := app.round(v_new_value - v_value, v_precision);
    update public.stock_ledger_entry
       set qty_after_transaction = v_new_qty,
           valuation_rate = v_new_rate,
           stock_value = v_new_value,
           stock_value_difference = v_diff,
           stock_queue = v_new_queue,
           outgoing_rate = v_out_rate
     where id = r.id;

    v_qty := v_new_qty;
    v_value := v_new_value;
    v_rate := v_new_rate;
    v_queue := v_new_queue;
    if app.round(coalesce(r.stock_value_difference, 0), v_precision) is distinct from v_diff then
      insert into _repost_touch (voucher_type, voucher_id) values (r.voucher_type, r.voucher_id);
    end if;
  end loop;
  perform set_config('app.sl_write', '', true);
  if current_setting('app.defer_stock_gl', true) = '1' then
    insert into _stock_gl_touch (voucher_type, voucher_id)
    select distinct voucher_type, voucher_id from _repost_touch
    on conflict do nothing;
  else
    for r in select distinct voucher_type, voucher_id from _repost_touch loop
      perform app.make_stock_gl_entries(r.voucher_type, r.voucher_id);
    end loop;
  end if;
exception
  when others then
    perform set_config('app.sl_write', '', true);
    raise;
end;
$$;


create or replace function app.make_sl_entries(p_entries jsonb, p_opts jsonb default '{}')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e jsonb;
  v_cancel boolean := coalesce((p_opts ->> 'is_cancelled')::boolean, false);
  v_org uuid;
  v_company uuid;
  v_item uuid;
  v_wh uuid;
  v_detail uuid;
  v_voucher uuid;
  v_qty numeric;
  v_rate numeric;
  v_date date;
  v_time time;
  v_at timestamptz;
  v_fy uuid;
  v_frozen date;
  v_frozen_days int;
  v_frozen_role text;
  v_uom uuid;
  v_serial boolean;
  v_batch boolean;
  v_stock boolean;
  v_group boolean;
  v_disabled boolean;
  v_wh_company uuid;
  orig public.stock_ledger_entry;
  touched record;
begin
  if jsonb_typeof(p_entries) is distinct from 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception using errcode = 'P0001', message = 'sl_entries: At least one stock ledger entry is required';
  end if;

  perform set_config('app.defer_stock_gl', '1', true);
  drop table if exists pg_temp._stock_gl_touch;
  create temp table _stock_gl_touch (
    voucher_type text not null,
    voucher_id uuid not null,
    primary key (voucher_type, voucher_id)
  ) on commit drop;

  for e in select value from jsonb_array_elements(p_entries) loop
    v_item := nullif(e ->> 'item_id', '')::uuid;
    v_wh := nullif(e ->> 'warehouse_id', '')::uuid;
    v_company := nullif(e ->> 'company_id', '')::uuid;
    v_detail := nullif(e ->> 'voucher_detail_id', '')::uuid;
    v_voucher := nullif(e ->> 'voucher_id', '')::uuid;
    v_qty := (e ->> 'actual_qty')::numeric;
    v_rate := coalesce((e ->> 'incoming_rate')::numeric, 0);
    v_date := (e ->> 'posting_date')::date;
    v_time := coalesce(nullif(e ->> 'posting_time', '')::time, '00:00:00'::time);
    if v_item is null or v_wh is null or v_voucher is null or nullif(e ->> 'voucher_type', '') is null
       or nullif(e ->> 'voucher_no', '') is null or v_date is null or v_qty is null then
      raise exception using errcode = 'P0001', message = 'sl_entries: Item, warehouse, posting date, quantity, and voucher are required';
    end if;
    if v_qty = 0 then
      raise exception using errcode = 'P0001', message = 'sl_qty: Actual qty cannot be zero';
    end if;
    insert into _stock_gl_touch (voucher_type, voucher_id)
    values (e ->> 'voucher_type', v_voucher)
    on conflict do nothing;

    select i.org_id, i.stock_uom_id, i.has_serial_no, i.has_batch_no, i.is_stock_item
      into v_org, v_uom, v_serial, v_batch, v_stock
      from public.item i
     where i.id = v_item;
    if v_org is null then
      raise exception using errcode = 'P0001', message = 'sl_item: Item is required';
    end if;
    if not app.is_member(v_org) then
      raise exception using errcode = 'P0001', message = 'sl_permission: You cannot post stock for this organization';
    end if;
    if not v_stock then
      raise exception using errcode = 'P0001', message = 'sl_item: Item is not a stock item';
    end if;

    select w.company_id, w.is_group, w.disabled
      into v_wh_company, v_group, v_disabled
      from public.warehouse w
     where w.id = v_wh and w.org_id = v_org;
    if v_wh_company is null or v_group or v_disabled then
      raise exception using errcode = 'P0001', message = 'sl_warehouse: Warehouse must be an active leaf of this organization';
    end if;
    if v_company is not null and v_company is distinct from v_wh_company then
      raise exception using errcode = 'P0001', message = 'sl_warehouse: Warehouse must belong to the company';
    end if;
    v_company := v_wh_company;
    v_at := (v_date + v_time)::timestamp;

    select s.stock_frozen_upto, s.stock_frozen_upto_days, s.stock_auth_role
      into v_frozen, v_frozen_days, v_frozen_role
      from public.stock_settings s
     where s.org_id = v_org;
    if (v_frozen is not null and v_date <= v_frozen)
       or (v_frozen_days is not null and v_date < current_date - v_frozen_days) then
      if v_frozen_role is null or not app.has_role(v_org, v_frozen_role) then
        raise exception using errcode = 'P0001',
          message = format('sl_frozen: You are not authorized to add or update entries before %s', coalesce(v_frozen::text, (current_date - v_frozen_days)::text));
      end if;
    end if;

    perform pg_advisory_xact_lock(hashtext(v_item::text), hashtext(v_wh::text));

    if v_cancel then
      select * into orig
        from public.stock_ledger_entry
       where org_id = v_org and voucher_type = e ->> 'voucher_type' and voucher_id = v_voucher
         and item_id = v_item and warehouse_id = v_wh
         and voucher_detail_id is not distinct from v_detail
         and not is_cancelled
       order by creation_order
       limit 1;
      if not found then
        raise exception using errcode = 'P0001', message = 'sl_cancel: Stock ledger row not found';
      end if;
      perform set_config('app.sl_write', '1', true);
      update public.stock_ledger_entry set is_cancelled = true where id = orig.id;
      insert into public.stock_ledger_entry (
        org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
        voucher_type, voucher_id, voucher_no, voucher_detail_id, actual_qty, qty_after_transaction,
        incoming_rate, outgoing_rate, valuation_rate, stock_value, stock_value_difference, stock_queue,
        stock_uom_id, serial_and_batch_bundle_id, batch_id, has_serial_no, has_batch_no, fiscal_year_id,
        project_id, is_cancelled, is_adjustment_entry, expense_account_id, cost_center_id, is_opening
      ) values (
        orig.org_id, orig.company_id, orig.item_id, orig.warehouse_id, orig.posting_date, orig.posting_time,
        orig.posting_datetime, orig.voucher_type, orig.voucher_id, orig.voucher_no, orig.voucher_detail_id,
        -orig.actual_qty, orig.qty_after_transaction - orig.actual_qty, orig.incoming_rate, orig.outgoing_rate,
        orig.valuation_rate, orig.stock_value, -orig.stock_value_difference, orig.stock_queue, orig.stock_uom_id,
        orig.serial_and_batch_bundle_id, orig.batch_id, orig.has_serial_no, orig.has_batch_no, orig.fiscal_year_id,
        orig.project_id, true, orig.is_adjustment_entry, orig.expense_account_id, orig.cost_center_id, orig.is_opening
      );
      perform set_config('app.sl_write', '', true);
      perform app.repost_item_valuation(v_item, v_wh, orig.posting_datetime);
    else
      select fy.id into v_fy
        from public.fiscal_year fy
       where fy.org_id = v_org and not fy.disabled
         and v_date between fy.year_start_date and fy.year_end_date
         and (
           not exists (select 1 from public.fiscal_year_company c where c.parent_id = fy.id)
           or exists (select 1 from public.fiscal_year_company c where c.parent_id = fy.id and c.company_id = v_company)
         )
       order by fy.year_start_date
       limit 1;
      if v_fy is null then
        raise exception using errcode = 'P0001',
          message = format('fiscal_year: Date %s is not in any active Fiscal Year', v_date);
      end if;

      insert into public.stock_ledger_entry (
        org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
        voucher_type, voucher_id, voucher_no, voucher_detail_id, actual_qty, incoming_rate,
        stock_uom_id, serial_and_batch_bundle_id, batch_id, has_serial_no, has_batch_no,
        fiscal_year_id, project_id, is_adjustment_entry, expense_account_id, cost_center_id, is_opening
      ) values (
        v_org, v_company, v_item, v_wh, v_date, v_time, v_at,
        e ->> 'voucher_type', v_voucher, e ->> 'voucher_no', v_detail, v_qty,
        case when v_qty > 0 then v_rate else 0 end,
        v_uom, nullif(e ->> 'serial_and_batch_bundle_id', '')::uuid, nullif(e ->> 'batch_id', '')::uuid,
        v_serial, v_batch, v_fy, nullif(e ->> 'project_id', '')::uuid,
        coalesce((e ->> 'is_adjustment_entry')::boolean, false),
        nullif(e ->> 'expense_account_id', '')::uuid,
        nullif(e ->> 'cost_center_id', '')::uuid,
        coalesce((e ->> 'is_opening')::boolean, false)
      );
      perform app.repost_item_valuation(v_item, v_wh, v_at);
    end if;

    perform app.update_bin_qty(v_item, v_wh);
  end loop;

  perform set_config('app.defer_stock_gl', '', true);
  for touched in select voucher_type, voucher_id from _stock_gl_touch loop
    perform app.make_stock_gl_entries(touched.voucher_type, touched.voucher_id);
  end loop;
exception
  when others then
    perform set_config('app.defer_stock_gl', '', true);
    raise;
end;
$$;

revoke execute on function app.make_stock_gl_entries(text, uuid) from public, anon;
grant execute on function app.make_stock_gl_entries(text, uuid) to authenticated;

