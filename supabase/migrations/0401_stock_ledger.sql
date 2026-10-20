-- 0401 stock: Stock Ledger Entry, Bin, and make_sl_entries.
-- ERPNext: erpnext/stock/stock_ledger.py make_sl_entries, update_entries_after.
-- docs/architecture/03-posting-engine.md, docs/modules/04-stock.md §2.9, §2.10, §3.2.
-- Perpetual inventory GL is the next line. A repost recomputes later stock rows and does not post GL.
-- The outward rate stays on the stock ledger row until a voucher table exists.

create table if not exists public.stock_ledger_entry (
  id                        uuid primary key default gen_random_uuid(),
  org_id                    uuid not null references public.organizations (id) on delete cascade,
  company_id                uuid not null,
  item_id                   uuid not null,
  warehouse_id              uuid not null,
  posting_date              date not null,
  posting_time              time not null,
  posting_datetime          timestamptz not null,
  voucher_type              text not null,
  voucher_id                uuid not null,
  voucher_no                text not null,
  voucher_detail_id         uuid,
  actual_qty                numeric(21,9) not null,
  qty_after_transaction     numeric(21,9) not null default 0,
  incoming_rate             numeric(21,9) not null default 0,
  outgoing_rate             numeric(21,9) not null default 0,
  valuation_rate            numeric(21,9) not null default 0,
  stock_value               numeric(21,9) not null default 0,
  stock_value_difference    numeric(21,9) not null default 0,
  stock_queue               jsonb not null default '[]'::jsonb,
  stock_uom_id              uuid not null,
  serial_and_batch_bundle_id uuid,
  batch_id                  uuid,
  has_serial_no             boolean not null default false,
  has_batch_no              boolean not null default false,
  fiscal_year_id            uuid,
  project_id                uuid,
  is_cancelled              boolean not null default false,
  is_adjustment_entry       boolean not null default false,
  creation_order            bigserial,
  created_at                timestamptz not null default now(),
  unique (org_id, id),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id),
  foreign key (org_id, fiscal_year_id) references public.fiscal_year (org_id, id),
  check (actual_qty <> 0)
);

create index if not exists sle_chain_idx
  on public.stock_ledger_entry (org_id, item_id, warehouse_id, posting_datetime, creation_order);
create index if not exists sle_voucher_idx on public.stock_ledger_entry (org_id, voucher_type, voucher_id);
create index if not exists sle_company_idx on public.stock_ledger_entry (org_id, company_id);
create index if not exists sle_warehouse_idx on public.stock_ledger_entry (org_id, warehouse_id);
create index if not exists sle_uom_idx on public.stock_ledger_entry (org_id, stock_uom_id);
create index if not exists sle_fiscal_year_idx on public.stock_ledger_entry (org_id, fiscal_year_id);

create table if not exists public.bin (
  id                                  uuid primary key default gen_random_uuid(),
  org_id                              uuid not null references public.organizations (id) on delete cascade,
  item_id                             uuid not null,
  warehouse_id                        uuid not null,
  actual_qty                          numeric(21,9) not null default 0,
  reserved_qty                        numeric(21,9) not null default 0,
  ordered_qty                         numeric(21,9) not null default 0,
  indented_qty                        numeric(21,9) not null default 0,
  planned_qty                         numeric(21,9) not null default 0,
  reserved_qty_for_production         numeric(21,9) not null default 0,
  reserved_qty_for_sub_contract       numeric(21,9) not null default 0,
  reserved_qty_for_production_plan    numeric(21,9) not null default 0,
  projected_qty                       numeric(21,9) not null default 0,
  valuation_rate                      numeric(21,9) not null default 0,
  stock_value                         numeric(21,9) not null default 0,
  stock_uom_id                        uuid,
  created_at                          timestamptz not null default now(),
  updated_at                          timestamptz not null default now(),
  unique (org_id, id),
  unique (org_id, item_id, warehouse_id),
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id) on delete set null (stock_uom_id)
);

create index if not exists bin_warehouse_idx on public.bin (org_id, warehouse_id);
create index if not exists bin_uom_idx on public.bin (org_id, stock_uom_id);

drop trigger if exists touch_updated on public.bin;
create trigger touch_updated before update on public.bin
  for each row execute function app.touch_updated();

-- Clients cannot change a stock ledger row. make_sl_entries sets app.sl_write for the cancel
-- flag and for the valuation columns a synchronous repost rewrites.
create or replace function app.stock_ledger_entry_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = 'P0001', message = 'ledger_append_only: Stock Ledger rows cannot be deleted';
  end if;
  if current_setting('app.sl_write', true) is distinct from '1' then
    raise exception using errcode = 'P0001', message = 'ledger_append_only: Stock Ledger rows cannot be changed';
  end if;
  return new;
end;
$$;

create or replace function app.bin_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = 'P0001', message = 'bin_derived: Bin rows cannot be deleted';
  end if;
  if current_setting('app.sl_write', true) is distinct from '1' then
    raise exception using errcode = 'P0001', message = 'bin_derived: Bin is recomputed from the stock ledger';
  end if;
  return new;
end;
$$;

revoke execute on function app.stock_ledger_entry_guard(), app.bin_guard() from public, anon, authenticated;

drop trigger if exists stock_ledger_entry_guard on public.stock_ledger_entry;
create trigger stock_ledger_entry_guard before update or delete on public.stock_ledger_entry
  for each row execute function app.stock_ledger_entry_guard();
drop trigger if exists bin_guard on public.bin;
create trigger bin_guard before update or delete on public.bin
  for each row execute function app.bin_guard();

alter table public.stock_ledger_entry enable row level security;
alter table public.stock_ledger_entry force row level security;
alter table public.bin enable row level security;
alter table public.bin force row level security;

drop policy if exists stock_ledger_entry_select on public.stock_ledger_entry;
create policy stock_ledger_entry_select on public.stock_ledger_entry for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));
drop policy if exists bin_select on public.bin;
create policy bin_select on public.bin for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Recompute every open stock ledger row for one item and warehouse from p_from forward.
------------------------------------------------------------------------------------------------------------------------

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

  perform set_config('app.sl_write', '1', true);
  for r in
    select id, actual_qty, incoming_rate
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
  end loop;
  perform set_config('app.sl_write', '', true);
exception
  when others then
    perform set_config('app.sl_write', '', true);
    raise;
end;
$$;

create or replace function app.update_bin_qty(p_item uuid, p_warehouse uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_qty numeric := 0;
  v_rate numeric := 0;
  v_value numeric := 0;
  v_uom uuid;
begin
  select org_id into v_org from public.item where id = p_item;
  select qty_after_transaction, valuation_rate, stock_value, stock_uom_id
    into v_qty, v_rate, v_value, v_uom
    from public.stock_ledger_entry
   where item_id = p_item and warehouse_id = p_warehouse and not is_cancelled
   order by posting_datetime desc, creation_order desc
   limit 1;
  v_qty := coalesce(v_qty, 0);
  v_rate := coalesce(v_rate, 0);
  v_value := coalesce(v_value, 0);

  perform set_config('app.sl_write', '1', true);
  insert into public.bin (
    org_id, item_id, warehouse_id, actual_qty, valuation_rate, stock_value, stock_uom_id, projected_qty
  ) values (
    v_org, p_item, p_warehouse, v_qty, v_rate, v_value, v_uom, v_qty
  )
  on conflict (org_id, item_id, warehouse_id) do update
    set actual_qty = excluded.actual_qty,
        valuation_rate = excluded.valuation_rate,
        stock_value = excluded.stock_value,
        stock_uom_id = excluded.stock_uom_id,
        projected_qty = excluded.actual_qty
          + bin.ordered_qty + bin.indented_qty + bin.planned_qty
          - bin.reserved_qty - bin.reserved_qty_for_production
          - bin.reserved_qty_for_sub_contract - bin.reserved_qty_for_production_plan;
  perform set_config('app.sl_write', '', true);
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
begin
  if jsonb_typeof(p_entries) is distinct from 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception using errcode = 'P0001', message = 'sl_entries: At least one stock ledger entry is required';
  end if;

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
        project_id, is_cancelled, is_adjustment_entry
      ) values (
        orig.org_id, orig.company_id, orig.item_id, orig.warehouse_id, orig.posting_date, orig.posting_time,
        orig.posting_datetime, orig.voucher_type, orig.voucher_id, orig.voucher_no, orig.voucher_detail_id,
        -orig.actual_qty, orig.qty_after_transaction - orig.actual_qty, orig.incoming_rate, orig.outgoing_rate,
        orig.valuation_rate, orig.stock_value, -orig.stock_value_difference, orig.stock_queue, orig.stock_uom_id,
        orig.serial_and_batch_bundle_id, orig.batch_id, orig.has_serial_no, orig.has_batch_no, orig.fiscal_year_id,
        orig.project_id, true, orig.is_adjustment_entry
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
        fiscal_year_id, project_id, is_adjustment_entry
      ) values (
        v_org, v_company, v_item, v_wh, v_date, v_time, v_at,
        e ->> 'voucher_type', v_voucher, e ->> 'voucher_no', v_detail, v_qty,
        case when v_qty > 0 then v_rate else 0 end,
        v_uom, nullif(e ->> 'serial_and_batch_bundle_id', '')::uuid, nullif(e ->> 'batch_id', '')::uuid,
        v_serial, v_batch, v_fy, nullif(e ->> 'project_id', '')::uuid,
        coalesce((e ->> 'is_adjustment_entry')::boolean, false)
      );
      perform app.repost_item_valuation(v_item, v_wh, v_at);
    end if;

    perform app.update_bin_qty(v_item, v_wh);
  end loop;
end;
$$;

revoke execute on function app.repost_item_valuation(uuid, uuid, timestamptz) from public, anon;
revoke execute on function app.update_bin_qty(uuid, uuid) from public, anon;
revoke execute on function app.make_sl_entries(jsonb, jsonb) from public, anon;
grant execute on function app.repost_item_valuation(uuid, uuid, timestamptz) to authenticated;
grant execute on function app.update_bin_qty(uuid, uuid) to authenticated;
grant execute on function app.make_sl_entries(jsonb, jsonb) to authenticated;
