-- 0502 selling: Sales Order (docs/modules/02-selling.md §2.11, §3.6, §5.2).
-- ERPNext: erpnext/selling/doctype/sales_order/sales_order.py
--   (validate_delivery_date, validate_po, validate_warehouse, check_credit_limit, on_submit, on_cancel)
-- ERPNext: erpnext/selling/doctype/sales_order/services/status.py (update_status, set_status)
-- ERPNext: erpnext/selling/doctype/customer/customer.py (check_credit_limit)
-- Header totals are the sum of item amounts. Taxes, the payment schedule, packed items,
-- app.map_doc, and app.update_prevdoc_status stay on their own checklist lines.
-- selling_settings is not built, so the A20 defaults are fixed here: duplicate items are
-- allowed, zero qty is rejected, the selling-price check is off, skip-delivery is off,
-- and a repeated customer PO is rejected. Quotation ordered qty is not written.

create table if not exists public.sales_order (
  id                       uuid primary key default gen_random_uuid(),
  org_id                   uuid not null references public.organizations (id) on delete cascade,
  name                     text not null,
  customer_name            text,
  naming_series            text not null default 'SAL-ORD-.YYYY.-',
  customer_id              uuid not null,
  company_id               uuid not null,
  transaction_date         date not null default current_date,
  delivery_date            date,
  po_no                    text,
  po_date                  date,
  tax_id                   text,
  set_warehouse_id         uuid,
  cost_center_id           uuid,
  order_type               text not null default 'Sales'
    check (order_type in ('Sales', 'Maintenance', 'Shopping Cart')),
  currency                 text not null,
  conversion_rate          numeric(21,9) not null default 1,
  selling_price_list_id    uuid not null,
  status                   text not null default 'Draft'
    check (status in (
      'Draft', 'On Hold', 'Closed', 'Cancelled', 'Completed', 'To Pay',
      'To Deliver', 'To Bill', 'To Deliver and Bill'
    )),
  per_delivered            numeric(21,9) not null default 0,
  per_billed               numeric(21,9) not null default 0,
  per_picked               numeric(21,9) not null default 0,
  delivery_status          text not null default 'Not Delivered'
    check (delivery_status in (
      'Not Delivered', 'Fully Delivered', 'Partly Delivered', 'Closed', 'Not Applicable'
    )),
  billing_status           text not null default 'Not Billed'
    check (billing_status in ('Not Billed', 'Fully Billed', 'Partly Billed', 'Closed')),
  advance_paid             numeric(21,9) not null default 0,
  advance_payment_status   text not null default 'Not Requested'
    check (advance_payment_status in ('Not Requested', 'Requested', 'Partially Paid', 'Fully Paid')),
  skip_delivery_note       boolean not null default false,
  reserve_stock            boolean not null default false,
  total                    numeric(21,9) not null default 0,
  net_total                numeric(21,9) not null default 0,
  grand_total              numeric(21,9) not null default 0,
  base_grand_total         numeric(21,9) not null default 0,
  docstatus                smallint not null default 0 check (docstatus in (0, 1, 2)),
  amended_from             uuid,
  created_at               timestamptz not null default now(),
  created_by               uuid default auth.uid(),
  updated_at               timestamptz not null default now(),
  updated_by               uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, customer_id) references public.customer (org_id, id),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, selling_price_list_id) references public.price_list (org_id, id),
  foreign key (org_id, set_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  foreign key (org_id, amended_from) references public.sales_order (org_id, id) on delete set null (amended_from)
);

create index if not exists sales_order_customer_idx on public.sales_order (org_id, customer_id);
create index if not exists sales_order_company_idx on public.sales_order (org_id, company_id);
create index if not exists sales_order_price_list_idx on public.sales_order (org_id, selling_price_list_id);
create index if not exists sales_order_warehouse_idx on public.sales_order (org_id, set_warehouse_id);
create index if not exists sales_order_cost_center_idx on public.sales_order (org_id, cost_center_id);
create index if not exists sales_order_amended_idx on public.sales_order (org_id, amended_from);
create index if not exists sales_order_po_idx on public.sales_order (org_id, customer_id, po_no);

create table if not exists public.sales_order_item (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null,
  parent_id              uuid not null,
  idx                    int not null,
  item_id                uuid not null,
  item_name              text,
  qty                    numeric(21,9) not null,
  uom_id                 uuid,
  stock_uom_id           uuid,
  conversion_factor      numeric(21,9) not null default 1,
  stock_qty              numeric(21,9) not null default 0,
  price_list_rate        numeric(21,9),
  discount_percentage    numeric(21,9) not null default 0,
  rate                   numeric(21,9),
  amount                 numeric(21,9) not null default 0,
  net_rate               numeric(21,9) not null default 0,
  net_amount             numeric(21,9) not null default 0,
  warehouse_id           uuid,
  delivery_date          date,
  prevdoc_id             uuid,
  quotation_item_id      uuid,
  billed_amt             numeric(21,9) not null default 0,
  delivered_qty          numeric(21,9) not null default 0,
  returned_qty           numeric(21,9) not null default 0,
  picked_qty             numeric(21,9) not null default 0,
  work_order_qty         numeric(21,9) not null default 0,
  closed                 boolean not null default false,
  grant_commission       boolean not null default true,
  delivered_by_supplier  boolean not null default false,
  supplier_id            uuid,
  skip_delivery          boolean not null default false,
  is_stock_item          boolean not null default true,
  cost_center_id         uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.sales_order (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, uom_id) references public.uom (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, prevdoc_id) references public.quotation (org_id, id),
  foreign key (org_id, quotation_item_id) references public.quotation_item (org_id, id),
  foreign key (org_id, supplier_id) references public.supplier (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id)
);

create index if not exists sales_order_item_parent_idx on public.sales_order_item (org_id, parent_id);
create index if not exists sales_order_item_item_idx on public.sales_order_item (org_id, item_id);
create index if not exists sales_order_item_uom_idx on public.sales_order_item (org_id, uom_id);
create index if not exists sales_order_item_stock_uom_idx on public.sales_order_item (org_id, stock_uom_id);
create index if not exists sales_order_item_wh_idx on public.sales_order_item (org_id, warehouse_id);
create index if not exists sales_order_item_quotation_idx on public.sales_order_item (org_id, prevdoc_id);
create index if not exists sales_order_item_qi_idx on public.sales_order_item (org_id, quotation_item_id);
create index if not exists sales_order_item_supplier_idx on public.sales_order_item (org_id, supplier_id);
create index if not exists sales_order_item_cc_idx on public.sales_order_item (org_id, cost_center_id);

-- Draft saves recompute party, currency, delivery date, and the customer PO.
-- Submitted status changes (Close, Hold, Re-open) skip those checks.
create or replace function app.sales_order_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  v_customer_name text;
  v_customer_doc text;
  v_disabled boolean;
  v_frozen boolean;
  v_tax_id text;
  v_party_currency text;
  v_company_currency text;
  v_list_name text;
  v_enabled boolean;
  v_selling boolean;
  v_other text;
  v_max date;
  v_idx int;
  v_check_po boolean;
  v_check_po_date boolean;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
  end if;
  if new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'SAL-ORD-.YYYY.-';
  end if;
  if new.transaction_date is null then
    new.transaction_date := current_date;
  end if;
  if new.order_type is null or btrim(new.order_type) = '' then
    new.order_type := 'Sales';
  end if;
  if new.order_type not in ('Sales', 'Maintenance', 'Shopping Cart') then
    raise exception using errcode = 'P0001',
      message = 'so_order: Order Type must be Sales, Maintenance, or Shopping Cart';
  end if;
  if new.docstatus is null then
    new.docstatus := 0;
  end if;
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  if tg_op = 'UPDATE' and new.docstatus = 1 and current_user = 'authenticated'
     and new.status is distinct from old.status then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  if new.po_no is not null and btrim(new.po_no) = '' then
    new.po_no := null;
  end if;

  if tg_op = 'INSERT' or new.docstatus = 0 then
    new.skip_delivery_note := false;
    if new.customer_id is null then
      raise exception using errcode = 'P0001', message = 'so_customer: Customer is required';
    end if;
    select c.customer_name, c.name, c.disabled, c.is_frozen, c.default_currency, c.tax_id
      into v_customer_name, v_customer_doc, v_disabled, v_frozen, v_party_currency, v_tax_id
      from public.customer c
     where c.id = new.customer_id and c.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'so_customer: Customer is required';
    end if;
    if v_disabled then
      raise exception using errcode = 'P0001',
        message = format('so_customer: Customer %s is disabled', v_customer_doc);
    end if;
    if v_frozen then
      raise exception using errcode = 'P0001',
        message = format('so_customer: Customer %s is frozen', v_customer_doc);
    end if;
    new.customer_name := v_customer_name;
    new.tax_id := v_tax_id;

    if new.company_id is null then
      raise exception using errcode = 'P0001', message = 'so_company: Company is required';
    end if;
    select c.default_currency into v_company_currency
      from public.companies c
     where c.id = new.company_id and c.org_id = new.org_id;
    if v_company_currency is null then
      raise exception using errcode = 'P0001', message = 'so_company: Company is required';
    end if;
    if new.currency is null or btrim(new.currency) = '' then
      new.currency := coalesce(nullif(btrim(v_party_currency), ''), v_company_currency);
    end if;
    if new.currency = v_company_currency then
      new.conversion_rate := 1;
    elsif new.conversion_rate is null or new.conversion_rate = 0 then
      raise exception using errcode = 'P0001', message = 'so_rate: Exchange Rate is required';
    end if;

    if new.selling_price_list_id is null then
      raise exception using errcode = 'P0001', message = 'so_price_list: Selling Price List is required';
    end if;
    select p.price_list_name, p.enabled, p.selling
      into v_list_name, v_enabled, v_selling
      from public.price_list p
     where p.id = new.selling_price_list_id and p.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'so_price_list: Selling Price List is required';
    end if;
    if not v_enabled or not v_selling then
      raise exception using errcode = 'P0001',
        message = format('so_price_list: Price List %s is not a selling price list', v_list_name);
    end if;

    if new.order_type = 'Sales' and not new.skip_delivery_note then
      select max(i.delivery_date) into v_max
        from public.sales_order_item i
       where i.parent_id = new.id and not i.skip_delivery and i.delivery_date is not null;
      if v_max is not null and new.delivery_date is distinct from v_max then
        new.delivery_date := v_max;
      end if;
    end if;
  end if;

  v_check_po := tg_op = 'INSERT' or new.docstatus = 0;
  if tg_op = 'UPDATE' and (new.po_no is distinct from old.po_no or new.customer_id is distinct from old.customer_id) then
    v_check_po := true;
  end if;
  if v_check_po and new.po_no is not null and new.customer_id is not null and new.order_type = 'Sales'
     and not coalesce(new.skip_delivery_note, false) then
    select o.name into v_other
      from public.sales_order o
     where o.org_id = new.org_id
       and o.customer_id = new.customer_id
       and o.po_no = new.po_no
       and o.docstatus < 2
       and o.id <> new.id
     limit 1;
    if v_other is not null then
      raise exception using errcode = 'P0001',
        message = format(
          'so_po: Sales Order %s already exists against Customer''s Purchase Order %s. To allow multiple Sales Orders, Enable Allow multiple Sales Orders against a Customer''s Purchase Order in Selling Settings',
          v_other, new.po_no
        );
    end if;
  end if;

  v_check_po_date := tg_op = 'INSERT' or new.docstatus = 0;
  if tg_op = 'UPDATE' and new.po_date is distinct from old.po_date then
    v_check_po_date := true;
  end if;
  if v_check_po_date and new.po_date is not null then
    select i.idx into v_idx
      from public.sales_order_item i
     where i.parent_id = new.id
       and i.delivery_date is not null
       and new.po_date > i.delivery_date
     order by i.idx
     limit 1;
    if v_idx is not null then
      raise exception using errcode = 'P0001',
        message = format(
          'so_delivery_date: Row %s: Expected Delivery Date cannot be before Purchase Order Date',
          v_idx
        );
    end if;
  end if;

  if new.status is null or btrim(new.status) = '' then
    new.status := 'Draft';
  end if;
  if new.docstatus = 2 then
    new.status := 'Cancelled';
  elsif new.docstatus = 0 then
    new.per_delivered := 0;
    new.per_billed := 0;
    new.per_picked := 0;
    new.advance_paid := 0;
    new.skip_delivery_note := false;
    new.delivery_status := 'Not Delivered';
    new.billing_status := 'Not Billed';
    new.advance_payment_status := 'Not Requested';
    if current_user = 'authenticated' then
      new.status := 'Draft';
    end if;
  end if;
  new.reserve_stock := coalesce(new.reserve_stock, false);
  new.total := coalesce(new.total, 0);
  new.net_total := coalesce(new.net_total, 0);
  new.grand_total := coalesce(new.grand_total, 0);
  new.conversion_rate := coalesce(new.conversion_rate, 1);
  new.base_grand_total := new.grand_total * new.conversion_rate;
  return new;
end;
$fn$;

create or replace function app.sales_order_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  h public.sales_order;
  v_code text;
  v_item_name text;
  v_disabled boolean;
  v_sales boolean;
  v_stock boolean;
  v_grant boolean;
  v_stock_uom uuid;
  v_max numeric;
  v_factor numeric;
  v_whole boolean;
  v_max_text text;
  v_needs_wh boolean;
  v_q_item uuid;
  v_q_uom uuid;
  v_q_factor numeric;
  v_q_parent uuid;
  v_q_company uuid;
  v_q_name text;
begin
  if new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001',
      message = format('so_qty: Row %s: Quantity must be greater than zero', coalesce(new.idx, 0));
  end if;
  select * into h from public.sales_order where id = new.parent_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'so_item: Sales Order is required';
  end if;
  if h.docstatus <> 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;

  select i.item_code, i.item_name, i.disabled, i.is_sales_item, i.is_stock_item, i.grant_commission, i.stock_uom_id, i.max_discount
    into v_code, v_item_name, v_disabled, v_sales, v_stock, v_grant, v_stock_uom, v_max
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'so_item: Item is required';
  end if;
  if v_disabled then
    raise exception using errcode = 'P0001',
      message = format('so_item: Item %s is disabled', v_code);
  end if;
  if not coalesce(v_sales, false) then
    raise exception using errcode = 'P0001',
      message = format('so_item: Item %s is not a sales item', v_code);
  end if;
  if new.item_name is null or btrim(new.item_name) = '' then
    new.item_name := v_item_name;
  end if;
  new.is_stock_item := coalesce(v_stock, false);
  new.grant_commission := coalesce(v_grant, true);
  new.skip_delivery := false;
  new.delivered_by_supplier := coalesce(new.delivered_by_supplier, false);
  new.closed := coalesce(new.closed, false);
  new.billed_amt := coalesce(new.billed_amt, 0);
  new.delivered_qty := coalesce(new.delivered_qty, 0);
  new.returned_qty := coalesce(new.returned_qty, 0);
  new.picked_qty := coalesce(new.picked_qty, 0);
  new.work_order_qty := coalesce(new.work_order_qty, 0);

  if new.uom_id is null or new.uom_id = v_stock_uom then
    new.uom_id := v_stock_uom;
    new.conversion_factor := 1;
  else
    select u.conversion_factor into v_factor
      from public.item_uom u
     where u.parent_id = new.item_id and u.uom_id = new.uom_id;
    if v_factor is null then
      raise exception using errcode = 'P0001',
        message = format('so_uom: Row %s: UOM is not allowed for this item', coalesce(new.idx, 0));
    end if;
    new.conversion_factor := v_factor;
  end if;
  new.stock_uom_id := v_stock_uom;
  select u.must_be_whole_number into v_whole from public.uom u where u.id = new.uom_id;
  if coalesce(v_whole, false) and new.qty <> trunc(new.qty) then
    raise exception using errcode = 'P0001',
      message = format('so_uom: Row %s: Qty cannot be a fraction', coalesce(new.idx, 0));
  end if;

  new.discount_percentage := coalesce(new.discount_percentage, 0);
  if v_max is not null and new.discount_percentage > v_max then
    v_max_text := trim(trailing '.' from trim(trailing '0' from v_max::text));
    raise exception using errcode = 'P0001',
      message = format('so_discount: Maximum discount for Item %s is %s%%', v_code, v_max_text);
  end if;
  if new.rate is null then
    new.rate := coalesce(new.price_list_rate, 0) * (1 - new.discount_percentage / 100);
  end if;
  new.amount := app.round(new.qty * new.rate, 2);
  new.net_rate := new.rate;
  new.net_amount := new.amount;
  new.stock_qty := new.qty * new.conversion_factor;

  if new.warehouse_id is null and h.set_warehouse_id is not null then
    new.warehouse_id := h.set_warehouse_id;
  end if;
  if new.cost_center_id is null then
    select c.cost_center_id into new.cost_center_id
      from public.companies c
     where c.id = h.company_id and c.org_id = h.org_id;
  end if;

  if h.order_type = 'Sales' and not new.skip_delivery then
    if new.delivery_date is null then
      new.delivery_date := h.delivery_date;
    end if;
    if new.delivery_date is null and not exists (
      select 1
        from public.sales_order_item i
       where i.parent_id = new.parent_id
         and i.id is distinct from new.id
         and i.delivery_date is not null
         and not i.skip_delivery
    ) then
      raise exception using errcode = 'P0001', message = 'so_delivery_date: Please enter Delivery Date';
    end if;
    if new.delivery_date is not null and h.transaction_date > new.delivery_date then
      raise exception using errcode = 'P0001',
        message = 'so_delivery_date: Expected Delivery Date should be after Sales Order Date';
    end if;
    if h.po_date is not null and new.delivery_date is not null and h.po_date > new.delivery_date then
      raise exception using errcode = 'P0001',
        message = format(
          'so_delivery_date: Row %s: Expected Delivery Date cannot be before Purchase Order Date',
          coalesce(new.idx, 0)
        );
    end if;
  end if;

  v_needs_wh := new.is_stock_item or exists (
    select 1
      from public.product_bundle b
      join public.product_bundle_item bi on bi.parent_id = b.id
      join public.item si on si.id = bi.item_id and si.org_id = bi.org_id
     where b.org_id = new.org_id
       and b.new_item_id = new.item_id
       and b.docstatus = 1
       and not b.disabled
       and si.is_stock_item
  );
  if v_needs_wh and new.warehouse_id is null and not new.delivered_by_supplier then
    raise exception using errcode = 'P0001',
      message = format('so_warehouse: Source warehouse required for stock item %s', v_code);
  end if;

  if new.quotation_item_id is not null then
    select qi.item_id, qi.uom_id, qi.conversion_factor, qi.parent_id, q.company_id, q.name
      into v_q_item, v_q_uom, v_q_factor, v_q_parent, v_q_company, v_q_name
      from public.quotation_item qi
      join public.quotation q on q.id = qi.parent_id
     where qi.id = new.quotation_item_id and qi.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'so_quotation: Quotation item was not found';
    end if;
    if new.prevdoc_id is not null and new.prevdoc_id is distinct from v_q_parent then
      raise exception using errcode = 'P0001',
        message = 'so_quotation: Quotation item does not belong to the selected Quotation';
    end if;
    if v_q_company is distinct from h.company_id then
      raise exception using errcode = 'P0001',
        message = format('so_quotation: Quotation %s belongs to a different company', v_q_name);
    end if;
    if new.item_id is distinct from v_q_item then
      raise exception using errcode = 'P0001',
        message = format('so_quotation: Row %s: Item does not match Quotation %s', coalesce(new.idx, 0), v_q_name);
    end if;
    if new.uom_id is distinct from v_q_uom then
      raise exception using errcode = 'P0001',
        message = format('so_quotation: Row %s: UOM does not match Quotation %s', coalesce(new.idx, 0), v_q_name);
    end if;
    if new.conversion_factor is distinct from v_q_factor then
      raise exception using errcode = 'P0001',
        message = format(
          'so_quotation: Row %s: Conversion factor does not match Quotation %s',
          coalesce(new.idx, 0), v_q_name
        );
    end if;
  elsif new.prevdoc_id is not null then
    select q.company_id, q.name into v_q_company, v_q_name
      from public.quotation q
     where q.id = new.prevdoc_id and q.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'so_quotation: Quotation was not found';
    end if;
    if v_q_company is distinct from h.company_id then
      raise exception using errcode = 'P0001',
        message = format('so_quotation: Quotation %s belongs to a different company', v_q_name);
    end if;
  end if;

  return new;
end;
$fn$;

create or replace function app.sales_order_item_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_parent uuid := case when tg_op = 'DELETE' then old.parent_id else new.parent_id end;
begin
  update public.sales_order q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.sales_order_item i
       where i.parent_id = v_parent
    ) s
   where q.id = v_parent;
  return null;
end;
$fn$;

-- Limit is the customer row, else the group row when that row does not bypass, else the company.
-- Zero means no check. A customer row that bypasses skips the check.
create or replace function app.sales_order_check_credit(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.sales_order;
  v_limit numeric;
  v_bypass boolean;
  v_group uuid;
  v_gl numeric;
  v_open numeric;
  v_outstanding numeric;
  v_out_text text;
  v_limit_text text;
begin
  select * into h from public.sales_order where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Sales Order not found';
  end if;

  select l.credit_limit, l.bypass_credit_limit_check
    into v_limit, v_bypass
    from public.customer_credit_limit l
   where l.org_id = h.org_id and l.parent_id = h.customer_id and l.company_id = h.company_id;
  if found then
    if coalesce(v_bypass, false) then
      return;
    end if;
  else
    select c.customer_group_id into v_group
      from public.customer c
     where c.id = h.customer_id and c.org_id = h.org_id;
    select l.credit_limit, l.bypass_credit_limit_check
      into v_limit, v_bypass
      from public.customer_group_credit_limit l
     where l.org_id = h.org_id and l.parent_id = v_group and l.company_id = h.company_id;
    if not found or coalesce(v_bypass, false) then
      select c.credit_limit into v_limit
        from public.companies c
       where c.id = h.company_id and c.org_id = h.org_id;
    end if;
  end if;
  if coalesce(v_limit, 0) <= 0 then
    return;
  end if;

  select coalesce(sum(g.debit - g.credit), 0) into v_gl
    from public.gl_entry g
    join public.account a on a.id = g.account_id
   where g.org_id = h.org_id
     and g.party_id = h.customer_id
     and g.company_id = h.company_id
     and not g.is_cancelled
     and a.account_type = 'Receivable';
  select coalesce(sum(o.base_grand_total * (100 - coalesce(o.per_billed, 0)) / 100), 0) into v_open
    from public.sales_order o
   where o.org_id = h.org_id
     and o.customer_id = h.customer_id
     and o.company_id = h.company_id
     and o.docstatus = 1
     and o.id <> h.id;
  v_outstanding := v_gl + v_open + h.base_grand_total * (100 - coalesce(h.per_billed, 0)) / 100;
  if v_outstanding > v_limit then
    v_out_text := trim(trailing '.' from trim(trailing '0' from v_outstanding::text));
    v_limit_text := trim(trailing '.' from trim(trailing '0' from v_limit::text));
    raise exception using errcode = 'P0001',
      message = format(
        'so_credit_limit: Credit limit has been crossed for customer %s (%s/%s)',
        h.customer_name, v_out_text, v_limit_text
      );
  end if;
end;
$fn$;

-- In-progress status for a submitted order. Close and Hold are stored directly.
create or replace function app.sales_order_next_status(p_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  s public.sales_order;
begin
  select * into s from public.sales_order where id = p_id;
  if (s.per_delivered >= 100 or s.skip_delivery_note) and s.per_billed >= 100 then
    return 'Completed';
  elsif s.advance_payment_status = 'Requested' then
    return 'To Pay';
  elsif s.per_delivered < 100 and s.per_billed >= 100 and not s.skip_delivery_note then
    return 'To Deliver';
  elsif (s.per_delivered >= 100 or s.skip_delivery_note) and s.per_billed < 100 then
    return 'To Bill';
  else
    return 'To Deliver and Bill';
  end if;
end;
$fn$;

create or replace function app.on_submit__sales_order(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count int;
  v_company uuid;
  v_base numeric;
  v_status text;
begin
  select count(*) into v_count from public.sales_order_item i where i.parent_id = p_id;
  if v_count = 0 then
    raise exception using errcode = 'P0001', message = 'so_items: Items are required';
  end if;

  update public.sales_order q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.sales_order_item i
       where i.parent_id = p_id
    ) s
   where q.id = p_id
  returning q.company_id, q.base_grand_total into v_company, v_base;

  perform app.validate_approving_authority('Sales Order', v_company, v_base);
  perform app.sales_order_check_credit(p_id);
  v_status := app.sales_order_next_status(p_id);
  update public.sales_order
     set status = v_status,
         delivery_status = 'Not Delivered',
         billing_status = 'Not Billed',
         advance_payment_status = 'Not Requested'
   where id = p_id;
end;
$fn$;

create or replace function app.on_cancel__sales_order(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_status text;
begin
  select status into v_status from public.sales_order where id = p_id;
  if v_status = 'Closed' then
    raise exception using errcode = 'P0001',
      message = 'so_closed: Closed order cannot be cancelled. Unclose to cancel.';
  end if;
  update public.sales_order set status = 'Cancelled' where id = p_id;
end;
$fn$;

-- p_status Closed and On Hold stick. Draft re-opens or resumes and recomputes the status.
create or replace function app.update_sales_order_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.sales_order;
  v_status text;
begin
  select * into h from public.sales_order where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Sales Order not found';
  end if;
  if not app.has_perm(h.org_id, 'Sales Order', 'submit') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if h.docstatus <> 1 then
    raise exception using errcode = 'P0001',
      message = 'so_status: Only a submitted Sales Order can be closed or held';
  end if;
  if p_status is null or p_status not in ('Closed', 'On Hold', 'Draft') then
    raise exception using errcode = 'P0001',
      message = 'so_status: Status must be Closed, On Hold, or Draft';
  end if;

  if p_status = 'Draft' then
    if exists (select 1 from public.sales_order_item i where i.parent_id = h.id)
       and not exists (
         select 1 from public.sales_order_item i where i.parent_id = h.id and not i.closed
       ) then
      raise exception using errcode = 'P0001',
        message = format(
          'so_rows_closed: Every row of %s is closed. Reopen the rows you need instead.',
          h.name
        );
    end if;
    perform app.sales_order_check_credit(p_id);
    v_status := app.sales_order_next_status(p_id);
  elsif p_status = 'On Hold' then
    if h.status = 'Closed' then
      raise exception using errcode = 'P0001',
        message = 'so_status: A closed Sales Order must be re-opened before it can be held';
    end if;
    v_status := 'On Hold';
  else
    v_status := 'Closed';
  end if;

  update public.sales_order set status = v_status where id = p_id;
end;
$fn$;

revoke all on function app.sales_order_validate() from public, anon, authenticated;
revoke all on function app.sales_order_item_validate() from public, anon, authenticated;
revoke all on function app.sales_order_item_sync() from public, anon, authenticated;
revoke all on function app.sales_order_check_credit(uuid) from public, anon, authenticated;
revoke all on function app.sales_order_next_status(uuid) from public, anon, authenticated;
revoke all on function app.on_submit__sales_order(uuid) from public, anon, authenticated;
revoke all on function app.on_cancel__sales_order(uuid) from public, anon, authenticated;
revoke all on function app.update_sales_order_status(uuid, text) from public, anon;
grant execute on function app.update_sales_order_status(uuid, text) to authenticated;

create or replace function public.update_sales_order_status(p_id uuid, p_status text)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.update_sales_order_status(p_id, p_status);
$$;

revoke all on function public.update_sales_order_status(uuid, text) from public, anon;
grant execute on function public.update_sales_order_status(uuid, text) to authenticated;

drop trigger if exists sales_order_validate on public.sales_order;
create trigger sales_order_validate before insert or update on public.sales_order
  for each row execute function app.sales_order_validate();
drop trigger if exists touch_updated on public.sales_order;
create trigger touch_updated before update on public.sales_order
  for each row execute function app.touch_updated();
drop trigger if exists sales_order_item_validate on public.sales_order_item;
create trigger sales_order_item_validate before insert or update on public.sales_order_item
  for each row execute function app.sales_order_item_validate();
drop trigger if exists sales_order_item_sync on public.sales_order_item;
create trigger sales_order_item_sync after insert or update or delete on public.sales_order_item
  for each row execute function app.sales_order_item_sync();

alter table public.sales_order enable row level security;
alter table public.sales_order force row level security;
alter table public.sales_order_item enable row level security;
alter table public.sales_order_item force row level security;

drop policy if exists sales_order_select on public.sales_order;
create policy sales_order_select on public.sales_order for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Order', 'read'))::uuid[]));
drop policy if exists sales_order_insert on public.sales_order;
create policy sales_order_insert on public.sales_order for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Sales Order', 'create'))::uuid[]));
drop policy if exists sales_order_update on public.sales_order;
create policy sales_order_update on public.sales_order for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]));
drop policy if exists sales_order_delete on public.sales_order;
create policy sales_order_delete on public.sales_order for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Order', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists sales_order_item_select on public.sales_order_item;
create policy sales_order_item_select on public.sales_order_item for select to authenticated
  using (exists (select 1 from public.sales_order p where p.id = parent_id));
drop policy if exists sales_order_item_insert on public.sales_order_item;
create policy sales_order_item_insert on public.sales_order_item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Sales Order', 'create'))::uuid[]));
drop policy if exists sales_order_item_update on public.sales_order_item;
create policy sales_order_item_update on public.sales_order_item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]));
drop policy if exists sales_order_item_delete on public.sales_order_item;
create policy sales_order_item_delete on public.sales_order_item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default, allow_on_submit
) values (
  'Sales Order', 'sales_order', 'selling', true, 'customer_name', 'SAL-ORD-.YYYY.-', array['po_no', 'po_date']
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default,
      allow_on_submit = excluded.allow_on_submit;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Sales Order Item', 'sales_order_item', 'selling', true, 'Sales Order', 'items')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Sales Order', true, false, false, false, false, false, false),
  ('Sales User', 'Sales Order', true, true, true, true, true, true, true),
  ('Sales Manager', 'Sales Order', true, true, true, true, true, true, true),
  ('Accounts User', 'Sales Order', true, false, false, false, false, false, false),
  ('Stock User', 'Sales Order', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
