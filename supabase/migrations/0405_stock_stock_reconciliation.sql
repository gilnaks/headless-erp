-- 0405 stock: Stock Reconciliation, including Opening Stock (docs/modules/04-stock.md §2.12, §3.2, §3.3).
-- ERPNext: erpnext/stock/doctype/stock_reconciliation/stock_reconciliation.json,
-- stock_reconciliation.py, erpnext/stock/stock_ledger.py.
-- A reconciliation sets the item-warehouse balance and replaces the queue with one bucket.
-- Serial and batch columns are stored and not validated.

create table if not exists public.stock_reconciliation (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations (id) on delete cascade,
  name                text not null,
  naming_series       text not null default 'MAT-RECO-.YYYY.-',
  company_id          uuid not null,
  purpose             text not null,
  posting_date        date not null default current_date,
  posting_time        time not null default localtime,
  expense_account_id  uuid,
  cost_center_id      uuid,
  difference_amount   numeric(21,9) not null default 0,
  set_warehouse_id    uuid,
  docstatus           smallint not null default 0 check (docstatus in (0, 1, 2)),
  amended_from        uuid,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, expense_account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  foreign key (org_id, set_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, amended_from) references public.stock_reconciliation (org_id, id) on delete set null (amended_from),
  check (purpose in ('Opening Stock', 'Stock Reconciliation', 'Adjustment Entry'))
);

create index if not exists stock_reconciliation_company_idx on public.stock_reconciliation (org_id, company_id);
create index if not exists stock_reconciliation_expense_idx on public.stock_reconciliation (org_id, expense_account_id);
create index if not exists stock_reconciliation_cost_center_idx on public.stock_reconciliation (org_id, cost_center_id);
create index if not exists stock_reconciliation_set_wh_idx on public.stock_reconciliation (org_id, set_warehouse_id);
create index if not exists stock_reconciliation_amended_idx on public.stock_reconciliation (org_id, amended_from);
create index if not exists stock_reconciliation_posting_idx on public.stock_reconciliation (org_id, posting_date);

create table if not exists public.stock_reconciliation_item (
  id                          uuid primary key default gen_random_uuid(),
  org_id                      uuid not null,
  parent_id                   uuid not null,
  idx                         int not null,
  item_id                     uuid not null,
  warehouse_id                uuid,
  qty                         numeric(21,9) not null default 0,
  valuation_rate              numeric(21,9) not null default 0,
  current_qty                 numeric(21,9) not null default 0,
  current_valuation_rate      numeric(21,9) not null default 0,
  current_amount              numeric(21,9) not null default 0,
  quantity_difference         numeric(21,9) not null default 0,
  amount_difference           numeric(21,9) not null default 0,
  batch_no                    text,
  serial_no                   text,
  serial_and_batch_bundle     text,
  allow_zero_valuation_rate   boolean not null default false,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.stock_reconciliation (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id)
);

create index if not exists stock_reconciliation_item_parent_idx on public.stock_reconciliation_item (org_id, parent_id);
create index if not exists stock_reconciliation_item_item_idx on public.stock_reconciliation_item (org_id, item_id);
create index if not exists stock_reconciliation_item_wh_idx on public.stock_reconciliation_item (org_id, warehouse_id);

create or replace function app.stock_reconciliation_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
  end if;
  if new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'MAT-RECO-.YYYY.-';
  end if;
  if new.posting_date is null then
    new.posting_date := current_date;
  end if;
  if new.posting_time is null then
    new.posting_time := localtime;
  end if;
  if new.purpose is null or new.purpose not in ('Opening Stock', 'Stock Reconciliation', 'Adjustment Entry') then
    raise exception using errcode = 'P0001', message = 'reco_purpose: Purpose is required';
  end if;
  if new.amended_from is not null and tg_op = 'INSERT' then
    new.docstatus := 0;
  end if;
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  return new;
end;
$$;

create or replace function app.stock_reconciliation_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_purpose text;
  v_set uuid;
  v_stock boolean;
  v_qty numeric;
  v_rate numeric;
  v_value numeric;
begin
  select i.is_stock_item into v_stock
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001', message = format('reco_item: Row %s: Item is required', new.idx);
  end if;
  if v_stock is not true then
    raise exception using errcode = 'P0001', message = format('reco_item: Row %s: Item is not a stock item', new.idx);
  end if;
  if new.warehouse_id is null then
    select r.set_warehouse_id into v_set from public.stock_reconciliation r where r.id = new.parent_id;
    new.warehouse_id := v_set;
  end if;
  if new.warehouse_id is null then
    raise exception using errcode = 'P0001', message = format('reco_warehouse: Row %s: Warehouse is required', new.idx);
  end if;
  if new.qty is null or new.qty < 0 then
    raise exception using errcode = 'P0001', message = format('reco_qty: Row %s: Quantity cannot be negative', new.idx);
  end if;
  new.valuation_rate := coalesce(new.valuation_rate, 0);
  if current_setting('app.reco_freeze', true) = '1' then
    return new;
  end if;
  select r.purpose into v_purpose from public.stock_reconciliation r where r.id = new.parent_id;
  select s.qty_after_transaction, s.valuation_rate, s.stock_value
    into v_qty, v_rate, v_value
    from public.stock_ledger_entry s
   where s.org_id = new.org_id and s.item_id = new.item_id and s.warehouse_id = new.warehouse_id
     and not s.is_cancelled
   order by s.posting_datetime desc, s.creation_order desc
   limit 1;
  new.current_qty := coalesce(v_qty, 0);
  new.current_valuation_rate := coalesce(v_rate, 0);
  new.current_amount := coalesce(v_value, 0);
  if v_purpose = 'Adjustment Entry' then
    new.qty := new.current_qty;
  end if;
  new.quantity_difference := new.qty - new.current_qty;
  new.amount_difference := app.round(new.qty * new.valuation_rate, 2) - app.round(new.current_amount, 2);
  return new;
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
    select id, actual_qty, incoming_rate, voucher_type, voucher_id, stock_value_difference, is_adjustment_entry
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

    if v_actual = 0 and not coalesce(r.is_adjustment_entry, false) then
      raise exception using errcode = 'P0001', message = 'sl_qty: Actual qty cannot be zero';
    end if;

    -- A reconciliation sets the balance. It does not consume FIFO buckets.
    if r.voucher_type = 'Stock Reconciliation' then
      if coalesce(r.is_adjustment_entry, false) then
        v_new_qty := v_qty;
      else
        v_new_qty := app.round(v_qty + v_actual, v_precision);
      end if;
      if v_new_qty = 0 then
        v_new_value := 0;
        v_new_rate := 0;
        v_new_queue := '[]'::jsonb;
      else
        v_new_rate := v_in_rate;
        v_new_value := app.round(v_new_qty * v_new_rate, v_precision);
        v_new_queue := jsonb_build_array(jsonb_build_array(v_new_qty, v_new_rate));
      end if;
      v_out_rate := 0;
    elsif v_method = 'Moving Average' then
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
    if v_qty = 0 and not coalesce((e ->> 'is_adjustment_entry')::boolean, false) then
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
        case
          when e ->> 'voucher_type' = 'Stock Reconciliation' then v_rate
          when v_qty > 0 then v_rate
          else 0
        end,
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

create or replace function app.on_submit__stock_reconciliation(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.stock_reconciliation;
  r record;
  v_at timestamp;
  v_expense uuid;
  v_type text;
  v_prev_qty numeric;
  v_prev_rate numeric;
  v_prev_value numeric;
  v_actual numeric;
  v_adjust boolean;
  v_post boolean;
  v_entries jsonb;
  v_count int := 0;
begin
  select * into h from public.stock_reconciliation where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Stock Reconciliation not found';
  end if;
  if not exists (select 1 from public.stock_reconciliation_item d where d.parent_id = p_id) then
    raise exception using errcode = 'P0001', message = 'reco_items: Items table cannot be blank';
  end if;

  update public.stock_reconciliation_item d
     set warehouse_id = coalesce(d.warehouse_id, h.set_warehouse_id)
   where d.parent_id = p_id;
  if exists (select 1 from public.stock_reconciliation_item d where d.parent_id = p_id and d.warehouse_id is null) then
    raise exception using errcode = 'P0001', message = 'reco_warehouse: Warehouse is required';
  end if;
  if exists (
    select 1 from public.stock_reconciliation_item d
     where d.parent_id = p_id
     group by d.item_id, d.warehouse_id
    having count(*) > 1
  ) then
    raise exception using errcode = 'P0001', message = 'reco_duplicate: Item and warehouse is repeated';
  end if;

  v_expense := h.expense_account_id;
  if v_expense is not null then
    select a.account_type into v_type
      from public.account a
     where a.id = v_expense and a.org_id = h.org_id;
    if v_type = 'Stock' then
      raise exception using errcode = 'P0001', message = 'reco_account: Difference Account cannot be a Stock account';
    end if;
  elsif h.purpose = 'Opening Stock' then
    select a.id into v_expense
      from public.account a
     where a.org_id = h.org_id and a.company_id = h.company_id
       and a.account_type = 'Temporary' and not a.is_group
     order by a.name
     limit 1;
    if v_expense is null then
      raise exception using errcode = 'P0001', message = 'reco_account: Temporary Opening account is required';
    end if;
  else
    select c.stock_adjustment_account_id into v_expense
      from public.companies c
     where c.id = h.company_id and c.org_id = h.org_id;
    if v_expense is null then
      raise exception using errcode = 'P0001', message = 'reco_account: Stock Adjustment account is required';
    end if;
  end if;
  if h.expense_account_id is null then
    update public.stock_reconciliation set expense_account_id = v_expense where id = p_id;
    h.expense_account_id := v_expense;
  end if;

  v_at := h.posting_date + h.posting_time;
  drop table if exists pg_temp._reco;
  create temp table _reco (
    id uuid,
    item_id uuid,
    warehouse_id uuid,
    rate numeric,
    prev_qty numeric,
    prev_rate numeric,
    prev_value numeric,
    actual_qty numeric,
    is_adjustment boolean
  ) on commit drop;

  for r in
    select d.id, d.idx, d.item_id, d.warehouse_id, d.qty, d.valuation_rate, d.allow_zero_valuation_rate
      from public.stock_reconciliation_item d
     where d.parent_id = p_id
     order by d.idx
  loop
    v_prev_qty := 0;
    v_prev_rate := 0;
    v_prev_value := 0;
    select s.qty_after_transaction, s.valuation_rate, s.stock_value
      into v_prev_qty, v_prev_rate, v_prev_value
      from public.stock_ledger_entry s
     where s.org_id = h.org_id and s.item_id = r.item_id and s.warehouse_id = r.warehouse_id
       and not s.is_cancelled and s.posting_datetime < v_at
     order by s.posting_datetime desc, s.creation_order desc
     limit 1;
    v_prev_qty := coalesce(v_prev_qty, 0);
    v_prev_rate := coalesce(v_prev_rate, 0);
    v_prev_value := coalesce(v_prev_value, 0);

    if h.purpose = 'Opening Stock' then
      if exists (
        select 1 from public.stock_ledger_entry s
         where s.org_id = h.org_id and s.item_id = r.item_id and s.warehouse_id = r.warehouse_id
           and not s.is_cancelled and s.posting_datetime <= v_at
      ) then
        raise exception using errcode = 'P0001',
          message = 'reco_opening: Opening Stock is only for an item and warehouse with no stock yet';
      end if;
      if r.qty <= 0 then
        raise exception using errcode = 'P0001', message = format('reco_qty: Row %s: Quantity must be greater than zero', r.idx);
      end if;
      v_actual := r.qty;
      v_adjust := false;
      v_post := true;
    elsif h.purpose = 'Adjustment Entry' then
      if r.qty is distinct from v_prev_qty then
        raise exception using errcode = 'P0001',
          message = format('reco_qty: Row %s: Adjustment Entry does not change quantity', r.idx);
      end if;
      v_actual := 0;
      v_adjust := true;
      v_post := r.valuation_rate is distinct from v_prev_rate;
    else
      v_actual := r.qty - v_prev_qty;
      v_adjust := false;
      v_post := r.qty is distinct from v_prev_qty or r.valuation_rate is distinct from v_prev_rate;
    end if;

    if v_post and r.valuation_rate = 0 and not r.allow_zero_valuation_rate
       and not (h.purpose = 'Stock Reconciliation' and r.qty = 0) then
      raise exception using errcode = 'P0001',
        message = format('reco_rate: Row %s: Valuation Rate is required', r.idx);
    end if;

    if v_post then
      insert into _reco (id, item_id, warehouse_id, rate, prev_qty, prev_rate, prev_value, actual_qty, is_adjustment)
      values (r.id, r.item_id, r.warehouse_id, r.valuation_rate, v_prev_qty, v_prev_rate, v_prev_value, v_actual, v_adjust);
      v_count := v_count + 1;
    end if;
  end loop;

  if v_count = 0 then
    raise exception using errcode = 'P0001', message = 'reco_empty: None of the items have any change in quantity or value';
  end if;

  select jsonb_agg(jsonb_build_object(
           'item_id', s.item_id,
           'warehouse_id', s.warehouse_id,
           'company_id', h.company_id,
           'actual_qty', s.actual_qty,
           'incoming_rate', s.rate,
           'posting_date', h.posting_date,
           'posting_time', to_char(h.posting_time, 'HH24:MI:SS'),
           'voucher_type', 'Stock Reconciliation',
           'voucher_id', h.id,
           'voucher_no', h.name,
           'voucher_detail_id', s.id,
           'expense_account_id', v_expense,
           'cost_center_id', h.cost_center_id,
           'is_opening', h.purpose = 'Opening Stock',
           'is_adjustment_entry', s.is_adjustment
         ))
    into v_entries
    from _reco s;
  perform app.make_sl_entries(v_entries, '{}'::jsonb);

  perform set_config('app.reco_freeze', '1', true);
  update public.stock_reconciliation_item d
     set current_qty = s.prev_qty,
         current_valuation_rate = s.prev_rate,
         current_amount = s.prev_value,
         quantity_difference = s.actual_qty,
         amount_difference = sle.stock_value_difference,
         qty = case when s.is_adjustment then s.prev_qty else d.qty end
    from _reco s
    join public.stock_ledger_entry sle
      on sle.voucher_detail_id = s.id and sle.voucher_id = h.id and not sle.is_cancelled
   where d.id = s.id;
  update public.stock_reconciliation_item d
     set quantity_difference = 0,
         amount_difference = 0
   where d.parent_id = p_id
     and not exists (select 1 from _reco s where s.id = d.id);
  perform set_config('app.reco_freeze', '', true);

  update public.stock_reconciliation
     set difference_amount = (
       select coalesce(sum(d.amount_difference), 0)
         from public.stock_reconciliation_item d
        where d.parent_id = p_id
     )
   where id = p_id;
end;
$$;

create or replace function app.on_cancel__stock_reconciliation(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entries jsonb;
begin
  if not exists (select 1 from public.stock_reconciliation where id = p_id) then
    raise exception using errcode = 'P0001', message = 'not_found: Stock Reconciliation not found';
  end if;
  select jsonb_agg(jsonb_build_object(
           'item_id', s.item_id,
           'warehouse_id', s.warehouse_id,
           'company_id', s.company_id,
           'actual_qty', s.actual_qty,
           'incoming_rate', s.incoming_rate,
           'posting_date', s.posting_date,
           'posting_time', to_char(s.posting_time, 'HH24:MI:SS'),
           'voucher_type', s.voucher_type,
           'voucher_id', s.voucher_id,
           'voucher_no', s.voucher_no,
           'voucher_detail_id', s.voucher_detail_id,
           'expense_account_id', s.expense_account_id,
           'cost_center_id', s.cost_center_id,
           'is_opening', s.is_opening,
           'is_adjustment_entry', s.is_adjustment_entry
         ) order by s.creation_order desc)
    into v_entries
    from public.stock_ledger_entry s
   where s.voucher_type = 'Stock Reconciliation' and s.voucher_id = p_id and not s.is_cancelled;
  if v_entries is not null then
    perform app.make_sl_entries(v_entries, '{"is_cancelled": true}'::jsonb);
  end if;
end;
$$;

revoke execute on function
  app.stock_reconciliation_validate(), app.stock_reconciliation_item_validate(),
  app.on_submit__stock_reconciliation(uuid), app.on_cancel__stock_reconciliation(uuid)
from public, anon, authenticated;

drop trigger if exists stock_reconciliation_validate on public.stock_reconciliation;
create trigger stock_reconciliation_validate before insert or update on public.stock_reconciliation
  for each row execute function app.stock_reconciliation_validate();
drop trigger if exists touch_updated on public.stock_reconciliation;
create trigger touch_updated before update on public.stock_reconciliation
  for each row execute function app.touch_updated();
drop trigger if exists stock_reconciliation_item_validate on public.stock_reconciliation_item;
create trigger stock_reconciliation_item_validate before insert or update on public.stock_reconciliation_item
  for each row execute function app.stock_reconciliation_item_validate();

alter table public.stock_reconciliation enable row level security;
alter table public.stock_reconciliation force row level security;
alter table public.stock_reconciliation_item enable row level security;
alter table public.stock_reconciliation_item force row level security;

drop policy if exists stock_reconciliation_select on public.stock_reconciliation;
create policy stock_reconciliation_select on public.stock_reconciliation for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'read'))::uuid[]));
drop policy if exists stock_reconciliation_insert on public.stock_reconciliation;
create policy stock_reconciliation_insert on public.stock_reconciliation for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'create'))::uuid[]));
drop policy if exists stock_reconciliation_update on public.stock_reconciliation;
create policy stock_reconciliation_update on public.stock_reconciliation for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'write'))::uuid[]));
drop policy if exists stock_reconciliation_delete on public.stock_reconciliation;
create policy stock_reconciliation_delete on public.stock_reconciliation for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists stock_reconciliation_item_select on public.stock_reconciliation_item;
create policy stock_reconciliation_item_select on public.stock_reconciliation_item for select to authenticated
  using (exists (select 1 from public.stock_reconciliation p where p.id = parent_id));
drop policy if exists stock_reconciliation_item_insert on public.stock_reconciliation_item;
create policy stock_reconciliation_item_insert on public.stock_reconciliation_item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'create'))::uuid[]));
drop policy if exists stock_reconciliation_item_update on public.stock_reconciliation_item;
create policy stock_reconciliation_item_update on public.stock_reconciliation_item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'write'))::uuid[]));
drop policy if exists stock_reconciliation_item_delete on public.stock_reconciliation_item;
create policy stock_reconciliation_item_delete on public.stock_reconciliation_item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Reconciliation', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default
) values (
  'Stock Reconciliation', 'stock_reconciliation', 'stock', true, 'name', 'MAT-RECO-.YYYY.-'
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Stock Reconciliation Item', 'stock_reconciliation_item', 'stock', true, 'Stock Reconciliation', 'items')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Stock Reconciliation', true, false, false, false, false, false, false),
  ('Stock Manager', 'Stock Reconciliation', true, true, true, true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
