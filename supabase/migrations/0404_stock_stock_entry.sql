-- 0404 stock: Stock Entry for the eight seeded purposes (docs/modules/04-stock.md §2.11, §4).
-- ERPNext: erpnext/stock/doctype/stock_entry/stock_entry.json, stock_entry.py.
-- Submit posts stock through app.make_sl_entries (outward first, so a transfer can
-- copy the valued outgoing rate) and posts additional cost as its own GL pair.
-- Material Request qty, work orders, BOM explosion, and serial/batch checks stay later lines.

create table if not exists public.stock_entry (
  id                        uuid primary key default gen_random_uuid(),
  org_id                    uuid not null references public.organizations (id) on delete cascade,
  name                      text not null,
  title                     text,
  naming_series             text not null default 'MAT-STE-.YYYY.-',
  stock_entry_type_id       uuid not null,
  purpose                   text not null,
  company_id                uuid not null,
  posting_date              date not null default current_date,
  posting_time              time not null default localtime,
  set_posting_time          boolean not null default false,
  from_warehouse_id         uuid,
  to_warehouse_id           uuid,
  add_to_transit            boolean not null default false,
  total_outgoing_value      numeric(21,9) not null default 0,
  total_incoming_value      numeric(21,9) not null default 0,
  value_difference          numeric(21,9) not null default 0,
  is_opening                text not null default 'No' check (is_opening in ('No', 'Yes')),
  remarks                   text,
  project                   text,
  cost_center_id            uuid,
  bom_no                    text,
  fg_completed_qty          numeric(21,9) not null default 0,
  use_multi_level_bom       boolean not null default true,
  work_order_id             uuid,
  outgoing_stock_entry_id   uuid,
  docstatus                 smallint not null default 0 check (docstatus in (0, 1, 2)),
  amended_from              uuid,
  created_at                timestamptz not null default now(),
  created_by                uuid default auth.uid(),
  updated_at                timestamptz not null default now(),
  updated_by                uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, stock_entry_type_id) references public.stock_entry_type (org_id, id),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, from_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, to_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  foreign key (org_id, amended_from) references public.stock_entry (org_id, id) on delete set null (amended_from),
  foreign key (org_id, outgoing_stock_entry_id) references public.stock_entry (org_id, id) on delete set null (outgoing_stock_entry_id)
);

create index if not exists stock_entry_type_idx on public.stock_entry (org_id, stock_entry_type_id);
create index if not exists stock_entry_company_idx on public.stock_entry (org_id, company_id);
create index if not exists stock_entry_from_wh_idx on public.stock_entry (org_id, from_warehouse_id);
create index if not exists stock_entry_to_wh_idx on public.stock_entry (org_id, to_warehouse_id);
create index if not exists stock_entry_cost_center_idx on public.stock_entry (org_id, cost_center_id);
create index if not exists stock_entry_outgoing_idx on public.stock_entry (org_id, outgoing_stock_entry_id);
create index if not exists stock_entry_amended_idx on public.stock_entry (org_id, amended_from);
create index if not exists stock_entry_posting_idx on public.stock_entry (org_id, posting_date);

create table if not exists public.stock_entry_detail (
  id                          uuid primary key default gen_random_uuid(),
  org_id                      uuid not null,
  parent_id                   uuid not null,
  idx                         int not null,
  item_id                     uuid not null,
  qty                         numeric(21,9) not null,
  uom_id                      uuid not null,
  conversion_factor           numeric(21,9) not null default 1,
  transfer_qty                numeric(21,9) not null default 0,
  s_warehouse_id              uuid,
  t_warehouse_id              uuid,
  basic_rate                  numeric(21,9) not null default 0,
  basic_amount                numeric(21,9) not null default 0,
  additional_cost             numeric(21,9) not null default 0,
  valuation_rate              numeric(21,9) not null default 0,
  amount                      numeric(21,9) not null default 0,
  expense_account_id          uuid,
  cost_center_id              uuid,
  allow_zero_valuation_rate   boolean not null default false,
  material_request_id         uuid,
  material_request_item       uuid,
  serial_and_batch_bundle     text,
  batch_no                    text,
  serial_no                   text,
  use_serial_batch_fields     boolean not null default false,
  is_finished_item            boolean not null default false,
  per_transferred             numeric(21,9) not null default 0,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.stock_entry (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, uom_id) references public.uom (org_id, id),
  foreign key (org_id, s_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, t_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, expense_account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id)
);

create index if not exists stock_entry_detail_parent_idx on public.stock_entry_detail (org_id, parent_id);
create index if not exists stock_entry_detail_item_idx on public.stock_entry_detail (org_id, item_id);
create index if not exists stock_entry_detail_uom_idx on public.stock_entry_detail (org_id, uom_id);
create index if not exists stock_entry_detail_s_wh_idx on public.stock_entry_detail (org_id, s_warehouse_id);
create index if not exists stock_entry_detail_t_wh_idx on public.stock_entry_detail (org_id, t_warehouse_id);
create index if not exists stock_entry_detail_expense_idx on public.stock_entry_detail (org_id, expense_account_id);
create index if not exists stock_entry_detail_cost_center_idx on public.stock_entry_detail (org_id, cost_center_id);

create table if not exists public.stock_entry_additional_cost (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null,
  parent_id           uuid not null,
  idx                 int not null,
  expense_account_id  uuid not null,
  description         text,
  amount              numeric(21,9) not null default 0,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.stock_entry (org_id, id) on delete cascade,
  foreign key (org_id, expense_account_id) references public.account (org_id, id)
);

create index if not exists stock_entry_additional_cost_parent_idx on public.stock_entry_additional_cost (org_id, parent_id);
create index if not exists stock_entry_additional_cost_account_idx on public.stock_entry_additional_cost (org_id, expense_account_id);

create or replace function app.stock_entry_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_purpose text;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
  end if;
  if new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'MAT-STE-.YYYY.-';
  end if;
  if new.posting_date is null then
    new.posting_date := current_date;
  end if;
  if new.posting_time is null or (tg_op = 'INSERT' and not new.set_posting_time) then
    new.posting_time := localtime;
  end if;
  select t.purpose into v_purpose
    from public.stock_entry_type t
   where t.id = new.stock_entry_type_id and t.org_id = new.org_id;
  if v_purpose is null then
    raise exception using errcode = 'P0001', message = 'ste_type: Stock Entry Type is required';
  end if;
  new.purpose := v_purpose;
  new.title := v_purpose;
  if new.is_opening = 'Yes' and new.purpose <> 'Material Receipt' then
    raise exception using errcode = 'P0001', message = 'ste_opening: Opening Stock Entry must be a Material Receipt';
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

create or replace function app.stock_entry_detail_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_from uuid;
  v_to uuid;
  v_stock boolean;
begin
  if new.qty is null or new.qty <= 0 or coalesce(new.conversion_factor, 0) < 0 then
    raise exception using errcode = 'P0001',
      message = format('ste_qty: Row %s: Quantity must be greater than zero', new.idx);
  end if;
  if new.conversion_factor is null or new.conversion_factor = 0 then
    new.conversion_factor := 1;
  end if;
  select i.is_stock_item into v_stock
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001', message = format('ste_item: Row %s: Item is required', new.idx);
  end if;
  if v_stock is not true then
    raise exception using errcode = 'P0001', message = format('ste_item: Row %s: Item is not a stock item', new.idx);
  end if;
  if new.uom_id is null then
    select i.stock_uom_id into new.uom_id from public.item i where i.id = new.item_id;
  end if;
  if new.uom_id is null then
    raise exception using errcode = 'P0001', message = format('ste_uom: Row %s: UOM is required', new.idx);
  end if;
  select e.from_warehouse_id, e.to_warehouse_id into v_from, v_to
    from public.stock_entry e
   where e.id = new.parent_id;
  if new.s_warehouse_id is null then
    new.s_warehouse_id := v_from;
  end if;
  if new.t_warehouse_id is null then
    new.t_warehouse_id := v_to;
  end if;
  new.transfer_qty := new.qty * new.conversion_factor;
  new.basic_rate := coalesce(new.basic_rate, 0);
  new.additional_cost := coalesce(new.additional_cost, 0);
  new.basic_amount := app.round(new.transfer_qty * new.basic_rate, 2);
  new.amount := app.round(new.basic_amount + new.additional_cost, 2);
  new.valuation_rate := case when new.transfer_qty = 0 then 0 else new.amount / new.transfer_qty end;
  new.per_transferred := coalesce(new.per_transferred, 0);
  return new;
end;
$$;

create or replace function app.stock_entry_additional_cost_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.expense_account_id is null then
    raise exception using errcode = 'P0001',
      message = format('ste_cost: Row %s: Additional cost account is required', new.idx);
  end if;
  if coalesce(new.amount, 0) < 0 then
    raise exception using errcode = 'P0001',
      message = format('ste_cost: Row %s: Additional cost amount cannot be negative', new.idx);
  end if;
  new.amount := coalesce(new.amount, 0);
  return new;
end;
$$;

create or replace function app.on_submit__stock_entry(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.stock_entry;
  r record;
  src record;
  v_transit uuid;
  v_entries jsonb;
  v_add numeric := 0;
  v_source numeric := 0;
  v_scrap numeric := 0;
  v_pool numeric := 0;
  v_denom numeric := 0;
  v_qty_sum numeric := 0;
  v_left numeric := 0;
  v_add_left numeric := 0;
  v_share numeric := 0;
  v_add_share numeric := 0;
  v_weight numeric := 0;
  v_div numeric := 0;
  v_n int := 0;
  v_i int := 0;
  v_flagged boolean := false;
  v_perpetual boolean := false;
  v_adj uuid;
  v_out numeric := 0;
  v_in numeric := 0;
  v_gl jsonb;
  v_take numeric;
  v_src_status int;
begin
  select * into h from public.stock_entry where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Stock Entry not found';
  end if;
  if not exists (select 1 from public.stock_entry_detail d where d.parent_id = p_id) then
    raise exception using errcode = 'P0001', message = 'ste_items: Items table cannot be blank';
  end if;

  update public.stock_entry_detail d
     set s_warehouse_id = coalesce(d.s_warehouse_id, h.from_warehouse_id),
         t_warehouse_id = coalesce(d.t_warehouse_id, h.to_warehouse_id)
   where d.parent_id = p_id;

  if h.add_to_transit then
    if h.purpose <> 'Material Transfer' then
      raise exception using errcode = 'P0001', message = 'ste_transit: Add to Transit is only for Material Transfer';
    end if;
    select w.id into v_transit
      from public.warehouse w
      left join public.warehouse_type t on t.id = w.warehouse_type_id and t.org_id = w.org_id
     where w.org_id = h.org_id and w.company_id = h.company_id
       and not w.is_group and not w.disabled
       and (t.name = 'Transit' or w.warehouse_name = 'Goods In Transit')
     order by case when t.name = 'Transit' then 0 else 1 end, w.warehouse_name
     limit 1;
    if v_transit is null then
      raise exception using errcode = 'P0001', message = 'ste_transit: Goods In Transit warehouse is required';
    end if;
    update public.stock_entry_detail set t_warehouse_id = v_transit where parent_id = p_id;
  end if;

  if h.purpose = 'Material Receipt' then
    if exists (
      select 1 from public.stock_entry_detail d
       where d.parent_id = p_id and (d.s_warehouse_id is not null or d.t_warehouse_id is null)
    ) then
      raise exception using errcode = 'P0001', message = 'ste_warehouse: Material Receipt needs a target warehouse only';
    end if;
  elsif h.purpose = 'Material Issue' then
    if exists (
      select 1 from public.stock_entry_detail d
       where d.parent_id = p_id and (d.s_warehouse_id is null or d.t_warehouse_id is not null)
    ) then
      raise exception using errcode = 'P0001', message = 'ste_warehouse: Material Issue needs a source warehouse only';
    end if;
  elsif h.purpose = 'Material Consumption for Manufacture' then
    if exists (
      select 1 from public.stock_entry_detail d
       where d.parent_id = p_id and (d.s_warehouse_id is null or d.t_warehouse_id is not null)
    ) then
      raise exception using errcode = 'P0001',
        message = 'ste_warehouse: Material Consumption for Manufacture needs a source warehouse only';
    end if;
  elsif h.purpose in ('Material Transfer', 'Material Transfer for Manufacture', 'Send to Subcontractor') then
    if exists (
      select 1 from public.stock_entry_detail d
       where d.parent_id = p_id
         and (d.s_warehouse_id is null or d.t_warehouse_id is null or d.s_warehouse_id = d.t_warehouse_id)
    ) then
      raise exception using errcode = 'P0001',
        message = format('ste_warehouse: %s needs a source and a different target warehouse', h.purpose);
    end if;
  elsif h.purpose in ('Manufacture', 'Repack') then
    if exists (
      select 1 from public.stock_entry_detail d
       where d.parent_id = p_id
         and ((d.s_warehouse_id is null and d.t_warehouse_id is null)
           or (d.s_warehouse_id is not null and d.t_warehouse_id is not null))
    ) or not exists (
      select 1 from public.stock_entry_detail d where d.parent_id = p_id and d.s_warehouse_id is not null
    ) or not exists (
      select 1 from public.stock_entry_detail d where d.parent_id = p_id and d.t_warehouse_id is not null
    ) then
      raise exception using errcode = 'P0001',
        message = format('ste_warehouse: %s needs an outgoing row and an incoming row', h.purpose);
    end if;
  else
    raise exception using errcode = 'P0001',
      message = format('ste_purpose: Purpose %s cannot be submitted', h.purpose);
  end if;

  if h.is_opening = 'Yes' and exists (
    select 1 from public.stock_entry_additional_cost a where a.parent_id = p_id and a.amount <> 0
  ) then
    raise exception using errcode = 'P0001',
      message = 'ste_opening_cost: Additional costs are not allowed on an opening Stock Entry';
  end if;

  if h.outgoing_stock_entry_id is not null then
    if h.purpose not in ('Material Transfer', 'Material Transfer for Manufacture', 'Send to Subcontractor') then
      raise exception using errcode = 'P0001', message = 'ste_transit: Only a transfer can receive from transit';
    end if;
    select e.docstatus into v_src_status from public.stock_entry e where e.id = h.outgoing_stock_entry_id;
    if v_src_status is distinct from 1 then
      raise exception using errcode = 'P0001', message = 'ste_transit: The outgoing Stock Entry must be submitted';
    end if;
  end if;

  drop table if exists pg_temp._ste;
  create temp table _ste (
    id uuid primary key,
    idx int,
    item_id uuid,
    transfer_qty numeric,
    s_warehouse_id uuid,
    t_warehouse_id uuid,
    basic_rate numeric,
    user_rate numeric,
    additional_cost numeric,
    expense_account_id uuid,
    cost_center_id uuid,
    allow_zero boolean,
    is_finished_item boolean
  ) on commit drop;

  insert into _ste
  select d.id, d.idx, d.item_id, d.transfer_qty, d.s_warehouse_id, d.t_warehouse_id,
         coalesce(d.basic_rate, 0), coalesce(d.basic_rate, 0), 0,
         d.expense_account_id, coalesce(d.cost_center_id, h.cost_center_id),
         d.allow_zero_valuation_rate, d.is_finished_item
    from public.stock_entry_detail d
   where d.parent_id = p_id;

  select jsonb_agg(jsonb_build_object(
           'item_id', s.item_id,
           'warehouse_id', s.s_warehouse_id,
           'company_id', h.company_id,
           'actual_qty', -s.transfer_qty,
           'incoming_rate', 0,
           'posting_date', h.posting_date,
           'posting_time', to_char(h.posting_time, 'HH24:MI:SS'),
           'voucher_type', 'Stock Entry',
           'voucher_id', h.id,
           'voucher_no', h.name,
           'voucher_detail_id', s.id,
           'expense_account_id', s.expense_account_id,
           'cost_center_id', s.cost_center_id,
           'is_opening', h.is_opening = 'Yes'
         ) order by s.idx)
    into v_entries
    from _ste s
   where s.s_warehouse_id is not null;
  if v_entries is not null then
    perform app.make_sl_entries(v_entries, '{}'::jsonb);
  end if;

  update _ste s
     set basic_rate = coalesce(sle.outgoing_rate, 0)
    from (
      select distinct on (voucher_detail_id, warehouse_id)
             voucher_detail_id, warehouse_id, outgoing_rate
        from public.stock_ledger_entry
       where voucher_type = 'Stock Entry' and voucher_id = p_id and not is_cancelled and actual_qty < 0
       order by voucher_detail_id, warehouse_id, creation_order desc
    ) sle
   where sle.voucher_detail_id = s.id and sle.warehouse_id = s.s_warehouse_id;

  update _ste s
     set basic_rate = coalesce((
           select coalesce(nullif(i.valuation_rate, 0), nullif(i.last_purchase_rate, 0), nullif(i.standard_rate, 0))
             from public.item i
            where i.id = s.item_id
         ), 0)
   where s.t_warehouse_id is not null and s.s_warehouse_id is null and s.basic_rate = 0;

  v_add := coalesce((select sum(a.amount) from public.stock_entry_additional_cost a where a.parent_id = p_id), 0);

  if h.purpose in ('Manufacture', 'Repack') then
    v_flagged := exists (
      select 1 from _ste s
       where s.t_warehouse_id is not null and s.s_warehouse_id is null and s.is_finished_item
    );
    select coalesce(sum(app.round(s.transfer_qty * s.basic_rate, 2)), 0) into v_source
      from _ste s where s.s_warehouse_id is not null;
    select coalesce(sum(app.round(s.transfer_qty * s.basic_rate, 2)), 0) into v_scrap
      from _ste s
     where s.t_warehouse_id is not null and s.s_warehouse_id is null
       and (v_flagged and not s.is_finished_item);
    v_pool := v_source + v_add - v_scrap;
    if v_pool < 0 then
      raise exception using errcode = 'P0001', message = 'ste_rate: Finished goods value cannot be negative';
    end if;
    select count(*)::int,
           coalesce(sum(s.transfer_qty * s.user_rate), 0),
           coalesce(sum(s.transfer_qty), 0)
      into v_n, v_denom, v_qty_sum
      from _ste s
     where s.t_warehouse_id is not null and s.s_warehouse_id is null
       and (not v_flagged or s.is_finished_item);
    v_left := v_pool;
    v_add_left := v_add;
    v_i := 0;
    for r in
      select * from _ste s
       where s.t_warehouse_id is not null and s.s_warehouse_id is null
         and (not v_flagged or s.is_finished_item)
       order by s.idx
    loop
      v_i := v_i + 1;
      if v_i = v_n then
        v_share := v_left;
        v_add_share := v_add_left;
      else
        v_div := case when v_denom = 0 then v_qty_sum else v_denom end;
        v_weight := case when v_denom = 0 then r.transfer_qty else r.transfer_qty * r.user_rate end;
        v_share := app.round(v_pool * v_weight / v_div, 2);
        v_add_share := app.round(v_add * v_weight / v_div, 2);
        v_left := v_left - v_share;
        v_add_left := v_add_left - v_add_share;
      end if;
      update _ste
         set basic_rate = case when r.transfer_qty = 0 then 0 else (v_share - v_add_share) / r.transfer_qty end,
             additional_cost = v_add_share
       where id = r.id;
    end loop;
  else
    if v_add <> 0 and not exists (select 1 from _ste s where s.t_warehouse_id is not null) then
      raise exception using errcode = 'P0001', message = 'ste_cost: Additional costs need an incoming row';
    end if;
    select count(*)::int,
           coalesce(sum(app.round(s.transfer_qty * s.basic_rate, 2)), 0),
           coalesce(sum(s.transfer_qty), 0)
      into v_n, v_denom, v_qty_sum
      from _ste s
     where s.t_warehouse_id is not null;
    v_left := v_add;
    v_i := 0;
    for r in select * from _ste s where s.t_warehouse_id is not null order by s.idx loop
      v_i := v_i + 1;
      if v_i = v_n then
        v_share := v_left;
      else
        v_div := case when v_denom = 0 then v_qty_sum else v_denom end;
        v_weight := case when v_denom = 0 then r.transfer_qty else app.round(r.transfer_qty * r.basic_rate, 2) end;
        v_share := app.round(v_add * v_weight / v_div, 2);
        v_left := v_left - v_share;
      end if;
      update _ste set additional_cost = v_share where id = r.id;
    end loop;
  end if;

  for r in select * from _ste s where s.t_warehouse_id is not null loop
    if r.transfer_qty = 0
       or (app.round((r.transfer_qty * r.basic_rate + r.additional_cost) / nullif(r.transfer_qty, 0), 2) = 0
           and not r.allow_zero) then
      raise exception using errcode = 'P0001', message = 'ste_rate: Valuation rate cannot be zero';
    end if;
  end loop;

  update public.stock_entry_detail d
     set basic_rate = s.basic_rate,
         additional_cost = s.additional_cost
    from _ste s
   where d.id = s.id;

  select jsonb_agg(jsonb_build_object(
           'item_id', d.item_id,
           'warehouse_id', d.t_warehouse_id,
           'company_id', h.company_id,
           'actual_qty', d.transfer_qty,
           'incoming_rate', d.valuation_rate,
           'posting_date', h.posting_date,
           'posting_time', to_char(h.posting_time, 'HH24:MI:SS'),
           'voucher_type', 'Stock Entry',
           'voucher_id', h.id,
           'voucher_no', h.name,
           'voucher_detail_id', d.id,
           'expense_account_id', d.expense_account_id,
           'cost_center_id', coalesce(d.cost_center_id, h.cost_center_id),
           'is_opening', h.is_opening = 'Yes'
         ) order by d.idx)
    into v_entries
    from public.stock_entry_detail d
   where d.parent_id = p_id and d.t_warehouse_id is not null;
  if v_entries is not null then
    perform app.make_sl_entries(v_entries, '{}'::jsonb);
  end if;

  select coalesce(sum(d.basic_amount), 0) into v_out
    from public.stock_entry_detail d
   where d.parent_id = p_id and d.s_warehouse_id is not null;
  select coalesce(sum(d.amount), 0) into v_in
    from public.stock_entry_detail d
   where d.parent_id = p_id and d.t_warehouse_id is not null;
  update public.stock_entry
     set total_outgoing_value = v_out,
         total_incoming_value = v_in,
         value_difference = v_in - v_out
   where id = p_id;

  select c.enable_perpetual_inventory, c.stock_adjustment_account_id
    into v_perpetual, v_adj
    from public.companies c
   where c.id = h.company_id;
  if v_add <> 0 and coalesce(v_perpetual, false) then
    if exists (
      select 1 from public.stock_entry_detail d
       where d.parent_id = p_id and d.additional_cost <> 0
         and d.expense_account_id is null and v_adj is null
    ) then
      raise exception using errcode = 'P0001', message = 'ste_cost: Set an expense account for the additional cost';
    end if;
    with nets as (
      select account_id, app.round(sum(debit - credit), 2) as net
        from (
          select coalesce(d.expense_account_id, v_adj) as account_id,
                 d.additional_cost as debit,
                 0::numeric as credit
            from public.stock_entry_detail d
           where d.parent_id = p_id and d.t_warehouse_id is not null and d.additional_cost <> 0
          union all
          select a.expense_account_id, 0::numeric, a.amount
            from public.stock_entry_additional_cost a
           where a.parent_id = p_id and a.amount <> 0
        ) q
       group by account_id
      having app.round(sum(debit - credit), 2) <> 0
    )
    select count(*)::int,
           jsonb_agg(jsonb_build_object(
             'company_id', h.company_id,
             'posting_date', h.posting_date,
             'account_id', n.account_id,
             'debit', case when n.net > 0 then n.net else 0 end,
             'credit', case when n.net < 0 then -n.net else 0 end,
             'voucher_type', 'Stock Entry',
             'voucher_id', h.id,
             'voucher_no', h.name,
             'remarks', 'Accounting Entry for Stock Additional Cost',
             'is_opening', false,
             'is_system_generated', true
           ))
      into v_n, v_gl
      from nets n;
    if v_n = 1 or (v_n >= 2 and v_gl is null) then
      raise exception using errcode = 'P0001', message = 'ste_cost: Additional cost accounts do not balance';
    end if;
    if coalesce(v_n, 0) >= 2 then
      perform app.make_gl_entries(v_gl, '{"merge": true}'::jsonb);
    end if;
  end if;

  if h.outgoing_stock_entry_id is not null then
    for r in select * from public.stock_entry_detail d where d.parent_id = p_id order by d.idx loop
      v_left := r.transfer_qty;
      for src in
        select d.id, d.transfer_qty, d.per_transferred
          from public.stock_entry_detail d
         where d.parent_id = h.outgoing_stock_entry_id
           and d.item_id = r.item_id
           and d.t_warehouse_id = r.s_warehouse_id
         order by d.idx
      loop
        v_take := least(v_left, src.transfer_qty - src.per_transferred);
        if v_take > 0 then
          update public.stock_entry_detail set per_transferred = per_transferred + v_take where id = src.id;
          v_left := v_left - v_take;
        end if;
        exit when v_left <= 0;
      end loop;
      if v_left > 0 then
        raise exception using errcode = 'P0001', message = 'ste_transit: Over transfer from the outgoing Stock Entry';
      end if;
    end loop;
  end if;
end;
$$;

create or replace function app.on_cancel__stock_entry(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.stock_entry;
  r record;
  src record;
  v_entries jsonb;
  v_left numeric;
  v_take numeric;
begin
  select * into h from public.stock_entry where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Stock Entry not found';
  end if;
  if exists (
    select 1 from public.stock_entry e where e.outgoing_stock_entry_id = p_id and e.docstatus = 1
  ) or exists (
    select 1 from public.stock_entry_detail d where d.parent_id = p_id and d.per_transferred > 0
  ) then
    raise exception using errcode = 'P0001', message = 'ste_transit: Cancel the later transfer first';
  end if;

  select jsonb_agg(jsonb_build_object(
           'item_id', s.item_id,
           'warehouse_id', s.warehouse_id,
           'company_id', s.company_id,
           'actual_qty', s.actual_qty,
           'posting_date', s.posting_date,
           'posting_time', to_char(s.posting_time, 'HH24:MI:SS'),
           'voucher_type', s.voucher_type,
           'voucher_id', s.voucher_id,
           'voucher_no', s.voucher_no,
           'voucher_detail_id', s.voucher_detail_id
         ) order by s.creation_order desc)
    into v_entries
    from public.stock_ledger_entry s
   where s.voucher_type = 'Stock Entry' and s.voucher_id = p_id and not s.is_cancelled;
  if v_entries is not null then
    perform app.make_sl_entries(v_entries, '{"is_cancelled": true}'::jsonb);
  end if;

  if h.outgoing_stock_entry_id is not null then
    for r in select * from public.stock_entry_detail d where d.parent_id = p_id order by d.idx desc loop
      v_left := r.transfer_qty;
      for src in
        select d.id, d.per_transferred
          from public.stock_entry_detail d
         where d.parent_id = h.outgoing_stock_entry_id
           and d.item_id = r.item_id
           and d.t_warehouse_id = r.s_warehouse_id
           and d.per_transferred > 0
         order by d.idx desc
      loop
        v_take := least(v_left, src.per_transferred);
        update public.stock_entry_detail set per_transferred = per_transferred - v_take where id = src.id;
        v_left := v_left - v_take;
        exit when v_left <= 0;
      end loop;
    end loop;
  end if;
end;
$$;

revoke execute on function
  app.stock_entry_validate(), app.stock_entry_detail_validate(), app.stock_entry_additional_cost_validate(),
  app.on_submit__stock_entry(uuid), app.on_cancel__stock_entry(uuid)
from public, anon, authenticated;

drop trigger if exists stock_entry_validate on public.stock_entry;
create trigger stock_entry_validate before insert or update on public.stock_entry
  for each row execute function app.stock_entry_validate();
drop trigger if exists touch_updated on public.stock_entry;
create trigger touch_updated before update on public.stock_entry
  for each row execute function app.touch_updated();
drop trigger if exists stock_entry_detail_validate on public.stock_entry_detail;
create trigger stock_entry_detail_validate before insert or update on public.stock_entry_detail
  for each row execute function app.stock_entry_detail_validate();
drop trigger if exists stock_entry_additional_cost_validate on public.stock_entry_additional_cost;
create trigger stock_entry_additional_cost_validate before insert or update on public.stock_entry_additional_cost
  for each row execute function app.stock_entry_additional_cost_validate();

alter table public.stock_entry enable row level security;
alter table public.stock_entry force row level security;
alter table public.stock_entry_detail enable row level security;
alter table public.stock_entry_detail force row level security;
alter table public.stock_entry_additional_cost enable row level security;
alter table public.stock_entry_additional_cost force row level security;

drop policy if exists stock_entry_select on public.stock_entry;
create policy stock_entry_select on public.stock_entry for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry', 'read'))::uuid[]));
drop policy if exists stock_entry_insert on public.stock_entry;
create policy stock_entry_insert on public.stock_entry for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry', 'create'))::uuid[]));
drop policy if exists stock_entry_update on public.stock_entry;
create policy stock_entry_update on public.stock_entry for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]));
drop policy if exists stock_entry_delete on public.stock_entry;
create policy stock_entry_delete on public.stock_entry for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists stock_entry_detail_select on public.stock_entry_detail;
create policy stock_entry_detail_select on public.stock_entry_detail for select to authenticated
  using (exists (select 1 from public.stock_entry p where p.id = parent_id));
drop policy if exists stock_entry_detail_insert on public.stock_entry_detail;
create policy stock_entry_detail_insert on public.stock_entry_detail for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Stock Entry', 'create'))::uuid[]));
drop policy if exists stock_entry_detail_update on public.stock_entry_detail;
create policy stock_entry_detail_update on public.stock_entry_detail for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]));
drop policy if exists stock_entry_detail_delete on public.stock_entry_detail;
create policy stock_entry_detail_delete on public.stock_entry_detail for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]));

drop policy if exists stock_entry_additional_cost_select on public.stock_entry_additional_cost;
create policy stock_entry_additional_cost_select on public.stock_entry_additional_cost for select to authenticated
  using (exists (select 1 from public.stock_entry p where p.id = parent_id));
drop policy if exists stock_entry_additional_cost_insert on public.stock_entry_additional_cost;
create policy stock_entry_additional_cost_insert on public.stock_entry_additional_cost for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Stock Entry', 'create'))::uuid[]));
drop policy if exists stock_entry_additional_cost_update on public.stock_entry_additional_cost;
create policy stock_entry_additional_cost_update on public.stock_entry_additional_cost for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]));
drop policy if exists stock_entry_additional_cost_delete on public.stock_entry_additional_cost;
create policy stock_entry_additional_cost_delete on public.stock_entry_additional_cost for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Entry', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default
) values (
  'Stock Entry', 'stock_entry', 'stock', true, 'title', 'MAT-STE-.YYYY.-'
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Stock Entry Detail', 'stock_entry_detail', 'stock', true, 'Stock Entry', 'items'),
  ('Stock Entry Additional Cost', 'stock_entry_additional_cost', 'stock', true, 'Stock Entry', 'additional_costs')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Stock Entry', true, false, false, false, false, false, false),
  ('Stock User', 'Stock Entry', true, true, true, true, true, true, true),
  ('Stock Manager', 'Stock Entry', true, true, true, true, true, true, true),
  ('Manufacturing User', 'Stock Entry', true, true, true, true, true, true, true),
  ('Manufacturing Manager', 'Stock Entry', true, true, true, true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
