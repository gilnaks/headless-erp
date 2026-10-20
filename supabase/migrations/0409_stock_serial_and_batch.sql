-- 0409 stock: Batch, Serial No, and Serial and Batch Bundle (docs/modules/04-stock.md §2.13, §3.5).
-- ERPNext: erpnext/stock/doctype/batch/batch.json, serial_no/serial_no.json,
-- serial_and_batch_bundle/serial_and_batch_bundle.json, serial_and_batch_bundle.py.
-- A stock-ledger insert creates or checks the bundle. Valuation stays item + warehouse.

create table if not exists public.batch (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations (id) on delete cascade,
  name                text not null,
  batch_id            text not null,
  item_id             uuid not null,
  manufacturing_date  date,
  expiry_date         date,
  batch_qty           numeric(21,9) not null default 0,
  disabled            boolean not null default false,
  supplier_id         uuid,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, supplier_id) references public.supplier (org_id, id)
);

create index if not exists batch_item_idx on public.batch (org_id, item_id);
create index if not exists batch_supplier_idx on public.batch (org_id, supplier_id);

create table if not exists public.serial_no (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null references public.organizations (id) on delete cascade,
  name                  text not null,
  serial_no             text not null,
  item_id               uuid not null,
  company_id            uuid not null,
  warehouse_id          uuid,
  batch_id              uuid,
  purchase_rate         numeric(21,9) not null default 0,
  customer_id           uuid,
  warranty_expiry_date  date,
  created_at            timestamptz not null default now(),
  created_by            uuid default auth.uid(),
  updated_at            timestamptz not null default now(),
  updated_by            uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, batch_id) references public.batch (org_id, id),
  foreign key (org_id, customer_id) references public.customer (org_id, id)
);

create index if not exists serial_no_item_idx on public.serial_no (org_id, item_id);
create index if not exists serial_no_company_idx on public.serial_no (org_id, company_id);
create index if not exists serial_no_warehouse_idx on public.serial_no (org_id, warehouse_id);
create index if not exists serial_no_batch_idx on public.serial_no (org_id, batch_id);
create index if not exists serial_no_customer_idx on public.serial_no (org_id, customer_id);

create table if not exists public.serial_and_batch_bundle (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null references public.organizations (id) on delete cascade,
  name                  text not null,
  naming_series         text not null default 'SABB-.########',
  item_id               uuid not null,
  company_id            uuid not null,
  warehouse_id          uuid not null,
  voucher_type          text not null,
  voucher_id            uuid,
  type_of_transaction   text not null check (type_of_transaction in ('Inward', 'Outward')),
  posting_datetime      timestamptz not null default now(),
  total_qty             numeric(21,9) not null default 0,
  docstatus             smallint not null default 0 check (docstatus in (0, 1, 2)),
  amended_from          uuid,
  created_at            timestamptz not null default now(),
  created_by            uuid default auth.uid(),
  updated_at            timestamptz not null default now(),
  updated_by            uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, amended_from) references public.serial_and_batch_bundle (org_id, id) on delete set null (amended_from)
);

create index if not exists sabb_item_idx on public.serial_and_batch_bundle (org_id, item_id);
create index if not exists sabb_company_idx on public.serial_and_batch_bundle (org_id, company_id);
create index if not exists sabb_warehouse_idx on public.serial_and_batch_bundle (org_id, warehouse_id);
create index if not exists sabb_voucher_idx on public.serial_and_batch_bundle (org_id, voucher_type, voucher_id);
create index if not exists sabb_amended_idx on public.serial_and_batch_bundle (org_id, amended_from);

create table if not exists public.serial_and_batch_entry (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null,
  parent_id       uuid not null,
  idx             int not null,
  serial_no_id    uuid,
  batch_id        uuid,
  qty             numeric(21,9) not null,
  incoming_rate   numeric(21,9) not null default 0,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.serial_and_batch_bundle (org_id, id) on delete cascade,
  foreign key (org_id, serial_no_id) references public.serial_no (org_id, id),
  foreign key (org_id, batch_id) references public.batch (org_id, id),
  check (serial_no_id is not null or batch_id is not null),
  check (qty > 0)
);

create index if not exists sabb_entry_parent_idx on public.serial_and_batch_entry (org_id, parent_id);
create index if not exists sabb_entry_serial_idx on public.serial_and_batch_entry (org_id, serial_no_id);
create index if not exists sabb_entry_batch_idx on public.serial_and_batch_entry (org_id, batch_id);

alter table public.stock_ledger_entry
  add constraint stock_ledger_entry_bundle_fkey
  foreign key (serial_and_batch_bundle_id) references public.serial_and_batch_bundle (id);
alter table public.stock_ledger_entry
  add constraint stock_ledger_entry_batch_fkey
  foreign key (batch_id) references public.batch (id);
create index if not exists sle_bundle_idx on public.stock_ledger_entry (serial_and_batch_bundle_id);
create index if not exists sle_batch_idx on public.stock_ledger_entry (batch_id);

create or replace function app.batch_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_batched boolean;
begin
  new.batch_id := trim(new.batch_id);
  if new.batch_id is null or new.batch_id = '' then
    raise exception using errcode = 'P0001', message = 'batch_id: Batch No is required';
  end if;
  new.name := new.batch_id;
  select i.has_batch_no into v_batched
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if v_batched is not true then
    raise exception using errcode = 'P0001', message = 'batch_item: Item must have a batch number';
  end if;
  if current_setting('app.serial_write', true) is distinct from '1' then
    if tg_op = 'UPDATE' then
      new.batch_qty := old.batch_qty;
    else
      new.batch_qty := 0;
    end if;
  end if;
  return new;
end;
$$;

create or replace function app.serial_no_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_serialized boolean;
begin
  new.serial_no := trim(new.serial_no);
  if new.serial_no is null or new.serial_no = '' then
    raise exception using errcode = 'P0001', message = 'serial_no: Serial No is required';
  end if;
  new.name := new.serial_no;
  select i.has_serial_no into v_serialized
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if v_serialized is not true then
    raise exception using errcode = 'P0001', message = 'serial_item: Item must have a serial number';
  end if;
  if tg_op = 'UPDATE' and current_setting('app.serial_write', true) is distinct from '1' then
    new.warehouse_id := old.warehouse_id;
    new.purchase_rate := old.purchase_rate;
  end if;
  return new;
end;
$$;

create or replace function app.serial_and_batch_bundle_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.docstatus <> 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'sabb_status: Submit the voucher that owns this bundle';
  end if;
  if tg_op = 'UPDATE' and old.docstatus > 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'sabb_status: A submitted bundle cannot be edited';
  end if;
  if new.type_of_transaction not in ('Inward', 'Outward') then
    raise exception using errcode = 'P0001', message = 'sabb_type: Type of transaction must be Inward or Outward';
  end if;
  return new;
end;
$$;

create or replace function app.serial_and_batch_entry_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status int;
begin
  if new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001', message = 'sabb_qty: Bundle row quantity must be greater than zero';
  end if;
  if new.serial_no_id is null and new.batch_id is null then
    raise exception using errcode = 'P0001', message = 'sabb_row: A bundle row needs a serial or a batch';
  end if;
  select b.docstatus into v_status
    from public.serial_and_batch_bundle b
   where b.id = new.parent_id;
  if v_status > 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'sabb_status: A submitted bundle cannot be edited';
  end if;
  return new;
end;
$$;

create or replace function app.refresh_batch_qty(p_batch uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.serial_write', '1', true);
  update public.batch b
     set batch_qty = coalesce((
           select sum(case when sle.actual_qty < 0 then -e.qty else e.qty end)
             from public.serial_and_batch_entry e
             join public.serial_and_batch_bundle bun
               on bun.id = e.parent_id and bun.org_id = e.org_id and bun.docstatus = 1
             join public.stock_ledger_entry sle
               on sle.serial_and_batch_bundle_id = bun.id and sle.org_id = bun.org_id and not sle.is_cancelled
            where e.batch_id = p_batch
         ), 0)
   where b.id = p_batch;
  perform set_config('app.serial_write', '', true);
end;
$$;

create or replace function app.sle_prepare_serial_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item_code text;
  v_create boolean;
  v_series text;
  v_auto boolean := true;
  v_pick text := 'FIFO';
  v_allow boolean := true;
  v_text text;
  v_batch_text text;
  v_need numeric;
  v_inward boolean;
  v_names text[] := '{}';
  v_wh_name text;
  v_batch uuid;
  v_serial uuid;
  v_serial_wh uuid;
  v_serial_item uuid;
  v_got int;
  v_left numeric;
  v_take numeric;
  v_avail numeric;
  v_sum numeric;
  v_bundle uuid;
  v_bundle_name text;
  v_one_batch uuid;
  v_batch_count int;
  v_serial_out text;
  v_batch_out text;
  v_qty_text text;
  v_need_text text;
  r record;
  v_name text;
begin
  if not coalesce(new.has_serial_no, false) and not coalesce(new.has_batch_no, false) then
    return new;
  end if;
  if new.is_cancelled or coalesce(new.actual_qty, 0) = 0 or new.serial_and_batch_bundle_id is not null then
    return new;
  end if;

  v_inward := new.actual_qty > 0;
  v_need := abs(new.actual_qty);
  if new.has_serial_no and v_need <> trunc(v_need) then
    raise exception using errcode = 'P0001', message = 'sabb_qty: A serialized item needs a whole number quantity';
  end if;

  if new.voucher_type = 'Stock Entry' then
    select d.serial_no, d.batch_no into v_text, v_batch_text
      from public.stock_entry_detail d
     where d.id = new.voucher_detail_id and d.org_id = new.org_id;
  elsif new.voucher_type = 'Stock Reconciliation' then
    select d.serial_no, d.batch_no into v_text, v_batch_text
      from public.stock_reconciliation_item d
     where d.id = new.voucher_detail_id and d.org_id = new.org_id;
  else
    raise exception using errcode = 'P0001',
      message = format('sabb_voucher: %s does not carry serials yet', new.voucher_type);
  end if;
  if not found then
    raise exception using errcode = 'P0001', message = 'sabb_serial: The stock row is missing';
  end if;

  select i.item_code, i.create_new_batch, i.batch_number_series
    into v_item_code, v_create, v_series
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  select s.auto_create_serial_and_batch_bundle_for_outward, s.pick_serial_and_batch_based_on, s.allow_existing_serial_no
    into v_auto, v_pick, v_allow
    from public.stock_settings s
   where s.org_id = new.org_id;
  v_auto := coalesce(v_auto, true);
  v_pick := coalesce(v_pick, 'FIFO');
  v_allow := coalesce(v_allow, true);
  select w.warehouse_name into v_wh_name from public.warehouse w where w.id = new.warehouse_id;

  create temp table if not exists _sabb_line (
    ord int generated by default as identity,
    serial_id uuid,
    batch_id uuid,
    qty numeric
  ) on commit drop;
  delete from _sabb_line;

  if new.has_serial_no then
    select coalesce(array_agg(picked.n order by picked.ord), '{}')
      into v_names
      from (
        select t.ord::int as ord, trim(t.x) as n
          from unnest(regexp_split_to_array(replace(coalesce(v_text, ''), E'\r', ''), E'[\n,]+')) with ordinality as t(x, ord)
         where trim(t.x) <> ''
      ) picked;
    if coalesce(array_length(v_names, 1), 0) = 0 then
      if not v_inward and v_auto then
        select coalesce(array_agg(p.name order by p.ord), '{}')
          into v_names
          from (
            select sn.name, row_number() over (
                     order by
                       case when v_pick = 'Expiry' then b.expiry_date end nulls last,
                       case when v_pick = 'LIFO' then posted.posted end desc nulls last,
                       case when v_pick <> 'LIFO' then posted.posted end asc nulls last,
                       sn.name
                   ) as ord
              from public.serial_no sn
              left join public.batch b on b.id = sn.batch_id and b.org_id = sn.org_id
              left join lateral (
                select min(sle.posting_datetime) as posted
                  from public.stock_ledger_entry sle
                  join public.serial_and_batch_entry e
                    on e.parent_id = sle.serial_and_batch_bundle_id and e.serial_no_id = sn.id
                 where sle.org_id = sn.org_id and not sle.is_cancelled and sle.actual_qty > 0
                   and sle.warehouse_id = new.warehouse_id
              ) posted on true
             where sn.org_id = new.org_id and sn.item_id = new.item_id and sn.warehouse_id = new.warehouse_id
             order by
               case when v_pick = 'Expiry' then b.expiry_date end nulls last,
               case when v_pick = 'LIFO' then posted.posted end desc nulls last,
               case when v_pick <> 'LIFO' then posted.posted end asc nulls last,
               sn.name
             limit v_need::int
          ) p;
      end if;
    end if;
    v_got := coalesce(array_length(v_names, 1), 0);
    if v_got = 0 then
      raise exception using errcode = 'P0001',
        message = format('sabb_serial: Serial numbers are required for %s', v_item_code);
    end if;
    if (select count(*) from unnest(v_names) n) <> (select count(distinct n) from unnest(v_names) n) then
      raise exception using errcode = 'P0001', message = 'sabb_serial: Duplicate serial number';
    end if;
    if v_got::numeric <> v_need then
      if not v_inward and v_auto and coalesce(v_text, '') = '' then
        raise exception using errcode = 'P0001',
          message = format('sabb_serial: Not enough serial numbers in %s for %s', v_wh_name, v_item_code);
      end if;
      v_qty_text := rtrim(rtrim(to_char(v_got, 'FM999999990.999999999'), '0'), '.');
      v_need_text := rtrim(rtrim(to_char(v_need, 'FM999999990.999999999'), '0'), '.');
      raise exception using errcode = 'P0001',
        message = format('sabb_qty: Total quantity in Serial and Batch Bundle is %s, it should be %s', v_qty_text, v_need_text);
    end if;

    foreach v_name in array v_names loop
      select s.id, s.warehouse_id, s.item_id into v_serial, v_serial_wh, v_serial_item
        from public.serial_no s
       where s.org_id = new.org_id and s.name = v_name;
      if found then
        if v_serial_item <> new.item_id then
          raise exception using errcode = 'P0001',
            message = format('sabb_serial: Serial %s belongs to another item', v_name);
        end if;
        if v_inward then
          if v_serial_wh is not null then
            raise exception using errcode = 'P0001',
              message = format('sabb_serial: Serial %s is already in stock', v_name);
          end if;
          if not v_allow then
            raise exception using errcode = 'P0001',
              message = format('sabb_serial: Serial %s cannot be received again', v_name);
          end if;
        elsif v_serial_wh is distinct from new.warehouse_id then
          raise exception using errcode = 'P0001',
            message = format('sabb_serial: Serial %s is not in %s', v_name, v_wh_name);
        end if;
      else
        if not v_inward then
          raise exception using errcode = 'P0001',
            message = format('sabb_serial: Serial %s is not in %s', v_name, v_wh_name);
        end if;
        insert into public.serial_no (org_id, name, serial_no, item_id, company_id)
        values (new.org_id, v_name, v_name, new.item_id, new.company_id)
        returning id into v_serial;
      end if;
      insert into _sabb_line (serial_id, batch_id, qty) values (v_serial, null, 1);
    end loop;
  end if;

  if new.has_batch_no then
    if coalesce(trim(v_batch_text), '') <> '' then
      select b.id into v_batch
        from public.batch b
       where b.org_id = new.org_id and b.name = trim(v_batch_text) and b.item_id = new.item_id;
      if v_batch is null then
        if not v_inward then
          raise exception using errcode = 'P0001',
            message = format('sabb_batch: Batch %s was not found for %s', trim(v_batch_text), v_item_code);
        end if;
        insert into public.batch (org_id, name, batch_id, item_id)
        values (new.org_id, trim(v_batch_text), trim(v_batch_text), new.item_id)
        returning id into v_batch;
      end if;
      if exists (select 1 from public.batch b where b.id = v_batch and b.disabled) then
        raise exception using errcode = 'P0001',
          message = format('sabb_batch: Batch %s is disabled', trim(v_batch_text));
      end if;
      if not v_inward and exists (
        select 1 from public.batch b
         where b.id = v_batch and b.expiry_date is not null and b.expiry_date < new.posting_date
      ) then
        raise exception using errcode = 'P0001',
          message = format('sabb_batch: Batch %s has expired', trim(v_batch_text));
      end if;
      if not v_inward then
        select coalesce(sum(case when sle.actual_qty < 0 then -e.qty else e.qty end), 0) into v_avail
          from public.serial_and_batch_entry e
          join public.serial_and_batch_bundle bun
            on bun.id = e.parent_id and bun.org_id = e.org_id and bun.docstatus = 1
          join public.stock_ledger_entry sle
            on sle.serial_and_batch_bundle_id = bun.id and sle.org_id = bun.org_id
           and not sle.is_cancelled and sle.warehouse_id = new.warehouse_id
         where e.batch_id = v_batch;
        if v_avail < v_need then
          raise exception using errcode = 'P0001',
            message = format('sabb_batch: Not enough batch quantity in %s for %s', v_wh_name, v_item_code);
        end if;
      end if;
      if new.has_serial_no then
        update _sabb_line set batch_id = v_batch where batch_id is null;
      else
        insert into _sabb_line (serial_id, batch_id, qty) values (null, v_batch, v_need);
      end if;
    elsif new.has_serial_no then
      if exists (select 1 from _sabb_line where batch_id is null) then
        raise exception using errcode = 'P0001',
          message = format('sabb_batch: Batch is required for %s', v_item_code);
      end if;
    elsif v_inward and v_create and coalesce(trim(v_series), '') <> '' then
      v_batch_text := app.next_name(new.org_id, new.company_id, trim(v_series), new.posting_date);
      insert into public.batch (org_id, name, batch_id, item_id)
      values (new.org_id, v_batch_text, v_batch_text, new.item_id)
      returning id into v_batch;
      insert into _sabb_line (serial_id, batch_id, qty) values (null, v_batch, v_need);
    elsif not v_inward and v_auto then
      v_left := v_need;
      for r in
        select b.id, b.name, held.avail
          from public.batch b
          join lateral (
            select coalesce(sum(case when sle.actual_qty < 0 then -e.qty else e.qty end), 0) as avail
              from public.serial_and_batch_entry e
              join public.serial_and_batch_bundle bun
                on bun.id = e.parent_id and bun.org_id = e.org_id and bun.docstatus = 1
              join public.stock_ledger_entry sle
                on sle.serial_and_batch_bundle_id = bun.id and sle.org_id = bun.org_id
               and not sle.is_cancelled and sle.warehouse_id = new.warehouse_id
             where e.batch_id = b.id
          ) held on held.avail > 0
          left join lateral (
            select min(sle.posting_datetime) as posted
              from public.stock_ledger_entry sle
              join public.serial_and_batch_entry e
                on e.parent_id = sle.serial_and_batch_bundle_id and e.batch_id = b.id
             where sle.org_id = b.org_id and not sle.is_cancelled and sle.actual_qty > 0
               and sle.warehouse_id = new.warehouse_id
          ) posted on true
         where b.org_id = new.org_id and b.item_id = new.item_id and not b.disabled
           and (b.expiry_date is null or b.expiry_date >= new.posting_date)
         order by
           case when v_pick = 'Expiry' then b.expiry_date end nulls last,
           case when v_pick = 'LIFO' then posted.posted end desc nulls last,
           case when v_pick <> 'LIFO' then posted.posted end asc nulls last,
           b.name
      loop
        v_take := least(r.avail, v_left);
        insert into _sabb_line (serial_id, batch_id, qty) values (null, r.id, v_take);
        v_left := v_left - v_take;
        exit when v_left <= 0;
      end loop;
      if v_left > 0 then
        raise exception using errcode = 'P0001',
          message = format('sabb_batch: Not enough batch quantity in %s for %s', v_wh_name, v_item_code);
      end if;
    else
      raise exception using errcode = 'P0001',
        message = format('sabb_batch: Batch is required for %s', v_item_code);
    end if;
  end if;

  select coalesce(sum(qty), 0) into v_sum from _sabb_line;
  if v_sum <> v_need then
    v_qty_text := rtrim(rtrim(to_char(v_sum, 'FM999999990.999999999'), '0'), '.');
    v_need_text := rtrim(rtrim(to_char(v_need, 'FM999999990.999999999'), '0'), '.');
    raise exception using errcode = 'P0001',
      message = format('sabb_qty: Total quantity in Serial and Batch Bundle is %s, it should be %s', v_qty_text, v_need_text);
  end if;

  v_bundle_name := app.next_name(new.org_id, new.company_id, 'SABB-.########', new.posting_date);
  insert into public.serial_and_batch_bundle (
    org_id, name, naming_series, item_id, company_id, warehouse_id, voucher_type, voucher_id,
    type_of_transaction, posting_datetime, total_qty, docstatus
  ) values (
    new.org_id, v_bundle_name, 'SABB-.########', new.item_id, new.company_id, new.warehouse_id,
    new.voucher_type, new.voucher_id,
    case when v_inward then 'Inward' else 'Outward' end,
    new.posting_datetime, v_need, 1
  ) returning id into v_bundle;

  insert into public.serial_and_batch_entry (org_id, parent_id, idx, serial_no_id, batch_id, qty, incoming_rate)
  select new.org_id, v_bundle, row_number() over (order by l.ord), l.serial_id, l.batch_id, l.qty,
         case when v_inward then coalesce(new.incoming_rate, 0) else 0 end
    from _sabb_line l;

  select min(batch_id), count(distinct batch_id) into v_one_batch, v_batch_count
    from _sabb_line
   where batch_id is not null;
  if v_batch_count = 1 then
    new.batch_id := v_one_batch;
  end if;
  new.serial_and_batch_bundle_id := v_bundle;

  select nullif(string_agg(s.name, E'\n' order by l.ord), '') into v_serial_out
    from _sabb_line l
    join public.serial_no s on s.id = l.serial_id;
  select nullif(string_agg(distinct b.name, ', '), '') into v_batch_out
    from _sabb_line l
    join public.batch b on b.id = l.batch_id;

  if new.voucher_type = 'Stock Entry' then
    update public.stock_entry_detail d
       set serial_and_batch_bundle = coalesce(nullif(d.serial_and_batch_bundle, ''), v_bundle_name),
           serial_no = coalesce(nullif(d.serial_no, ''), v_serial_out),
           batch_no = coalesce(nullif(d.batch_no, ''), v_batch_out)
     where d.id = new.voucher_detail_id;
  elsif new.voucher_type = 'Stock Reconciliation' then
    update public.stock_reconciliation_item d
       set serial_and_batch_bundle = coalesce(nullif(d.serial_and_batch_bundle, ''), v_bundle_name),
           serial_no = coalesce(nullif(d.serial_no, ''), v_serial_out),
           batch_no = coalesce(nullif(d.batch_no, ''), v_batch_out)
     where d.id = new.voucher_detail_id;
  end if;

  return new;
end;
$$;

create or replace function app.sle_finish_serial_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  if new.serial_and_batch_bundle_id is null then
    return new;
  end if;
  perform set_config('app.serial_write', '1', true);
  if new.is_cancelled then
    update public.serial_and_batch_bundle
       set docstatus = 2
     where id = new.serial_and_batch_bundle_id and docstatus = 1;
  end if;
  update public.serial_no s
     set warehouse_id = case when new.actual_qty > 0 then new.warehouse_id else null end,
         purchase_rate = case
           when new.actual_qty > 0 and not new.is_cancelled then coalesce(new.incoming_rate, 0)
           else s.purchase_rate
         end,
         batch_id = coalesce(e.batch_id, s.batch_id)
    from public.serial_and_batch_entry e
   where e.parent_id = new.serial_and_batch_bundle_id and e.serial_no_id = s.id;
  for r in
    select distinct e.batch_id
      from public.serial_and_batch_entry e
     where e.parent_id = new.serial_and_batch_bundle_id and e.batch_id is not null
  loop
    perform app.refresh_batch_qty(r.batch_id);
  end loop;
  perform set_config('app.serial_write', '', true);
  return new;
end;
$$;

revoke all on function
  app.batch_validate(), app.serial_no_validate(), app.serial_and_batch_bundle_validate(),
  app.serial_and_batch_entry_validate(), app.refresh_batch_qty(uuid),
  app.sle_prepare_serial_batch(), app.sle_finish_serial_batch()
from public, anon, authenticated;

drop trigger if exists batch_validate on public.batch;
create trigger batch_validate before insert or update on public.batch
  for each row execute function app.batch_validate();
drop trigger if exists touch_updated on public.batch;
create trigger touch_updated before update on public.batch
  for each row execute function app.touch_updated();
drop trigger if exists serial_no_validate on public.serial_no;
create trigger serial_no_validate before insert or update on public.serial_no
  for each row execute function app.serial_no_validate();
drop trigger if exists touch_updated on public.serial_no;
create trigger touch_updated before update on public.serial_no
  for each row execute function app.touch_updated();
drop trigger if exists serial_and_batch_bundle_validate on public.serial_and_batch_bundle;
create trigger serial_and_batch_bundle_validate before insert or update on public.serial_and_batch_bundle
  for each row execute function app.serial_and_batch_bundle_validate();
drop trigger if exists touch_updated on public.serial_and_batch_bundle;
create trigger touch_updated before update on public.serial_and_batch_bundle
  for each row execute function app.touch_updated();
drop trigger if exists serial_and_batch_entry_validate on public.serial_and_batch_entry;
create trigger serial_and_batch_entry_validate before insert or update on public.serial_and_batch_entry
  for each row execute function app.serial_and_batch_entry_validate();
drop trigger if exists sle_prepare_serial_batch on public.stock_ledger_entry;
create trigger sle_prepare_serial_batch before insert on public.stock_ledger_entry
  for each row execute function app.sle_prepare_serial_batch();
drop trigger if exists sle_finish_serial_batch on public.stock_ledger_entry;
create trigger sle_finish_serial_batch after insert on public.stock_ledger_entry
  for each row execute function app.sle_finish_serial_batch();

alter table public.batch enable row level security;
alter table public.batch force row level security;
alter table public.serial_no enable row level security;
alter table public.serial_no force row level security;
alter table public.serial_and_batch_bundle enable row level security;
alter table public.serial_and_batch_bundle force row level security;
alter table public.serial_and_batch_entry enable row level security;
alter table public.serial_and_batch_entry force row level security;

drop policy if exists batch_select on public.batch;
create policy batch_select on public.batch for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Batch', 'read'))::uuid[]));
drop policy if exists batch_insert on public.batch;
create policy batch_insert on public.batch for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Batch', 'create'))::uuid[]));
drop policy if exists batch_update on public.batch;
create policy batch_update on public.batch for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Batch', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Batch', 'write'))::uuid[]));
drop policy if exists batch_delete on public.batch;
create policy batch_delete on public.batch for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Batch', 'delete'))::uuid[]));

drop policy if exists serial_no_select on public.serial_no;
create policy serial_no_select on public.serial_no for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial No', 'read'))::uuid[]));
drop policy if exists serial_no_insert on public.serial_no;
create policy serial_no_insert on public.serial_no for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Serial No', 'create'))::uuid[]));
drop policy if exists serial_no_update on public.serial_no;
create policy serial_no_update on public.serial_no for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial No', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Serial No', 'write'))::uuid[]));
drop policy if exists serial_no_delete on public.serial_no;
create policy serial_no_delete on public.serial_no for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial No', 'delete'))::uuid[]));

drop policy if exists sabb_select on public.serial_and_batch_bundle;
create policy sabb_select on public.serial_and_batch_bundle for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'read'))::uuid[]));
drop policy if exists sabb_insert on public.serial_and_batch_bundle;
create policy sabb_insert on public.serial_and_batch_bundle for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'create'))::uuid[]));
drop policy if exists sabb_update on public.serial_and_batch_bundle;
create policy sabb_update on public.serial_and_batch_bundle for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'write'))::uuid[]));
drop policy if exists sabb_delete on public.serial_and_batch_bundle;
create policy sabb_delete on public.serial_and_batch_bundle for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists sabb_entry_select on public.serial_and_batch_entry;
create policy sabb_entry_select on public.serial_and_batch_entry for select to authenticated
  using (exists (select 1 from public.serial_and_batch_bundle p where p.id = parent_id));
drop policy if exists sabb_entry_insert on public.serial_and_batch_entry;
create policy sabb_entry_insert on public.serial_and_batch_entry for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'create'))::uuid[]));
drop policy if exists sabb_entry_update on public.serial_and_batch_entry;
create policy sabb_entry_update on public.serial_and_batch_entry for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'write'))::uuid[]));
drop policy if exists sabb_entry_delete on public.serial_and_batch_entry;
create policy sabb_entry_delete on public.serial_and_batch_entry for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Serial and Batch Bundle', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values
  ('Batch', 'batch', 'stock', 'batch_id'),
  ('Serial No', 'serial_no', 'stock', 'serial_no')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default
) values (
  'Serial and Batch Bundle', 'serial_and_batch_bundle', 'stock', true, 'name', 'SABB-.########'
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Serial and Batch Entry', 'serial_and_batch_entry', 'stock', true, 'Serial and Batch Bundle', 'entries')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Batch', true, false, false, false, false, false, false),
  ('Stock User', 'Batch', true, true, true, false, false, false, true),
  ('Item Manager', 'Batch', true, true, true, false, false, false, true),
  ('System Manager', 'Serial No', true, false, false, false, false, false, false),
  ('Item Manager', 'Serial No', true, true, true, false, false, false, true),
  ('Stock Manager', 'Serial No', true, true, true, false, false, false, true),
  ('Stock User', 'Serial No', true, true, true, false, false, false, false),
  ('Purchase User', 'Serial No', true, true, true, false, false, false, true),
  ('Sales User', 'Serial No', true, true, true, false, false, false, true),
  ('System Manager', 'Serial and Batch Bundle', true, false, false, false, false, false, false),
  ('Stock User', 'Serial and Batch Bundle', true, true, true, true, true, true, true),
  ('Stock Manager', 'Serial and Batch Bundle', true, true, true, true, true, true, true),
  ('Purchase User', 'Serial and Batch Bundle', true, true, true, true, true, true, true),
  ('Manufacturing User', 'Serial and Batch Bundle', true, true, true, true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
