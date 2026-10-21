-- 0501 selling: Quotation (docs/modules/02-selling.md §2.10, §3.4, §5.1).
-- ERPNext: erpnext/selling/doctype/quotation/quotation.py
--   (validate_valid_till, validate_revision, on_submit, declare_enquiry_lost, set_expired_status)
-- ERPNext: erpnext/selling/doctype/quotation/mapper.py (make_revision)
-- Header totals are the sum of item amounts. Tax rows, the payment schedule, packed items,
-- and app.map_doc stay on their own checklist lines. selling_settings is not built, so the
-- A20 defaults are fixed here: duplicate items are allowed, zero qty is rejected, and the
-- selling-price check is off. There is no sales order, so cancel does not look for one.

create table if not exists public.quotation (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  name                    text not null,
  customer_name           text,
  naming_series           text not null default 'SAL-QTN-.YYYY.-',
  quotation_to            text not null default 'Customer' check (quotation_to = 'Customer'),
  customer_id             uuid not null,
  company_id              uuid not null,
  transaction_date        date not null default current_date,
  valid_till              date,
  is_active               boolean not null default true,
  is_latest_revision      boolean not null default false,
  revision_of             uuid,
  order_type              text not null default 'Sales'
    check (order_type in ('Sales', 'Maintenance', 'Shopping Cart')),
  currency                text not null,
  conversion_rate         numeric(21,9) not null default 1,
  selling_price_list_id   uuid not null,
  status                  text not null default 'Draft'
    check (status in (
      'Draft', 'Open', 'Replied', 'Lost', 'Ordered', 'Partially Ordered', 'Expired', 'Cancelled'
    )),
  order_lost_reason       text,
  total                   numeric(21,9) not null default 0,
  net_total               numeric(21,9) not null default 0,
  grand_total             numeric(21,9) not null default 0,
  base_grand_total        numeric(21,9) not null default 0,
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
  foreign key (org_id, selling_price_list_id) references public.price_list (org_id, id),
  foreign key (org_id, revision_of) references public.quotation (org_id, id),
  foreign key (org_id, amended_from) references public.quotation (org_id, id) on delete set null (amended_from)
);

create index if not exists quotation_customer_idx on public.quotation (org_id, customer_id);
create index if not exists quotation_company_idx on public.quotation (org_id, company_id);
create index if not exists quotation_price_list_idx on public.quotation (org_id, selling_price_list_id);
create index if not exists quotation_revision_idx on public.quotation (org_id, revision_of);
create index if not exists quotation_amended_idx on public.quotation (org_id, amended_from);
create index if not exists quotation_date_idx on public.quotation (org_id, transaction_date);

create table if not exists public.quotation_item (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null,
  parent_id             uuid not null,
  idx                   int not null,
  item_id               uuid not null,
  item_name             text,
  qty                   numeric(21,9) not null,
  uom_id                uuid,
  stock_uom_id          uuid,
  conversion_factor     numeric(21,9) not null default 1,
  stock_qty             numeric(21,9) not null default 0,
  price_list_rate       numeric(21,9),
  discount_percentage   numeric(21,9) not null default 0,
  rate                  numeric(21,9),
  amount                numeric(21,9) not null default 0,
  net_rate              numeric(21,9) not null default 0,
  net_amount            numeric(21,9) not null default 0,
  warehouse_id          uuid,
  is_alternative        boolean not null default false,
  is_free_item          boolean not null default false,
  ordered_qty           numeric(21,9) not null default 0,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.quotation (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, uom_id) references public.uom (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id)
);

create index if not exists quotation_item_parent_idx on public.quotation_item (org_id, parent_id);
create index if not exists quotation_item_item_idx on public.quotation_item (org_id, item_id);
create index if not exists quotation_item_uom_idx on public.quotation_item (org_id, uom_id);
create index if not exists quotation_item_stock_uom_idx on public.quotation_item (org_id, stock_uom_id);
create index if not exists quotation_item_wh_idx on public.quotation_item (org_id, warehouse_id);

create table if not exists public.quotation_lost_reason_detail (
  id                         uuid primary key default gen_random_uuid(),
  org_id                     uuid not null,
  parent_id                  uuid not null,
  idx                        int not null,
  quotation_lost_reason_id   uuid not null,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.quotation (org_id, id) on delete cascade,
  foreign key (org_id, quotation_lost_reason_id) references public.quotation_lost_reason (org_id, id)
);

create index if not exists quotation_lost_reason_detail_parent_idx
  on public.quotation_lost_reason_detail (org_id, parent_id);
create index if not exists quotation_lost_reason_detail_reason_idx
  on public.quotation_lost_reason_detail (org_id, quotation_lost_reason_id);

-- Draft saves recompute party, currency, and revision rules. Submitted status changes
-- (Set as Lost, expire, latest-revision) skip those checks so a later job can still write.
create or replace function app.quotation_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  v_customer_name text;
  v_customer_doc text;
  v_disabled boolean;
  v_frozen boolean;
  v_party_currency text;
  v_company_currency text;
  v_list_name text;
  v_enabled boolean;
  v_selling boolean;
  v_root_name text;
  v_root_company uuid;
  v_root_customer uuid;
  v_root_status text;
  v_latest date;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
  end if;
  if new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'SAL-QTN-.YYYY.-';
  end if;
  if new.transaction_date is null then
    new.transaction_date := current_date;
  end if;
  if new.quotation_to is null or btrim(new.quotation_to) = '' then
    new.quotation_to := 'Customer';
  end if;
  if new.quotation_to <> 'Customer' then
    raise exception using errcode = 'P0001', message = 'quotation_party: Quotation To must be Customer';
  end if;
  if new.order_type is null or btrim(new.order_type) = '' then
    new.order_type := 'Sales';
  end if;
  if new.order_type not in ('Sales', 'Maintenance', 'Shopping Cart') then
    raise exception using errcode = 'P0001',
      message = 'quotation_order: Order Type must be Sales, Maintenance, or Shopping Cart';
  end if;
  if new.docstatus is null then
    new.docstatus := 0;
  end if;
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;

  if tg_op = 'INSERT' or new.docstatus = 0 then
    if new.customer_id is null then
      raise exception using errcode = 'P0001', message = 'quotation_customer: Customer is required';
    end if;
    select c.customer_name, c.name, c.disabled, c.is_frozen, c.default_currency
      into v_customer_name, v_customer_doc, v_disabled, v_frozen, v_party_currency
      from public.customer c
     where c.id = new.customer_id and c.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'quotation_customer: Customer is required';
    end if;
    if v_disabled then
      raise exception using errcode = 'P0001',
        message = format('quotation_customer: Customer %s is disabled', v_customer_doc);
    end if;
    if v_frozen then
      raise exception using errcode = 'P0001',
        message = format('quotation_customer: Customer %s is frozen', v_customer_doc);
    end if;
    new.customer_name := v_customer_name;

    if new.company_id is null then
      raise exception using errcode = 'P0001', message = 'quotation_company: Company is required';
    end if;
    select c.default_currency into v_company_currency
      from public.companies c
     where c.id = new.company_id and c.org_id = new.org_id;
    if v_company_currency is null then
      raise exception using errcode = 'P0001', message = 'quotation_company: Company is required';
    end if;
    if new.currency is null or btrim(new.currency) = '' then
      new.currency := coalesce(nullif(btrim(v_party_currency), ''), v_company_currency);
    end if;
    if new.currency = v_company_currency then
      new.conversion_rate := 1;
    elsif new.conversion_rate is null or new.conversion_rate = 0 then
      raise exception using errcode = 'P0001', message = 'quotation_rate: Exchange Rate is required';
    end if;

    if new.selling_price_list_id is null then
      raise exception using errcode = 'P0001', message = 'quotation_price_list: Selling Price List is required';
    end if;
    select p.price_list_name, p.enabled, p.selling
      into v_list_name, v_enabled, v_selling
      from public.price_list p
     where p.id = new.selling_price_list_id and p.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'quotation_price_list: Selling Price List is required';
    end if;
    if not v_enabled or not v_selling then
      raise exception using errcode = 'P0001',
        message = format('quotation_price_list: Price List %s is not a selling price list', v_list_name);
    end if;

    if new.valid_till is not null and new.valid_till < new.transaction_date then
      raise exception using errcode = 'P0001',
        message = 'quotation_date: Valid till date cannot be before transaction date';
    end if;

    if new.revision_of is not null and (
      tg_op = 'INSERT'
      or new.company_id is distinct from old.company_id
      or new.customer_id is distinct from old.customer_id
      or new.revision_of is distinct from old.revision_of
      or new.transaction_date is distinct from old.transaction_date
    ) then
      select q.name, q.company_id, q.customer_id, q.status
        into v_root_name, v_root_company, v_root_customer, v_root_status
        from public.quotation q
       where q.id = new.revision_of and q.org_id = new.org_id;
      if not found then
        raise exception using errcode = 'P0001', message = 'quotation_revise: The original Quotation was not found';
      end if;
      if new.company_id is distinct from v_root_company then
        raise exception using errcode = 'P0001',
          message = format('quotation_revise: A revision must have the same company as Quotation %s.', v_root_name);
      end if;
      if new.customer_id is distinct from v_root_customer then
        raise exception using errcode = 'P0001',
          message = format('quotation_revise: A revision must be for the same Customer as Quotation %s.', v_root_name);
      end if;
      if tg_op = 'INSERT' and (
        v_root_status = 'Lost'
        or exists (
          select 1 from public.quotation o
           where o.org_id = new.org_id
             and o.docstatus = 1
             and o.status = 'Lost'
             and (o.id = new.revision_of or o.revision_of = new.revision_of)
        )
      ) then
        raise exception using errcode = 'P0001',
          message = format('quotation_revise: Quotation %s is Lost and cannot be revised.', v_root_name);
      end if;
      select max(o.transaction_date) into v_latest
        from public.quotation o
       where o.org_id = new.org_id
         and o.id is distinct from new.id
         and o.docstatus = 1
         and (o.id = new.revision_of or o.revision_of = new.revision_of);
      if v_latest is not null and new.transaction_date <= v_latest then
        raise exception using errcode = 'P0001',
          message = format(
            'quotation_revision: Transaction Date must be after %s, the date of the latest version of this Quotation.',
            to_char(v_latest, 'YYYY-MM-DD')
          );
      end if;
    end if;
  end if;

  if new.status is null or btrim(new.status) = '' then
    new.status := 'Draft';
  end if;
  if new.docstatus = 0 and current_user = 'authenticated' then
    new.status := 'Draft';
  end if;
  if new.is_active is null then
    new.is_active := true;
  end if;
  if new.is_latest_revision is null then
    new.is_latest_revision := false;
  end if;
  new.total := coalesce(new.total, 0);
  new.net_total := coalesce(new.net_total, 0);
  new.grand_total := coalesce(new.grand_total, 0);
  new.conversion_rate := coalesce(new.conversion_rate, 1);
  new.base_grand_total := new.grand_total * new.conversion_rate;
  return new;
end;
$fn$;

create or replace function app.quotation_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  h public.quotation;
  v_code text;
  v_item_name text;
  v_disabled boolean;
  v_sales boolean;
  v_stock uuid;
  v_max numeric;
  v_factor numeric;
  v_whole boolean;
  v_max_text text;
begin
  if new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001',
      message = format('quotation_qty: Row %s: Quantity must be greater than zero', coalesce(new.idx, 0));
  end if;
  select * into h from public.quotation where id = new.parent_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'quotation_item: Quotation is required';
  end if;
  if h.docstatus <> 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;

  select i.item_code, i.item_name, i.disabled, i.is_sales_item, i.stock_uom_id, i.max_discount
    into v_code, v_item_name, v_disabled, v_sales, v_stock, v_max
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'quotation_item: Item is required';
  end if;
  if v_disabled then
    raise exception using errcode = 'P0001',
      message = format('quotation_item: Item %s is disabled', v_code);
  end if;
  if not coalesce(v_sales, false) then
    raise exception using errcode = 'P0001',
      message = format('quotation_item: Item %s is not a sales item', v_code);
  end if;
  if new.item_name is null or btrim(new.item_name) = '' then
    new.item_name := v_item_name;
  end if;

  if new.uom_id is null or new.uom_id = v_stock then
    new.uom_id := v_stock;
    new.conversion_factor := 1;
  else
    select u.conversion_factor into v_factor
      from public.item_uom u
     where u.parent_id = new.item_id and u.uom_id = new.uom_id;
    if v_factor is null then
      raise exception using errcode = 'P0001',
        message = format('quotation_uom: Row %s: UOM is not allowed for this item', coalesce(new.idx, 0));
    end if;
    new.conversion_factor := v_factor;
  end if;
  new.stock_uom_id := v_stock;
  select u.must_be_whole_number into v_whole from public.uom u where u.id = new.uom_id;
  if coalesce(v_whole, false) and new.qty <> trunc(new.qty) then
    raise exception using errcode = 'P0001',
      message = format('quotation_uom: Row %s: Qty cannot be a fraction', coalesce(new.idx, 0));
  end if;

  new.discount_percentage := coalesce(new.discount_percentage, 0);
  if v_max is not null and new.discount_percentage > v_max then
    v_max_text := trim(trailing '.' from trim(trailing '0' from v_max::text));
    raise exception using errcode = 'P0001',
      message = format('quotation_discount: Maximum discount for Item %s is %s%%', v_code, v_max_text);
  end if;
  if new.rate is null then
    new.rate := coalesce(new.price_list_rate, 0) * (1 - new.discount_percentage / 100);
  end if;
  new.amount := app.round(new.qty * new.rate, 2);
  new.net_rate := new.rate;
  new.net_amount := new.amount;
  new.stock_qty := new.qty * new.conversion_factor;
  new.ordered_qty := coalesce(new.ordered_qty, 0);
  new.is_alternative := coalesce(new.is_alternative, false);
  new.is_free_item := coalesce(new.is_free_item, false);
  return new;
end;
$fn$;

create or replace function app.quotation_item_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_parent uuid := case when tg_op = 'DELETE' then old.parent_id else new.parent_id end;
begin
  update public.quotation q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.quotation_item i
       where i.parent_id = v_parent
    ) s
   where q.id = v_parent;
  return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

-- One submitted version of a root is latest: newest transaction_date, then created_at.
-- p_include is the row being submitted (still a draft). p_exclude is the row being cancelled.
create or replace function app.quotation_refresh_latest(p_root uuid, p_include uuid, p_exclude uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_org uuid;
begin
  select q.org_id into v_org from public.quotation q where q.id = p_root;
  if v_org is null then
    return;
  end if;
  with family as (
    select q.id, q.transaction_date, q.created_at
      from public.quotation q
     where q.org_id = v_org
       and (q.id = p_root or q.revision_of = p_root)
       and q.id is distinct from p_exclude
       and (q.docstatus = 1 or q.id is not distinct from p_include)
  ),
  winner as (
    select f.id
      from family f
     order by f.transaction_date desc, f.created_at desc
     limit 1
  )
  update public.quotation q
     set is_latest_revision = (q.id is not distinct from (select w.id from winner w))
   where q.org_id = v_org
     and (
       q.id in (select f.id from family f)
       or q.id is not distinct from p_exclude
     );
end;
$fn$;

create or replace function app.on_submit__quotation(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count int;
  v_company uuid;
  v_base numeric;
  v_revision uuid;
  v_active boolean;
  v_org uuid;
begin
  select count(*) into v_count from public.quotation_item i where i.parent_id = p_id;
  if v_count = 0 then
    raise exception using errcode = 'P0001', message = 'quotation_items: Items are required';
  end if;

  update public.quotation q
     set status = 'Open',
         total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.quotation_item i
       where i.parent_id = p_id
    ) s
   where q.id = p_id
  returning q.company_id, q.base_grand_total, q.revision_of, q.is_active, q.org_id
    into v_company, v_base, v_revision, v_active, v_org;

  perform app.validate_approving_authority('Quotation', v_company, v_base);

  if v_revision is not null and v_active then
    update public.quotation o
       set is_active = false
     where o.org_id = v_org
       and o.id <> p_id
       and o.docstatus = 1
       and o.is_active
       and (o.id = v_revision or o.revision_of = v_revision);
  end if;

  perform app.quotation_refresh_latest(coalesce(v_revision, p_id), p_id, null);
end;
$fn$;

create or replace function app.on_cancel__quotation(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_root uuid;
begin
  update public.quotation set status = 'Cancelled' where id = p_id;
  select coalesce(q.revision_of, q.id) into v_root from public.quotation q where q.id = p_id;
  perform app.quotation_refresh_latest(v_root, null, p_id);
end;
$fn$;

create or replace function app.revise_quotation(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  q public.quotation;
  v_root uuid;
  v_root_name text;
  v_like text;
  v_n int;
  v_id uuid;
  v_name text;
begin
  select * into q from public.quotation where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Quotation not found';
  end if;
  if not app.has_perm(q.org_id, 'Quotation', 'write') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if q.docstatus <> 1 or q.status in ('Lost', 'Ordered') then
    raise exception using errcode = 'P0001',
      message = format('quotation_revise: Cannot revise a Quotation with status %s.', q.status);
  end if;

  v_root := coalesce(q.revision_of, q.id);
  select r.name into v_root_name from public.quotation r where r.id = v_root;
  v_like := replace(replace(replace(v_root_name, '\', '\\'), '%', '\%'), '_', '\_') || '-R%';
  select coalesce(max((regexp_match(r.name, '-R([0-9]+)$'))[1]::int), 0) + 1
    into v_n
    from public.quotation r
   where r.org_id = q.org_id
     and r.name like v_like escape '\';
  v_name := v_root_name || '-R' || v_n::text;

  insert into public.quotation (
    org_id, name, naming_series, quotation_to, customer_id, company_id,
    transaction_date, valid_till, is_active, is_latest_revision, revision_of,
    order_type, currency, conversion_rate, selling_price_list_id, status,
    total, net_total, grand_total, base_grand_total, docstatus
  ) values (
    q.org_id, v_name, q.naming_series, 'Customer', q.customer_id, q.company_id,
    current_date, null, true, false, v_root,
    q.order_type, q.currency, q.conversion_rate, q.selling_price_list_id, 'Draft',
    0, 0, 0, 0, 0
  ) returning id into v_id;

  insert into public.quotation_item (
    org_id, parent_id, idx, item_id, item_name, qty, uom_id, stock_uom_id,
    conversion_factor, stock_qty, price_list_rate, discount_percentage, rate,
    amount, net_rate, net_amount, warehouse_id, is_alternative, is_free_item, ordered_qty
  )
  select
    i.org_id, v_id, i.idx, i.item_id, i.item_name, i.qty, i.uom_id, i.stock_uom_id,
    i.conversion_factor, i.stock_qty, i.price_list_rate, i.discount_percentage, i.rate,
    i.amount, i.net_rate, i.net_amount, i.warehouse_id, i.is_alternative, i.is_free_item, 0
    from public.quotation_item i
   where i.parent_id = q.id
   order by i.idx;

  return jsonb_build_object('id', v_id, 'name', v_name);
end;
$fn$;

create or replace function app.set_quotation_lost(p_id uuid, p_reason_id uuid, p_detail text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  q public.quotation;
  v_root uuid;
  v_reason text;
  v_detail text;
begin
  select * into q from public.quotation where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Quotation not found';
  end if;
  if not app.has_perm(q.org_id, 'Quotation', 'write') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if q.docstatus <> 1 then
    raise exception using errcode = 'P0001',
      message = format('quotation_lost: Cannot set as Lost a Quotation with status %s.', q.status);
  end if;

  v_root := coalesce(q.revision_of, q.id);
  if q.status in ('Ordered', 'Partially Ordered') or exists (
    select 1 from public.quotation o
     where o.org_id = q.org_id
       and o.docstatus = 1
       and o.status in ('Ordered', 'Partially Ordered')
       and (o.id = v_root or o.revision_of = v_root)
  ) then
    raise exception using errcode = 'P0001',
      message = 'quotation_lost: Cannot set as Lost as Sales Order is made.';
  end if;

  select r.order_lost_reason into v_reason
    from public.quotation_lost_reason r
   where r.id = p_reason_id and r.org_id = q.org_id;
  if not found then
    raise exception using errcode = 'P0001',
      message = format(
        'quotation_lost: Invalid lost reason %s, please create a new lost reason',
        coalesce(p_reason_id::text, '')
      );
  end if;

  v_detail := nullif(btrim(coalesce(p_detail, '')), '');
  update public.quotation
     set status = 'Lost', is_active = true, order_lost_reason = v_detail
   where id = p_id;
  delete from public.quotation_lost_reason_detail where parent_id = p_id;
  insert into public.quotation_lost_reason_detail (org_id, parent_id, idx, quotation_lost_reason_id)
  values (q.org_id, p_id, 1, p_reason_id);
  update public.quotation o
     set status = 'Lost', is_active = false
   where o.org_id = q.org_id
     and o.id <> p_id
     and o.docstatus = 1
     and o.status not in ('Ordered', 'Partially Ordered')
     and (o.id = v_root or o.revision_of = v_root);

  return jsonb_build_object('id', p_id, 'order_lost_reason', v_reason);
end;
$fn$;

-- Daily. Does not call a status map: Expired is not in that map, and a later refresh would reopen it.
create or replace function app.expire_quotations()
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  update public.quotation
     set status = 'Expired'
   where docstatus = 1
     and valid_till is not null
     and valid_till < current_date
     and status not in ('Lost', 'Expired');
end;
$fn$;

revoke all on function app.quotation_validate() from public, anon, authenticated;
revoke all on function app.quotation_item_validate() from public, anon, authenticated;
revoke all on function app.quotation_item_sync() from public, anon, authenticated;
revoke all on function app.quotation_refresh_latest(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function app.on_submit__quotation(uuid) from public, anon, authenticated;
revoke all on function app.on_cancel__quotation(uuid) from public, anon, authenticated;
revoke execute on function app.expire_quotations() from public, anon, authenticated;

revoke all on function app.revise_quotation(uuid) from public, anon;
revoke all on function app.set_quotation_lost(uuid, uuid, text) from public, anon;
grant execute on function app.revise_quotation(uuid) to authenticated;
grant execute on function app.set_quotation_lost(uuid, uuid, text) to authenticated;

create or replace function public.revise_quotation(p_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.revise_quotation(p_id);
$$;

create or replace function public.set_quotation_lost(p_id uuid, p_reason_id uuid, p_detail text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.set_quotation_lost(p_id, p_reason_id, p_detail);
$$;

revoke all on function public.revise_quotation(uuid) from public, anon;
revoke all on function public.set_quotation_lost(uuid, uuid, text) from public, anon;
grant execute on function public.revise_quotation(uuid) to authenticated;
grant execute on function public.set_quotation_lost(uuid, uuid, text) to authenticated;

-- After fiscal year (00:15) and before reorder (00:45). Re-running replaces the job.
select cron.schedule('expire-quotations', '20 0 * * *', 'select app.expire_quotations()');

drop trigger if exists quotation_validate on public.quotation;
create trigger quotation_validate before insert or update on public.quotation
  for each row execute function app.quotation_validate();
drop trigger if exists touch_updated on public.quotation;
create trigger touch_updated before update on public.quotation
  for each row execute function app.touch_updated();
drop trigger if exists quotation_item_validate on public.quotation_item;
create trigger quotation_item_validate before insert or update on public.quotation_item
  for each row execute function app.quotation_item_validate();
drop trigger if exists quotation_item_sync on public.quotation_item;
create trigger quotation_item_sync after insert or update or delete on public.quotation_item
  for each row execute function app.quotation_item_sync();

alter table public.quotation enable row level security;
alter table public.quotation force row level security;
alter table public.quotation_item enable row level security;
alter table public.quotation_item force row level security;
alter table public.quotation_lost_reason_detail enable row level security;
alter table public.quotation_lost_reason_detail force row level security;

drop policy if exists quotation_select on public.quotation;
create policy quotation_select on public.quotation for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation', 'read'))::uuid[]));
drop policy if exists quotation_insert on public.quotation;
create policy quotation_insert on public.quotation for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Quotation', 'create'))::uuid[]));
drop policy if exists quotation_update on public.quotation;
create policy quotation_update on public.quotation for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]));
drop policy if exists quotation_delete on public.quotation;
create policy quotation_delete on public.quotation for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists quotation_item_select on public.quotation_item;
create policy quotation_item_select on public.quotation_item for select to authenticated
  using (exists (select 1 from public.quotation p where p.id = parent_id));
drop policy if exists quotation_item_insert on public.quotation_item;
create policy quotation_item_insert on public.quotation_item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Quotation', 'create'))::uuid[]));
drop policy if exists quotation_item_update on public.quotation_item;
create policy quotation_item_update on public.quotation_item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]));
drop policy if exists quotation_item_delete on public.quotation_item;
create policy quotation_item_delete on public.quotation_item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]));

drop policy if exists quotation_lost_reason_detail_select on public.quotation_lost_reason_detail;
create policy quotation_lost_reason_detail_select on public.quotation_lost_reason_detail for select to authenticated
  using (exists (select 1 from public.quotation p where p.id = parent_id));
drop policy if exists quotation_lost_reason_detail_insert on public.quotation_lost_reason_detail;
create policy quotation_lost_reason_detail_insert on public.quotation_lost_reason_detail for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Quotation', 'create'))::uuid[]));
drop policy if exists quotation_lost_reason_detail_update on public.quotation_lost_reason_detail;
create policy quotation_lost_reason_detail_update on public.quotation_lost_reason_detail for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]));
drop policy if exists quotation_lost_reason_detail_delete on public.quotation_lost_reason_detail;
create policy quotation_lost_reason_detail_delete on public.quotation_lost_reason_detail for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default
) values (
  'Quotation', 'quotation', 'selling', true, 'customer_name', 'SAL-QTN-.YYYY.-'
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Quotation Item', 'quotation_item', 'selling', true, 'Quotation', 'items'),
  ('Quotation Lost Reason Detail', 'quotation_lost_reason_detail', 'selling', true, 'Quotation', 'lost_reasons')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Quotation', true, false, false, false, false, false, false),
  ('Sales User', 'Quotation', true, true, true, true, true, true, true),
  ('Sales Manager', 'Quotation', true, true, true, true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
