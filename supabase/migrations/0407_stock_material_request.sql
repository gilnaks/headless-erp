-- 0407 stock: Material Request (docs/modules/04-stock.md §2.14, 03-buying §2.9).
-- ERPNext: erpnext/stock/doctype/material_request/material_request.json,
-- material_request.py, mapper.py, erpnext/controllers/status_updater.py.
-- Submit does not move stock. A linked Stock Entry updates ordered qty, status, and bin.indented_qty.
-- Purchase ordered qty waits for the purchase order. Manufacture waits for the work order.
-- BOM, sales order, and the buying create menu are later lines.

create table if not exists public.material_request (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  name                    text not null,
  title                   text,
  naming_series           text not null default 'MAT-MR-.YYYY.-',
  material_request_type   text not null
    check (material_request_type in (
      'Purchase', 'Material Transfer', 'Material Issue', 'Manufacture', 'Customer Provided'
    )),
  customer_id             uuid,
  company_id              uuid not null,
  transaction_date        date not null default current_date,
  schedule_date           date,
  set_from_warehouse_id   uuid,
  set_warehouse_id        uuid,
  status                  text not null default 'Draft'
    check (status in (
      'Draft', 'Pending', 'Stopped', 'Partially Ordered', 'Ordered', 'Transferred',
      'Issued', 'Partially Received', 'Received', 'Cancelled'
    )),
  per_ordered             numeric(21,9) not null default 0,
  per_received            numeric(21,9) not null default 0,
  docstatus               smallint not null default 0 check (docstatus in (0, 1, 2)),
  amended_from            uuid,
  created_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  updated_at              timestamptz not null default now(),
  updated_by              uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, customer_id) references public.customer (org_id, id),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, set_from_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, set_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, amended_from) references public.material_request (org_id, id) on delete set null (amended_from)
);

create index if not exists material_request_customer_idx on public.material_request (org_id, customer_id);
create index if not exists material_request_company_idx on public.material_request (org_id, company_id);
create index if not exists material_request_from_wh_idx on public.material_request (org_id, set_from_warehouse_id);
create index if not exists material_request_wh_idx on public.material_request (org_id, set_warehouse_id);
create index if not exists material_request_amended_idx on public.material_request (org_id, amended_from);
create index if not exists material_request_date_idx on public.material_request (org_id, transaction_date);

create table if not exists public.material_request_item (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null,
  parent_id           uuid not null,
  idx                 int not null,
  item_id             uuid not null,
  qty                 numeric(21,9) not null,
  uom_id              uuid,
  conversion_factor   numeric(21,9) not null default 1,
  stock_uom_id        uuid,
  stock_qty           numeric(21,9) not null default 0,
  schedule_date       date,
  warehouse_id        uuid,
  from_warehouse_id   uuid,
  ordered_qty         numeric(21,9) not null default 0,
  received_qty        numeric(21,9) not null default 0,
  rate                numeric(21,9) not null default 0,
  amount              numeric(21,9) not null default 0,
  project             text,
  cost_center_id      uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.material_request (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, uom_id) references public.uom (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, from_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id)
);

create index if not exists material_request_item_parent_idx on public.material_request_item (org_id, parent_id);
create index if not exists material_request_item_item_idx on public.material_request_item (org_id, item_id);
create index if not exists material_request_item_uom_idx on public.material_request_item (org_id, uom_id);
create index if not exists material_request_item_stock_uom_idx on public.material_request_item (org_id, stock_uom_id);
create index if not exists material_request_item_wh_idx on public.material_request_item (org_id, warehouse_id);
create index if not exists material_request_item_from_wh_idx on public.material_request_item (org_id, from_warehouse_id);
create index if not exists material_request_item_cost_center_idx on public.material_request_item (org_id, cost_center_id);

alter table public.stock_entry_detail
  add constraint stock_entry_detail_material_request_fkey
  foreign key (org_id, material_request_id) references public.material_request (org_id, id);
alter table public.stock_entry_detail
  add constraint stock_entry_detail_material_request_item_fkey
  foreign key (org_id, material_request_item) references public.material_request_item (org_id, id);
create index if not exists stock_entry_detail_mr_idx on public.stock_entry_detail (org_id, material_request_id);
create index if not exists stock_entry_detail_mr_item_idx on public.stock_entry_detail (org_id, material_request_item);

-- Series date is posting_date, or transaction_date when the voucher has no posting date.
create or replace function app.submit_doc(p_doctype text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_org uuid;
  v_status int;
  v_name text;
  v_company uuid;
  v_posting date;
  v_series text;
  v_hook text;
  v_date_col text;
begin
  if p_id is null then
    raise exception using errcode = 'P0001', message = 'not_found: document id is required';
  end if;
  select * into v_meta from public.doctype_meta where doctype = p_doctype and not is_child;
  if not found or not v_meta.is_submittable then
    raise exception using errcode = 'P0001', message = format('not_submittable: %s cannot be submitted', coalesce(p_doctype, 'null'));
  end if;

  execute format('select org_id, docstatus, name from public.%I where id = $1', v_meta.table_name)
    into v_org, v_status, v_name using p_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = format('not_found: %s not found', p_doctype);
  end if;
  if not app.has_perm(v_org, p_doctype, 'submit') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if v_status <> 0 then
    raise exception using errcode = 'P0001', message = format('not_draft: %s is not a draft', p_doctype);
  end if;

  if v_name like 'DRAFT-%' and exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = v_meta.table_name and column_name = 'naming_series'
  ) then
    if exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = v_meta.table_name and column_name = 'posting_date'
    ) then
      v_date_col := 'posting_date';
    elsif exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = v_meta.table_name and column_name = 'transaction_date'
    ) then
      v_date_col := 'transaction_date';
    end if;
    if v_date_col is not null then
      execute format('select company_id, %I, naming_series from public.%I where id = $1', v_date_col, v_meta.table_name)
        into v_company, v_posting, v_series using p_id;
    else
      execute format('select company_id, naming_series from public.%I where id = $1', v_meta.table_name)
        into v_company, v_series using p_id;
      v_posting := null;
    end if;
    v_name := app.next_name(v_org, v_company, coalesce(nullif(v_series, ''), v_meta.naming_series_default), v_posting);
    execute format('update public.%I set name = $2 where id = $1', v_meta.table_name) using p_id, v_name;
  end if;

  v_hook := 'on_submit__' || v_meta.table_name;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'app' and p.proname = v_hook
  ) then
    execute format('select app.%I($1)', v_hook) using p_id;
  end if;

  execute format('update public.%I set docstatus = 1 where id = $1 and docstatus = 0', v_meta.table_name) using p_id;
  execute format('select name from public.%I where id = $1', v_meta.table_name) into v_name using p_id;
  return jsonb_build_object('id', p_id, 'name', v_name);
end;
$$;

create or replace function app.material_request_validate()
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
    new.naming_series := 'MAT-MR-.YYYY.-';
  end if;
  if new.transaction_date is null then
    new.transaction_date := current_date;
  end if;
  if new.material_request_type = 'Subcontracting' then
    raise exception using errcode = 'P0001', message = 'mr_type: Subcontracting is not available';
  end if;
  if new.material_request_type is null or new.material_request_type not in (
    'Purchase', 'Material Transfer', 'Material Issue', 'Manufacture', 'Customer Provided'
  ) then
    raise exception using errcode = 'P0001', message = 'mr_type: Purpose is required';
  end if;
  if new.material_request_type <> 'Customer Provided' then
    new.customer_id := null;
  end if;
  if new.status is null or btrim(new.status) = '' then
    new.status := 'Draft';
  end if;
  if new.docstatus = 0 and current_user = 'authenticated' then
    new.status := 'Draft';
  end if;
  new.per_ordered := coalesce(new.per_ordered, 0);
  new.per_received := coalesce(new.per_received, 0);
  if new.amended_from is not null and tg_op = 'INSERT' then
    new.docstatus := 0;
  end if;
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  return new;
end;
$$;

create or replace function app.material_request_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  h public.material_request;
  v_stock boolean;
  v_stock_uom uuid;
  v_whole boolean;
  v_factor numeric;
  v_company uuid;
begin
  if new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001',
      message = format('mr_qty: Row %s: Quantity must be greater than zero', coalesce(new.idx, 0));
  end if;
  select * into h from public.material_request where id = new.parent_id;
  if h.docstatus <> 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  select i.is_stock_item, i.stock_uom_id into v_stock, v_stock_uom
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001',
      message = format('mr_item: Row %s: Item is required', coalesce(new.idx, 0));
  end if;
  if new.uom_id is null then
    new.uom_id := v_stock_uom;
    new.conversion_factor := 1;
  end if;
  new.stock_uom_id := v_stock_uom;
  if new.uom_id = v_stock_uom then
    new.conversion_factor := 1;
  else
    select u.conversion_factor into v_factor
      from public.item_uom u
     where u.parent_id = new.item_id and u.uom_id = new.uom_id
     limit 1;
    if v_factor is null then
      raise exception using errcode = 'P0001',
        message = format('mr_uom: Row %s: UOM is not allowed for this item', coalesce(new.idx, 0));
    end if;
    if new.conversion_factor is null or new.conversion_factor = 0 or new.conversion_factor = 1 then
      new.conversion_factor := v_factor;
    end if;
  end if;
  select u.must_be_whole_number into v_whole from public.uom u where u.id = new.uom_id;
  if v_whole and new.qty <> trunc(new.qty) then
    raise exception using errcode = 'P0001',
      message = format('mr_uom: Row %s: Qty cannot be a fraction', coalesce(new.idx, 0));
  end if;
  if new.warehouse_id is null then
    new.warehouse_id := h.set_warehouse_id;
  end if;
  if new.from_warehouse_id is null then
    new.from_warehouse_id := h.set_from_warehouse_id;
  end if;
  if v_stock and new.warehouse_id is null then
    raise exception using errcode = 'P0001',
      message = format('mr_warehouse: Row %s: Warehouse is mandatory for stock Item', coalesce(new.idx, 0));
  end if;
  if h.material_request_type = 'Material Transfer' and new.from_warehouse_id is null then
    raise exception using errcode = 'P0001',
      message = format('mr_warehouse: Row %s: Source Warehouse is required for Material Transfer', coalesce(new.idx, 0));
  end if;
  if new.warehouse_id is not null then
    select w.company_id into v_company from public.warehouse w where w.id = new.warehouse_id;
    if v_company is distinct from h.company_id then
      raise exception using errcode = 'P0001',
        message = format('mr_warehouse: Row %s: Warehouse does not belong to the company', coalesce(new.idx, 0));
    end if;
  end if;
  if new.from_warehouse_id is not null then
    select w.company_id into v_company from public.warehouse w where w.id = new.from_warehouse_id;
    if v_company is distinct from h.company_id then
      raise exception using errcode = 'P0001',
        message = format('mr_warehouse: Row %s: Warehouse does not belong to the company', coalesce(new.idx, 0));
    end if;
  end if;
  if new.schedule_date is null then
    new.schedule_date := h.schedule_date;
  end if;
  if new.schedule_date is null then
    raise exception using errcode = 'P0001', message = 'mr_date: Please enter the Required By.';
  end if;
  if new.schedule_date < h.transaction_date then
    raise exception using errcode = 'P0001',
      message = format('mr_date: Row %s: Required By cannot be before Transaction Date.', coalesce(new.idx, 0));
  end if;
  new.stock_qty := new.qty * new.conversion_factor;
  new.rate := coalesce(new.rate, 0);
  new.amount := app.round(new.qty * new.rate, 2);
  new.ordered_qty := coalesce(new.ordered_qty, 0);
  new.received_qty := coalesce(new.received_qty, 0);
  return new;
end;
$$;

create or replace function app.material_request_item_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent uuid := coalesce(new.parent_id, old.parent_id);
  v_items text;
begin
  select string_agg(s.item_name, ', ' order by s.idx) into v_items
    from (
      select i.item_name, r.idx
        from public.material_request_item r
        join public.item i on i.id = r.item_id
       where r.parent_id = v_parent
       order by r.idx
       limit 3
    ) s;
  update public.material_request h
     set schedule_date = coalesce(
           (select min(i.schedule_date) from public.material_request_item i where i.parent_id = v_parent),
           h.schedule_date
         ),
         title = left(h.material_request_type || ' Request for ' || coalesce(v_items, ''), 100)
   where h.id = v_parent;
  return null;
end;
$$;

create or replace function app.material_request_status(p_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  h public.material_request;
begin
  select * into h from public.material_request where id = p_id;
  if h.docstatus = 0 then
    return 'Draft';
  end if;
  if h.status = 'Stopped' then
    return 'Stopped';
  end if;
  if h.docstatus = 2 then
    return 'Cancelled';
  end if;
  if h.per_ordered = 0 then
    return 'Pending';
  end if;
  if h.per_ordered >= 100 and h.material_request_type in ('Purchase', 'Manufacture', 'Subcontracting') then
    return 'Ordered';
  end if;
  if h.per_ordered >= 100 and h.material_request_type = 'Material Transfer' then
    return 'Transferred';
  end if;
  if h.per_ordered >= 100 and h.material_request_type = 'Material Issue' then
    return 'Issued';
  end if;
  if (h.per_received >= 100 and h.material_request_type = 'Purchase')
     or (h.per_ordered >= 100 and h.material_request_type = 'Customer Provided') then
    return 'Received';
  end if;
  if h.per_received > 0 and h.per_received < 100 and h.material_request_type = 'Purchase' then
    return 'Partially Received';
  end if;
  if h.per_ordered > 0 and h.per_ordered < 100
     and h.material_request_type in ('Material Transfer', 'Customer Provided') then
    return 'Partially Received';
  end if;
  if h.per_ordered > 0 and h.per_ordered < 100 and h.per_received < 100
     and h.material_request_type not in ('Material Transfer', 'Customer Provided') then
    return 'Partially Ordered';
  end if;
  return 'Pending';
end;
$$;

create or replace function app.refresh_indented_qty(p_org uuid, p_item uuid, p_warehouse uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_indent numeric := 0;
  v_uom uuid;
begin
  if p_item is null or p_warehouse is null then
    return;
  end if;
  select coalesce(sum(case
           when h.material_request_type in ('Purchase', 'Manufacture', 'Customer Provided', 'Material Transfer')
             then r.stock_qty - r.ordered_qty else 0 end), 0)
       - coalesce(sum(case
           when h.material_request_type = 'Material Issue'
             then r.stock_qty - r.ordered_qty else 0 end), 0)
    into v_indent
    from public.material_request_item r
    join public.material_request h on h.id = r.parent_id
   where r.org_id = p_org
     and r.item_id = p_item
     and r.warehouse_id = p_warehouse
     and r.stock_qty > r.ordered_qty
     and h.docstatus = 1
     and h.status is distinct from 'Stopped';

  select i.stock_uom_id into v_uom from public.item i where i.id = p_item;
  perform set_config('app.sl_write', '1', true);
  insert into public.bin (
    org_id, item_id, warehouse_id, actual_qty, indented_qty, stock_uom_id, projected_qty
  ) values (
    p_org, p_item, p_warehouse, 0, v_indent, v_uom, v_indent
  )
  on conflict (org_id, item_id, warehouse_id) do update
    set indented_qty = excluded.indented_qty,
        projected_qty = bin.actual_qty + bin.ordered_qty + excluded.indented_qty + bin.planned_qty
          - bin.reserved_qty - bin.reserved_qty_for_production
          - bin.reserved_qty_for_sub_contract - bin.reserved_qty_for_production_plan;
  perform set_config('app.sl_write', '', true);
exception
  when others then
    perform set_config('app.sl_write', '', true);
    raise;
end;
$$;

create or replace function app.refresh_material_request(p_id uuid, p_from_stock_entry boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.material_request;
  r record;
  v_ordered numeric;
  v_allow numeric;
  v_allowed numeric;
  v_per numeric;
  v_code text;
begin
  select * into h from public.material_request where id = p_id;
  if not found then
    return;
  end if;
  if p_from_stock_entry and h.status in ('Stopped', 'Cancelled') then
    raise exception using errcode = 'P0001',
      message = format('mr_stopped: Material Request %s is cancelled or stopped', h.name);
  end if;

  if h.material_request_type in ('Material Issue', 'Material Transfer', 'Customer Provided') then
    select s.mr_qty_allowance into v_allow from public.stock_settings s where s.org_id = h.org_id;
    for r in
      select i.*, it.item_code
        from public.material_request_item i
        join public.item it on it.id = i.item_id
       where i.parent_id = h.id
    loop
      select coalesce(sum(d.transfer_qty), 0) into v_ordered
        from public.stock_entry_detail d
        join public.stock_entry e on e.id = d.parent_id
       where d.material_request_item = r.id and e.docstatus = 1;
      if v_allow is not null then
        v_allowed := r.stock_qty + (r.stock_qty * v_allow / 100);
      else
        v_allowed := r.stock_qty;
      end if;
      if v_ordered > v_allowed then
        v_code := case when v_allow is not null then 'allowed requested quantity' else 'requested quantity' end;
        raise exception using errcode = 'P0001',
          message = format(
            'mr_qty: The total Issue / Transfer quantity %s in Material Request %s cannot be greater than %s %s for Item %s',
            to_char(v_ordered, 'FM999999990.999999999'),
            h.name,
            v_code,
            to_char(v_allowed, 'FM999999990.999999999'),
            r.item_code
          );
      end if;
      update public.material_request_item set ordered_qty = v_ordered where id = r.id;
    end loop;
  end if;

  select case when coalesce(sum(abs(i.stock_qty)), 0) = 0 then 0
              else app.round(
                sum(least(abs(i.ordered_qty), abs(i.stock_qty))) / sum(abs(i.stock_qty)) * 100,
                6
              ) end
    into v_per
    from public.material_request_item i
   where i.parent_id = h.id;
  update public.material_request set per_ordered = coalesce(v_per, 0) where id = h.id;
  update public.material_request set status = app.material_request_status(id) where id = h.id;

  for r in
    select distinct i.item_id, i.warehouse_id
      from public.material_request_item i
     where i.parent_id = h.id and i.warehouse_id is not null
  loop
    perform app.refresh_indented_qty(h.org_id, r.item_id, r.warehouse_id);
  end loop;
end;
$$;

create or replace function app.on_submit__material_request(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.material_request_item i where i.parent_id = p_id) then
    raise exception using errcode = 'P0001', message = 'mr_items: Items are required';
  end if;
end;
$$;

create or replace function app.on_cancel__material_request(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.material_request set status = 'Cancelled' where id = p_id;
end;
$$;

create or replace function app.material_request_set_status(p_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.material_request;
begin
  select * into h from public.material_request where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Material Request not found';
  end if;
  if not app.has_perm(h.org_id, 'Material Request', 'write') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if p_status = 'Stopped' then
    if h.docstatus = 2 then
      raise exception using errcode = 'P0001',
        message = format('mr_status: Material Request %s is cancelled so the action cannot be completed', h.name);
    end if;
    if h.docstatus <> 1 then
      raise exception using errcode = 'P0001',
        message = format('mr_status: Material Request %s has not been submitted so the action cannot be completed', h.name);
    end if;
    update public.material_request set status = 'Stopped' where id = p_id;
  elsif p_status = 'Submitted' then
    if h.docstatus = 2 then
      raise exception using errcode = 'P0001',
        message = format('mr_status: Material Request %s is cancelled so the action cannot be completed', h.name);
    end if;
    if h.docstatus <> 1 then
      raise exception using errcode = 'P0001',
        message = format('mr_status: Material Request %s has not been submitted so the action cannot be completed', h.name);
    end if;
    update public.material_request set status = 'Pending' where id = p_id;
  else
    raise exception using errcode = 'P0001', message = 'mr_status: Status cannot be changed to that';
  end if;
  perform app.refresh_material_request(p_id, false);
  return jsonb_build_object('id', p_id);
end;
$$;

create or replace function app.make_stock_entry_from_material_request(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.material_request;
  r record;
  v_purpose text;
  v_type uuid;
  v_se uuid;
  v_name text;
  v_idx int := 0;
  v_qty numeric;
  v_from uuid;
  v_to uuid;
begin
  select * into h from public.material_request where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Material Request not found';
  end if;
  if not app.has_perm(h.org_id, 'Material Request', 'read')
     or not app.has_perm(h.org_id, 'Stock Entry', 'create') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if h.docstatus <> 1 then
    raise exception using errcode = 'P0001',
      message = format('mr_status: Material Request %s has not been submitted so the action cannot be completed', h.name);
  end if;
  if h.status in ('Stopped', 'Cancelled') then
    raise exception using errcode = 'P0001',
      message = format('mr_stopped: Material Request %s is cancelled or stopped', h.name);
  end if;
  if h.material_request_type = 'Purchase' then
    raise exception using errcode = 'P0001', message = 'mr_map: A Purchase request is ordered from a Purchase Order';
  end if;
  if h.material_request_type = 'Manufacture' then
    raise exception using errcode = 'P0001', message = 'mr_map: Manufacture waits for a Work Order';
  end if;
  if h.material_request_type not in ('Material Issue', 'Material Transfer', 'Customer Provided') then
    raise exception using errcode = 'P0001', message = 'mr_map: This request cannot make a Stock Entry';
  end if;

  v_purpose := case h.material_request_type
    when 'Customer Provided' then 'Material Receipt'
    else h.material_request_type
  end;
  select t.id into v_type
    from public.stock_entry_type t
   where t.org_id = h.org_id and t.purpose = v_purpose
   limit 1;
  if v_type is null then
    raise exception using errcode = 'P0001', message = 'mr_map: Stock Entry Type is required';
  end if;
  v_from := case
    when h.material_request_type = 'Material Issue' then h.set_warehouse_id
    when h.material_request_type = 'Material Transfer' then h.set_from_warehouse_id
    else null
  end;
  v_to := case
    when h.material_request_type in ('Material Transfer', 'Customer Provided') then h.set_warehouse_id
    else null
  end;

  insert into public.stock_entry (
    org_id, company_id, stock_entry_type_id, from_warehouse_id, to_warehouse_id, posting_date
  ) values (
    h.org_id, h.company_id, v_type, v_from, v_to, current_date
  )
  returning id into v_se;

  for r in
    select * from public.material_request_item i
     where i.parent_id = h.id and i.stock_qty > i.ordered_qty
     order by i.idx
  loop
    v_idx := v_idx + 1;
    v_qty := (r.stock_qty - r.ordered_qty) / r.conversion_factor;
    insert into public.stock_entry_detail (
      org_id, parent_id, idx, item_id, qty, uom_id, conversion_factor,
      s_warehouse_id, t_warehouse_id, allow_zero_valuation_rate,
      material_request_id, material_request_item
    ) values (
      h.org_id, v_se, v_idx, r.item_id, v_qty, r.uom_id, r.conversion_factor,
      case
        when h.material_request_type = 'Material Issue' then r.warehouse_id
        when h.material_request_type = 'Material Transfer' then r.from_warehouse_id
        else null
      end,
      case
        when h.material_request_type in ('Material Transfer', 'Customer Provided') then r.warehouse_id
        else null
      end,
      h.material_request_type = 'Customer Provided',
      h.id,
      r.id
    );
  end loop;
  if v_idx = 0 then
    raise exception using errcode = 'P0001', message = 'mr_empty: Nothing to transfer or issue';
  end if;
  select e.name into v_name from public.stock_entry e where e.id = v_se;
  return jsonb_build_object('id', v_se, 'name', v_name);
end;
$$;

create or replace function app.material_request_on_docstatus()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and new.docstatus in (1, 2) then
    perform app.refresh_material_request(new.id, false);
  end if;
  return new;
end;
$$;

create or replace function app.stock_entry_refresh_material_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mr uuid;
begin
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and new.docstatus in (1, 2) then
    for v_mr in
      select distinct d.material_request_id
        from public.stock_entry_detail d
       where d.parent_id = new.id and d.material_request_id is not null
    loop
      perform app.refresh_material_request(v_mr, true);
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function
  app.material_request_validate(), app.material_request_item_validate(), app.material_request_item_sync(),
  app.material_request_status(uuid), app.refresh_indented_qty(uuid, uuid, uuid),
  app.refresh_material_request(uuid, boolean),
  app.on_submit__material_request(uuid), app.on_cancel__material_request(uuid),
  app.material_request_on_docstatus(), app.stock_entry_refresh_material_request()
from public, anon, authenticated;

revoke all on function app.material_request_set_status(uuid, text) from public, anon;
revoke all on function app.make_stock_entry_from_material_request(uuid) from public, anon;
grant execute on function app.material_request_set_status(uuid, text) to authenticated;
grant execute on function app.make_stock_entry_from_material_request(uuid) to authenticated;

create or replace function public.material_request_set_status(p_id uuid, p_status text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.material_request_set_status(p_id, p_status);
$$;

create or replace function public.make_stock_entry_from_material_request(p_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.make_stock_entry_from_material_request(p_id);
$$;

revoke all on function public.material_request_set_status(uuid, text) from public, anon;
revoke all on function public.make_stock_entry_from_material_request(uuid) from public, anon;
grant execute on function public.material_request_set_status(uuid, text) to authenticated;
grant execute on function public.make_stock_entry_from_material_request(uuid) to authenticated;

drop trigger if exists material_request_validate on public.material_request;
create trigger material_request_validate before insert or update on public.material_request
  for each row execute function app.material_request_validate();
drop trigger if exists touch_updated on public.material_request;
create trigger touch_updated before update on public.material_request
  for each row execute function app.touch_updated();
drop trigger if exists material_request_item_validate on public.material_request_item;
create trigger material_request_item_validate before insert or update on public.material_request_item
  for each row execute function app.material_request_item_validate();
drop trigger if exists material_request_item_sync on public.material_request_item;
create trigger material_request_item_sync after insert or update or delete on public.material_request_item
  for each row execute function app.material_request_item_sync();
drop trigger if exists material_request_on_docstatus on public.material_request;
create trigger material_request_on_docstatus after update on public.material_request
  for each row execute function app.material_request_on_docstatus();
drop trigger if exists stock_entry_refresh_material_request on public.stock_entry;
create trigger stock_entry_refresh_material_request after update on public.stock_entry
  for each row execute function app.stock_entry_refresh_material_request();

alter table public.material_request enable row level security;
alter table public.material_request force row level security;
alter table public.material_request_item enable row level security;
alter table public.material_request_item force row level security;

drop policy if exists material_request_select on public.material_request;
create policy material_request_select on public.material_request for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Material Request', 'read'))::uuid[]));
drop policy if exists material_request_insert on public.material_request;
create policy material_request_insert on public.material_request for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Material Request', 'create'))::uuid[]));
drop policy if exists material_request_update on public.material_request;
create policy material_request_update on public.material_request for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Material Request', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Material Request', 'write'))::uuid[]));
drop policy if exists material_request_delete on public.material_request;
create policy material_request_delete on public.material_request for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Material Request', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists material_request_item_select on public.material_request_item;
create policy material_request_item_select on public.material_request_item for select to authenticated
  using (exists (select 1 from public.material_request p where p.id = parent_id));
drop policy if exists material_request_item_insert on public.material_request_item;
create policy material_request_item_insert on public.material_request_item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Material Request', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Material Request', 'create'))::uuid[]));
drop policy if exists material_request_item_update on public.material_request_item;
create policy material_request_item_update on public.material_request_item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Material Request', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Material Request', 'write'))::uuid[]));
drop policy if exists material_request_item_delete on public.material_request_item;
create policy material_request_item_delete on public.material_request_item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Material Request', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default
) values (
  'Material Request', 'material_request', 'stock', true, 'title', 'MAT-MR-.YYYY.-'
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Material Request Item', 'material_request_item', 'stock', true, 'Material Request', 'items')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Material Request', true, false, false, false, false, false, false),
  ('Purchase Manager', 'Material Request', true, true, true, true, true, true, true),
  ('Purchase User', 'Material Request', true, true, true, true, true, true, true),
  ('Stock Manager', 'Material Request', true, true, true, true, true, true, true),
  ('Stock User', 'Material Request', true, true, true, true, true, true, true),
  ('Manufacturing Manager', 'Material Request', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
