-- 0503 stock: Delivery Note, items, and packing list (docs/modules/02-selling.md §2.12, §2.13, §5.3).
-- ERPNext: erpnext/stock/doctype/delivery_note/delivery_note.py (validate, on_submit, on_cancel, update_status)
-- ERPNext: erpnext/stock/doctype/packed_item/packed_item.py (make_packing_list)
-- ERPNext: erpnext/selling/doctype/customer/customer.py (check_credit_limit)
-- Header totals are the sum of item amounts. Stock ledger, perpetual GL, and
-- app.update_prevdoc_status stay on their own checklist lines. app.map_doc,
-- including Make Return, stays closed. selling_settings is not built, so
-- so_required stays off, duplicate items are allowed, and zero qty is rejected.

create table if not exists public.delivery_note (
  id                       uuid primary key default gen_random_uuid(),
  org_id                   uuid not null references public.organizations (id) on delete cascade,
  name                     text not null,
  customer_name            text,
  naming_series            text not null default 'MAT-DN-.YYYY.-',
  customer_id              uuid not null,
  company_id               uuid not null,
  posting_date             date not null default current_date,
  posting_time             time not null default localtime,
  set_posting_time         boolean not null default false,
  is_return                boolean not null default false,
  return_against           uuid,
  tax_id                   text,
  set_warehouse_id         uuid,
  set_target_warehouse_id  uuid,
  transporter_id           uuid,
  lr_no                    text,
  lr_date                  date,
  vehicle_no               text,
  instructions             text,
  print_without_amount     boolean not null default false,
  currency                 text not null,
  conversion_rate          numeric(21,9) not null default 1,
  selling_price_list_id    uuid not null,
  status                   text not null default 'Draft'
    check (status in (
      'Draft', 'Cancelled', 'Closed', 'Return', 'Return Issued',
      'Completed', 'Partially Billed', 'To Bill'
    )),
  per_billed               numeric(21,9) not null default 0,
  per_returned             numeric(21,9) not null default 0,
  per_installed            numeric(21,9) not null default 0,
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
  foreign key (org_id, set_target_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, transporter_id) references public.supplier (org_id, id),
  foreign key (org_id, return_against) references public.delivery_note (org_id, id),
  foreign key (org_id, amended_from) references public.delivery_note (org_id, id) on delete set null (amended_from)
);

create index if not exists delivery_note_customer_idx on public.delivery_note (org_id, customer_id);
create index if not exists delivery_note_company_idx on public.delivery_note (org_id, company_id);
create index if not exists delivery_note_price_list_idx on public.delivery_note (org_id, selling_price_list_id);
create index if not exists delivery_note_warehouse_idx on public.delivery_note (org_id, set_warehouse_id);
create index if not exists delivery_note_target_wh_idx on public.delivery_note (org_id, set_target_warehouse_id);
create index if not exists delivery_note_transporter_idx on public.delivery_note (org_id, transporter_id);
create index if not exists delivery_note_return_idx on public.delivery_note (org_id, return_against);
create index if not exists delivery_note_amended_idx on public.delivery_note (org_id, amended_from);
create index if not exists delivery_note_posting_idx
  on public.delivery_note (org_id, company_id, docstatus, posting_date);

create table if not exists public.delivery_note_item (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null,
  parent_id               uuid not null,
  idx                     int not null,
  item_id                 uuid not null,
  item_name               text,
  qty                     numeric(21,9) not null,
  uom_id                  uuid,
  stock_uom_id            uuid,
  conversion_factor       numeric(21,9) not null default 1,
  stock_qty               numeric(21,9) not null default 0,
  price_list_rate         numeric(21,9),
  discount_percentage     numeric(21,9) not null default 0,
  rate                    numeric(21,9),
  amount                  numeric(21,9) not null default 0,
  net_rate                numeric(21,9) not null default 0,
  net_amount              numeric(21,9) not null default 0,
  warehouse_id            uuid,
  target_warehouse_id     uuid,
  expense_account_id      uuid,
  cost_center_id          uuid,
  against_sales_order_id  uuid,
  so_detail_id            uuid,
  dn_detail_id            uuid,
  billed_amt              numeric(21,9) not null default 0,
  returned_qty            numeric(21,9) not null default 0,
  received_qty            numeric(21,9) not null default 0,
  incoming_rate           numeric(21,9) not null default 0,
  closed                  boolean not null default false,
  is_stock_item           boolean not null default true,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.delivery_note (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, uom_id) references public.uom (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, target_warehouse_id) references public.warehouse (org_id, id),
  foreign key (org_id, expense_account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  foreign key (org_id, against_sales_order_id) references public.sales_order (org_id, id),
  foreign key (org_id, so_detail_id) references public.sales_order_item (org_id, id),
  foreign key (org_id, dn_detail_id) references public.delivery_note_item (org_id, id)
);

create index if not exists delivery_note_item_parent_idx on public.delivery_note_item (org_id, parent_id);
create index if not exists delivery_note_item_item_idx on public.delivery_note_item (org_id, item_id);
create index if not exists delivery_note_item_uom_idx on public.delivery_note_item (org_id, uom_id);
create index if not exists delivery_note_item_stock_uom_idx on public.delivery_note_item (org_id, stock_uom_id);
create index if not exists delivery_note_item_wh_idx on public.delivery_note_item (org_id, warehouse_id);
create index if not exists delivery_note_item_target_wh_idx on public.delivery_note_item (org_id, target_warehouse_id);
create index if not exists delivery_note_item_expense_idx on public.delivery_note_item (org_id, expense_account_id);
create index if not exists delivery_note_item_cc_idx on public.delivery_note_item (org_id, cost_center_id);
create index if not exists delivery_note_item_so_idx on public.delivery_note_item (org_id, against_sales_order_id);
create index if not exists delivery_note_item_so_detail_idx on public.delivery_note_item (org_id, so_detail_id);
create index if not exists delivery_note_item_dn_detail_idx on public.delivery_note_item (org_id, dn_detail_id);

-- One table for Quotation, Sales Order, and Delivery Note. The form child is the delivery note.
create table if not exists public.packed_item (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null,
  parent_doctype    text not null default 'Delivery Note'
    check (parent_doctype in ('Quotation', 'Sales Order', 'Delivery Note')),
  parent_id         uuid not null,
  parent_detail_id  uuid,
  parent_item_id    uuid,
  idx               int not null,
  item_id           uuid not null,
  product_bundle_id uuid,
  item_name         text,
  description       text,
  qty               numeric(21,9) not null default 0,
  uom_id            uuid,
  warehouse_id      uuid,
  rate              numeric(21,9) not null default 0,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, parent_item_id) references public.item (org_id, id),
  foreign key (org_id, product_bundle_id) references public.product_bundle (org_id, id),
  foreign key (org_id, uom_id) references public.uom (org_id, id),
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id)
);

create index if not exists packed_item_parent_idx on public.packed_item (org_id, parent_doctype, parent_id);
create index if not exists packed_item_detail_idx on public.packed_item (parent_detail_id);
create index if not exists packed_item_item_idx on public.packed_item (org_id, item_id);
create index if not exists packed_item_parent_item_idx on public.packed_item (org_id, parent_item_id);
create index if not exists packed_item_bundle_idx on public.packed_item (org_id, product_bundle_id);
create index if not exists packed_item_uom_idx on public.packed_item (org_id, uom_id);
create index if not exists packed_item_wh_idx on public.packed_item (org_id, warehouse_id);

create or replace function app.delivery_note_validate()
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
  v_fy uuid;
  v_src_status int;
  v_src_company uuid;
  v_src_customer uuid;
  v_src_return boolean;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
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
  new.is_return := coalesce(new.is_return, false);
  new.set_posting_time := coalesce(new.set_posting_time, false);
  new.print_without_amount := coalesce(new.print_without_amount, false);
  if new.posting_date is null then
    new.posting_date := current_date;
  end if;
  if new.posting_time is null or (tg_op = 'INSERT' and not new.set_posting_time) then
    new.posting_time := localtime;
  end if;
  if new.docstatus = 0 then
    if new.is_return then
      new.naming_series := 'MAT-DN-RET-.YYYY.-';
    else
      new.naming_series := 'MAT-DN-.YYYY.-';
    end if;
  elsif new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'MAT-DN-.YYYY.-';
  end if;

  if tg_op = 'INSERT' or new.docstatus = 0 then
    if new.customer_id is null then
      raise exception using errcode = 'P0001', message = 'dn_customer: Customer is required';
    end if;
    select c.customer_name, c.name, c.disabled, c.is_frozen, c.default_currency, c.tax_id
      into v_customer_name, v_customer_doc, v_disabled, v_frozen, v_party_currency, v_tax_id
      from public.customer c
     where c.id = new.customer_id and c.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'dn_customer: Customer is required';
    end if;
    if v_disabled then
      raise exception using errcode = 'P0001',
        message = format('dn_customer: Customer %s is disabled', v_customer_doc);
    end if;
    if v_frozen then
      raise exception using errcode = 'P0001',
        message = format('dn_customer: Customer %s is frozen', v_customer_doc);
    end if;
    new.customer_name := v_customer_name;
    new.tax_id := v_tax_id;

    if new.company_id is null then
      raise exception using errcode = 'P0001', message = 'dn_company: Company is required';
    end if;
    select c.default_currency into v_company_currency
      from public.companies c
     where c.id = new.company_id and c.org_id = new.org_id;
    if v_company_currency is null then
      raise exception using errcode = 'P0001', message = 'dn_company: Company is required';
    end if;
    if new.currency is null or btrim(new.currency) = '' then
      new.currency := coalesce(nullif(btrim(v_party_currency), ''), v_company_currency);
    end if;
    if new.currency = v_company_currency then
      new.conversion_rate := 1;
    elsif new.conversion_rate is null or new.conversion_rate = 0 then
      raise exception using errcode = 'P0001', message = 'dn_rate: Exchange Rate is required';
    end if;

    if new.selling_price_list_id is null then
      raise exception using errcode = 'P0001', message = 'dn_price_list: Selling Price List is required';
    end if;
    select p.price_list_name, p.enabled, p.selling
      into v_list_name, v_enabled, v_selling
      from public.price_list p
     where p.id = new.selling_price_list_id and p.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'dn_price_list: Selling Price List is required';
    end if;
    if not v_enabled or not v_selling then
      raise exception using errcode = 'P0001',
        message = format('dn_price_list: Price List %s is not a selling price list', v_list_name);
    end if;

    select fy.id into v_fy
      from public.fiscal_year fy
     where fy.org_id = new.org_id and not fy.disabled
       and new.posting_date between fy.year_start_date and fy.year_end_date
       and (
         not exists (select 1 from public.fiscal_year_company c where c.parent_id = fy.id)
         or exists (
           select 1 from public.fiscal_year_company c
            where c.parent_id = fy.id and c.company_id = new.company_id
         )
       )
     order by fy.year_start_date
     limit 1;
    if v_fy is null then
      raise exception using errcode = 'P0001',
        message = format('fiscal_year: Date %s is not in any active Fiscal Year', new.posting_date);
    end if;

    if new.is_return and new.return_against is not null then
      if new.return_against = new.id then
        raise exception using errcode = 'P0001',
          message = 'dn_return: A Delivery Note cannot be returned against itself';
      end if;
      select d.docstatus, d.company_id, d.customer_id, d.is_return
        into v_src_status, v_src_company, v_src_customer, v_src_return
        from public.delivery_note d
       where d.id = new.return_against and d.org_id = new.org_id;
      if not found or v_src_status <> 1 then
        raise exception using errcode = 'P0001',
          message = 'dn_return: Return must be against a submitted Delivery Note';
      end if;
      if v_src_return then
        raise exception using errcode = 'P0001',
          message = 'dn_return: Return must be against a Delivery Note that is not itself a return';
      end if;
      if v_src_company is distinct from new.company_id then
        raise exception using errcode = 'P0001',
          message = 'dn_return: Return belongs to a different company';
      end if;
      if v_src_customer is distinct from new.customer_id then
        raise exception using errcode = 'P0001',
          message = 'dn_return: Return belongs to a different customer';
      end if;
    end if;
  end if;

  if new.status is null or btrim(new.status) = '' then
    new.status := 'Draft';
  end if;
  if new.docstatus = 2 then
    new.status := 'Cancelled';
  elsif new.docstatus = 0 then
    new.per_billed := 0;
    new.per_returned := 0;
    new.per_installed := 0;
    if current_user = 'authenticated' then
      new.status := 'Draft';
    end if;
  end if;
  new.total := coalesce(new.total, 0);
  new.net_total := coalesce(new.net_total, 0);
  new.grand_total := coalesce(new.grand_total, 0);
  new.conversion_rate := coalesce(new.conversion_rate, 1);
  new.base_grand_total := new.grand_total * new.conversion_rate;
  return new;
end;
$fn$;

create or replace function app.delivery_note_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  h public.delivery_note;
  v_code text;
  v_item_name text;
  v_disabled boolean;
  v_sales boolean;
  v_stock boolean;
  v_stock_uom uuid;
  v_max numeric;
  v_factor numeric;
  v_whole boolean;
  v_max_text text;
  v_needs_wh boolean;
  v_group boolean;
  v_account_company uuid;
  v_so_name text;
  v_so_status text;
  v_so_docstatus int;
  v_so_company uuid;
  v_so_customer uuid;
  v_so_currency text;
  v_so_item uuid;
  v_so_uom uuid;
  v_so_factor numeric;
  v_so_parent uuid;
  v_src_qty numeric;
  v_src_parent uuid;
  v_already numeric;
begin
  select * into h from public.delivery_note where id = new.parent_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'dn_item: Delivery Note is required';
  end if;
  if h.docstatus <> 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  if h.is_return then
    if new.qty is null or new.qty >= 0 then
      raise exception using errcode = 'P0001',
        message = format('dn_qty: Row %s: Quantity must be less than zero', coalesce(new.idx, 0));
    end if;
  elsif new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001',
      message = format('dn_qty: Row %s: Quantity must be greater than zero', coalesce(new.idx, 0));
  end if;

  select i.item_code, i.item_name, i.disabled, i.is_sales_item, i.is_stock_item, i.stock_uom_id, i.max_discount
    into v_code, v_item_name, v_disabled, v_sales, v_stock, v_stock_uom, v_max
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'dn_item: Item is required';
  end if;
  if v_disabled then
    raise exception using errcode = 'P0001',
      message = format('dn_item: Item %s is disabled', v_code);
  end if;
  if not coalesce(v_sales, false) then
    raise exception using errcode = 'P0001',
      message = format('dn_item: Item %s is not a sales item', v_code);
  end if;
  if new.item_name is null or btrim(new.item_name) = '' then
    new.item_name := v_item_name;
  end if;
  new.is_stock_item := coalesce(v_stock, false);
  new.closed := coalesce(new.closed, false);
  if h.docstatus = 0 then
    new.billed_amt := 0;
    new.returned_qty := 0;
    new.received_qty := 0;
    new.incoming_rate := 0;
  end if;

  if new.uom_id is null or new.uom_id = v_stock_uom then
    new.uom_id := v_stock_uom;
    new.conversion_factor := 1;
  else
    select u.conversion_factor into v_factor
      from public.item_uom u
     where u.parent_id = new.item_id and u.uom_id = new.uom_id;
    if v_factor is null then
      raise exception using errcode = 'P0001',
        message = format('dn_uom: Row %s: UOM is not allowed for this item', coalesce(new.idx, 0));
    end if;
    new.conversion_factor := v_factor;
  end if;
  new.stock_uom_id := v_stock_uom;
  select u.must_be_whole_number into v_whole from public.uom u where u.id = new.uom_id;
  if coalesce(v_whole, false) and new.qty <> trunc(new.qty) then
    raise exception using errcode = 'P0001',
      message = format('dn_uom: Row %s: Qty cannot be a fraction', coalesce(new.idx, 0));
  end if;

  new.discount_percentage := coalesce(new.discount_percentage, 0);
  if v_max is not null and new.discount_percentage > v_max then
    v_max_text := trim(trailing '.' from trim(trailing '0' from v_max::text));
    raise exception using errcode = 'P0001',
      message = format('dn_discount: Maximum discount for Item %s is %s%%', v_code, v_max_text);
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
  if new.target_warehouse_id is null and h.set_target_warehouse_id is not null then
    new.target_warehouse_id := h.set_target_warehouse_id;
  end if;
  if new.cost_center_id is null or new.expense_account_id is null then
    select coalesce(new.cost_center_id, c.cost_center_id),
           coalesce(new.expense_account_id, c.default_expense_account_id)
      into new.cost_center_id, new.expense_account_id
      from public.companies c
     where c.id = h.company_id and c.org_id = h.org_id;
  end if;

  v_needs_wh := new.is_stock_item or exists (
    select 1
      from public.product_bundle b
      join public.product_bundle_item bi on bi.parent_id = b.id
      join public.item si on si.id = bi.item_id and si.org_id = bi.org_id
     where b.org_id = new.org_id
       and b.new_item_id = new.item_id
       and b.docstatus = 1
       and b.is_active
       and not b.disabled
       and si.is_stock_item
  );
  if v_needs_wh and new.warehouse_id is null then
    raise exception using errcode = 'P0001',
      message = format('dn_warehouse: Source warehouse required for stock item %s', v_code);
  end if;
  if new.expense_account_id is not null then
    select a.is_group, a.company_id into v_group, v_account_company
      from public.account a
     where a.id = new.expense_account_id and a.org_id = new.org_id;
    if not found or v_account_company is distinct from h.company_id or coalesce(v_group, false) then
      raise exception using errcode = 'P0001',
        message = 'dn_expense: Expense account must be a ledger of the company';
    end if;
  elsif v_needs_wh then
    raise exception using errcode = 'P0001',
      message = format('dn_expense: Expense account is required for stock item %s', v_code);
  end if;

  if new.so_detail_id is not null then
    select i.item_id, i.uom_id, i.conversion_factor, i.parent_id
      into v_so_item, v_so_uom, v_so_factor, v_so_parent
      from public.sales_order_item i
     where i.id = new.so_detail_id and i.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'dn_so: Sales Order item was not found';
    end if;
    if new.against_sales_order_id is null then
      new.against_sales_order_id := v_so_parent;
    elsif new.against_sales_order_id is distinct from v_so_parent then
      raise exception using errcode = 'P0001',
        message = 'dn_so: Sales Order item does not belong to the selected Sales Order';
    end if;
    if new.item_id is distinct from v_so_item then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Row %s: Item does not match the Sales Order', coalesce(new.idx, 0));
    end if;
    if new.uom_id is distinct from v_so_uom then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Row %s: UOM does not match the Sales Order', coalesce(new.idx, 0));
    end if;
    if new.conversion_factor is distinct from v_so_factor then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Row %s: Conversion factor does not match the Sales Order', coalesce(new.idx, 0));
    end if;
  end if;

  if new.against_sales_order_id is not null then
    select o.name, o.status, o.docstatus, o.company_id, o.customer_id, o.currency
      into v_so_name, v_so_status, v_so_docstatus, v_so_company, v_so_customer, v_so_currency
      from public.sales_order o
     where o.id = new.against_sales_order_id and o.org_id = new.org_id;
    if not found or v_so_docstatus <> 1 then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s is not submitted', coalesce(v_so_name, ''));
    end if;
    if v_so_status = 'On Hold' then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s is on hold', v_so_name);
    end if;
    if v_so_status = 'Closed' then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s is closed', v_so_name);
    end if;
    if v_so_company is distinct from h.company_id then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s belongs to a different company', v_so_name);
    end if;
    if v_so_customer is distinct from h.customer_id then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s belongs to a different customer', v_so_name);
    end if;
    if v_so_currency is distinct from h.currency then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s uses a different currency', v_so_name);
    end if;
  end if;

  if h.is_return and h.return_against is not null and new.dn_detail_id is null then
    raise exception using errcode = 'P0001',
      message = format('dn_return: Row %s must cite the source row', coalesce(new.idx, 0));
  end if;
  if h.is_return and new.dn_detail_id is not null then
    select i.qty, i.parent_id into v_src_qty, v_src_parent
      from public.delivery_note_item i
     where i.id = new.dn_detail_id and i.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'dn_return: Source row was not found';
    end if;
    if h.return_against is not null and v_src_parent is distinct from h.return_against then
      raise exception using errcode = 'P0001',
        message = 'dn_return: Return row does not belong to the source Delivery Note';
    end if;
    select coalesce(sum(abs(i.qty)), 0) into v_already
      from public.delivery_note_item i
      join public.delivery_note d on d.id = i.parent_id
     where i.dn_detail_id = new.dn_detail_id
       and i.id is distinct from new.id
       and d.is_return
       and d.docstatus < 2
       and (d.id = new.parent_id or d.docstatus = 1);
    if abs(new.qty) + v_already > abs(v_src_qty) then
      raise exception using errcode = 'P0001',
        message = 'dn_return: Returned quantity cannot be more than the delivered quantity';
    end if;
  end if;

  return new;
end;
$fn$;

create or replace function app.delivery_note_item_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_parent uuid := case when tg_op = 'DELETE' then old.parent_id else new.parent_id end;
begin
  update public.delivery_note q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.delivery_note_item i
       where i.parent_id = v_parent
    ) s
   where q.id = v_parent;
  return null;
end;
$fn$;

-- Rebuild packed rows from the active product bundle. Qty is component qty times parent stock qty.
-- A warehouse the user already set for the same parent row and component is kept.
create or replace function app.make_packing_list(p_doctype text, p_parent uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_org uuid;
  v_kept jsonb;
  v_item record;
  v_comp record;
  v_bundle uuid;
  v_idx int := 0;
  v_wh uuid;
  v_code text;
begin
  if p_doctype = 'Quotation' then
    select q.org_id into v_org from public.quotation q where q.id = p_parent;
  elsif p_doctype = 'Sales Order' then
    select o.org_id into v_org from public.sales_order o where o.id = p_parent;
  elsif p_doctype = 'Delivery Note' then
    select d.org_id into v_org from public.delivery_note d where d.id = p_parent;
  else
    return;
  end if;
  if v_org is null then
    return;
  end if;

  select coalesce(jsonb_object_agg(s.key, s.warehouse_id), '{}'::jsonb) into v_kept
    from (
      select distinct on (p.parent_detail_id, p.item_id)
             p.parent_detail_id::text || ':' || p.item_id::text as key,
             p.warehouse_id
        from public.packed_item p
       where p.parent_doctype = p_doctype
         and p.parent_id = p_parent
         and p.warehouse_id is not null
       order by p.parent_detail_id, p.item_id, p.idx
    ) s;

  delete from public.packed_item p
   where p.parent_doctype = p_doctype and p.parent_id = p_parent;

  if p_doctype = 'Quotation' then
    for v_item in
      select i.id, i.item_id, i.stock_qty, i.warehouse_id
        from public.quotation_item i
       where i.parent_id = p_parent and not i.is_alternative
       order by i.idx
    loop
      v_bundle := null;
      select b.id into v_bundle
        from public.product_bundle b
       where b.org_id = v_org
         and b.new_item_id = v_item.item_id
         and b.docstatus = 1
         and b.is_active
         and not b.disabled
       limit 1;
      if v_bundle is null then
        continue;
      end if;
      for v_comp in
        select bi.item_id, bi.qty, bi.uom_id, bi.description, si.item_name, si.item_code, si.is_stock_item
          from public.product_bundle_item bi
          join public.item si on si.id = bi.item_id and si.org_id = bi.org_id
         where bi.parent_id = v_bundle
         order by bi.idx
      loop
        v_idx := v_idx + 1;
        v_wh := nullif(v_kept ->> (v_item.id::text || ':' || v_comp.item_id::text), '')::uuid;
        if v_wh is null then
          v_wh := v_item.warehouse_id;
        end if;
        insert into public.packed_item (
          org_id, parent_doctype, parent_id, parent_detail_id, parent_item_id, idx,
          item_id, product_bundle_id, item_name, description, qty, uom_id, warehouse_id, rate
        ) values (
          v_org, p_doctype, p_parent, v_item.id, v_item.item_id, v_idx,
          v_comp.item_id, v_bundle, v_comp.item_name, v_comp.description,
          v_comp.qty * v_item.stock_qty, v_comp.uom_id, v_wh, 0
        );
      end loop;
    end loop;
  elsif p_doctype = 'Sales Order' then
    for v_item in
      select i.id, i.item_id, i.stock_qty, i.warehouse_id
        from public.sales_order_item i
       where i.parent_id = p_parent
       order by i.idx
    loop
      v_bundle := null;
      select b.id into v_bundle
        from public.product_bundle b
       where b.org_id = v_org
         and b.new_item_id = v_item.item_id
         and b.docstatus = 1
         and b.is_active
         and not b.disabled
       limit 1;
      if v_bundle is null then
        continue;
      end if;
      for v_comp in
        select bi.item_id, bi.qty, bi.uom_id, bi.description, si.item_name, si.item_code, si.is_stock_item
          from public.product_bundle_item bi
          join public.item si on si.id = bi.item_id and si.org_id = bi.org_id
         where bi.parent_id = v_bundle
         order by bi.idx
      loop
        v_idx := v_idx + 1;
        v_wh := nullif(v_kept ->> (v_item.id::text || ':' || v_comp.item_id::text), '')::uuid;
        if v_wh is null then
          v_wh := v_item.warehouse_id;
        end if;
        insert into public.packed_item (
          org_id, parent_doctype, parent_id, parent_detail_id, parent_item_id, idx,
          item_id, product_bundle_id, item_name, description, qty, uom_id, warehouse_id, rate
        ) values (
          v_org, p_doctype, p_parent, v_item.id, v_item.item_id, v_idx,
          v_comp.item_id, v_bundle, v_comp.item_name, v_comp.description,
          v_comp.qty * v_item.stock_qty, v_comp.uom_id, v_wh, 0
        );
      end loop;
    end loop;
  else
    for v_item in
      select i.id, i.item_id, i.stock_qty, i.warehouse_id
        from public.delivery_note_item i
       where i.parent_id = p_parent
       order by i.idx
    loop
      v_bundle := null;
      select b.id into v_bundle
        from public.product_bundle b
       where b.org_id = v_org
         and b.new_item_id = v_item.item_id
         and b.docstatus = 1
         and b.is_active
         and not b.disabled
       limit 1;
      if v_bundle is null then
        continue;
      end if;
      for v_comp in
        select bi.item_id, bi.qty, bi.uom_id, bi.description, si.item_name, si.item_code, si.is_stock_item
          from public.product_bundle_item bi
          join public.item si on si.id = bi.item_id and si.org_id = bi.org_id
         where bi.parent_id = v_bundle
         order by bi.idx
      loop
        v_idx := v_idx + 1;
        v_wh := nullif(v_kept ->> (v_item.id::text || ':' || v_comp.item_id::text), '')::uuid;
        if v_wh is null then
          v_wh := v_item.warehouse_id;
        end if;
        if v_wh is null and coalesce(v_comp.is_stock_item, false) then
          v_code := v_comp.item_code;
          raise exception using errcode = 'P0001',
            message = format('dn_warehouse: Source warehouse required for stock item %s', v_code);
        end if;
        insert into public.packed_item (
          org_id, parent_doctype, parent_id, parent_detail_id, parent_item_id, idx,
          item_id, product_bundle_id, item_name, description, qty, uom_id, warehouse_id, rate
        ) values (
          v_org, p_doctype, p_parent, v_item.id, v_item.item_id, v_idx,
          v_comp.item_id, v_bundle, v_comp.item_name, v_comp.description,
          v_comp.qty * v_item.stock_qty, v_comp.uom_id, v_wh, 0
        );
      end loop;
    end loop;
  end if;
end;
$fn$;

create or replace function app.pack_parent_items()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_doctype text;
  v_parent uuid;
begin
  v_parent := case when tg_op = 'DELETE' then old.parent_id else new.parent_id end;
  v_doctype := case tg_table_name
    when 'quotation_item' then 'Quotation'
    when 'sales_order_item' then 'Sales Order'
    when 'delivery_note_item' then 'Delivery Note'
    else null
  end;
  if v_doctype is not null then
    perform app.make_packing_list(v_doctype, v_parent);
  end if;
  return null;
end;
$fn$;

create or replace function app.packed_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  if new.parent_doctype is null or btrim(new.parent_doctype) = '' then
    new.parent_doctype := 'Delivery Note';
  end if;
  new.qty := coalesce(new.qty, 0);
  new.rate := coalesce(new.rate, 0);
  return new;
end;
$fn$;

-- Limit is the customer row, else the group row when that row does not bypass, else the company.
-- Zero means no check. A customer row that bypasses skips the check.
create or replace function app.delivery_note_check_credit(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.delivery_note;
  v_limit numeric;
  v_bypass boolean;
  v_group uuid;
  v_gl numeric;
  v_open numeric;
  v_outstanding numeric;
  v_out_text text;
  v_limit_text text;
begin
  select * into h from public.delivery_note where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Delivery Note not found';
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
     and o.docstatus = 1;
  v_outstanding := v_gl + v_open + h.base_grand_total;
  if v_outstanding > v_limit then
    v_out_text := trim(trailing '.' from trim(trailing '0' from v_outstanding::text));
    v_limit_text := trim(trailing '.' from trim(trailing '0' from v_limit::text));
    raise exception using errcode = 'P0001',
      message = format(
        'dn_credit_limit: Credit limit has been crossed for customer %s (%s/%s)',
        h.customer_name, v_out_text, v_limit_text
      );
  end if;
end;
$fn$;

create or replace function app.delivery_note_next_status(p_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  s public.delivery_note;
begin
  select * into s from public.delivery_note where id = p_id;
  if s.is_return and s.per_billed = 0 then
    return 'Return';
  elsif s.per_returned >= 100 then
    return 'Return Issued';
  elsif s.per_billed >= 100 then
    return 'Completed';
  elsif s.per_billed > 0 then
    return 'Partially Billed';
  else
    return 'To Bill';
  end if;
end;
$fn$;

create or replace function app.on_submit__delivery_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count int;
  v_status text;
begin
  select count(*) into v_count from public.delivery_note_item i where i.parent_id = p_id;
  if v_count = 0 then
    raise exception using errcode = 'P0001', message = 'dn_items: Items are required';
  end if;
  if exists (
    select 1
      from public.delivery_note_item i
      join public.delivery_note d on d.id = i.parent_id
     where i.parent_id = p_id
       and ((d.is_return and i.qty >= 0) or (not d.is_return and i.qty <= 0))
  ) then
    raise exception using errcode = 'P0001', message = 'dn_qty: Quantity has the wrong sign for this Delivery Note';
  end if;

  update public.delivery_note q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.delivery_note_item i
       where i.parent_id = p_id
    ) s
   where q.id = p_id;

  perform app.make_packing_list('Delivery Note', p_id);
  perform app.delivery_note_check_credit(p_id);
  v_status := app.delivery_note_next_status(p_id);
  update public.delivery_note set status = v_status where id = p_id;
end;
$fn$;

create or replace function app.on_cancel__delivery_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_status text;
begin
  select status into v_status from public.delivery_note where id = p_id;
  if v_status = 'Closed' then
    raise exception using errcode = 'P0001',
      message = 'dn_closed: Closed delivery note cannot be cancelled. Re-open to cancel.';
  end if;
  update public.delivery_note set status = 'Cancelled' where id = p_id;
end;
$fn$;

-- Closed sticks. Draft re-opens, re-checks credit, and recomputes the status.
create or replace function app.update_delivery_note_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.delivery_note;
  v_status text;
begin
  select * into h from public.delivery_note where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Delivery Note not found';
  end if;
  if not app.has_perm(h.org_id, 'Delivery Note', 'submit') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if h.docstatus <> 1 then
    raise exception using errcode = 'P0001',
      message = 'dn_status: Only a submitted Delivery Note can be closed or reopened';
  end if;
  if p_status is null or p_status not in ('Closed', 'Draft') then
    raise exception using errcode = 'P0001',
      message = 'dn_status: Status must be Closed or Draft';
  end if;

  if p_status = 'Draft' then
    perform app.delivery_note_check_credit(p_id);
    v_status := app.delivery_note_next_status(p_id);
  else
    v_status := 'Closed';
  end if;

  update public.delivery_note set status = v_status where id = p_id;
end;
$fn$;

revoke all on function app.delivery_note_validate() from public, anon, authenticated;
revoke all on function app.delivery_note_item_validate() from public, anon, authenticated;
revoke all on function app.delivery_note_item_sync() from public, anon, authenticated;
revoke all on function app.make_packing_list(text, uuid) from public, anon, authenticated;
revoke all on function app.pack_parent_items() from public, anon, authenticated;
revoke all on function app.packed_item_validate() from public, anon, authenticated;
revoke all on function app.delivery_note_check_credit(uuid) from public, anon, authenticated;
revoke all on function app.delivery_note_next_status(uuid) from public, anon, authenticated;
revoke all on function app.on_submit__delivery_note(uuid) from public, anon, authenticated;
revoke all on function app.on_cancel__delivery_note(uuid) from public, anon, authenticated;
revoke all on function app.update_delivery_note_status(uuid, text) from public, anon;
grant execute on function app.update_delivery_note_status(uuid, text) to authenticated;

create or replace function public.update_delivery_note_status(p_id uuid, p_status text)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.update_delivery_note_status(p_id, p_status);
$$;

revoke all on function public.update_delivery_note_status(uuid, text) from public, anon;
grant execute on function public.update_delivery_note_status(uuid, text) to authenticated;

drop trigger if exists delivery_note_validate on public.delivery_note;
create trigger delivery_note_validate before insert or update on public.delivery_note
  for each row execute function app.delivery_note_validate();
drop trigger if exists touch_updated on public.delivery_note;
create trigger touch_updated before update on public.delivery_note
  for each row execute function app.touch_updated();
drop trigger if exists delivery_note_item_validate on public.delivery_note_item;
create trigger delivery_note_item_validate before insert or update on public.delivery_note_item
  for each row execute function app.delivery_note_item_validate();
drop trigger if exists delivery_note_item_sync on public.delivery_note_item;
create trigger delivery_note_item_sync after insert or update or delete on public.delivery_note_item
  for each row execute function app.delivery_note_item_sync();
drop trigger if exists packed_item_validate on public.packed_item;
create trigger packed_item_validate before insert or update on public.packed_item
  for each row execute function app.packed_item_validate();

-- Deferred so the rebuild runs after save_doc has written both the items and the packed rows.
drop trigger if exists delivery_note_item_pack on public.delivery_note_item;
create constraint trigger delivery_note_item_pack
  after insert or update or delete on public.delivery_note_item
  deferrable initially deferred
  for each row execute function app.pack_parent_items();
drop trigger if exists quotation_item_pack on public.quotation_item;
create constraint trigger quotation_item_pack
  after insert or update or delete on public.quotation_item
  deferrable initially deferred
  for each row execute function app.pack_parent_items();
drop trigger if exists sales_order_item_pack on public.sales_order_item;
create constraint trigger sales_order_item_pack
  after insert or update or delete on public.sales_order_item
  deferrable initially deferred
  for each row execute function app.pack_parent_items();

alter table public.delivery_note enable row level security;
alter table public.delivery_note force row level security;
alter table public.delivery_note_item enable row level security;
alter table public.delivery_note_item force row level security;
alter table public.packed_item enable row level security;
alter table public.packed_item force row level security;

drop policy if exists delivery_note_select on public.delivery_note;
create policy delivery_note_select on public.delivery_note for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Delivery Note', 'read'))::uuid[]));
drop policy if exists delivery_note_insert on public.delivery_note;
create policy delivery_note_insert on public.delivery_note for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Delivery Note', 'create'))::uuid[]));
drop policy if exists delivery_note_update on public.delivery_note;
create policy delivery_note_update on public.delivery_note for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]));
drop policy if exists delivery_note_delete on public.delivery_note;
create policy delivery_note_delete on public.delivery_note for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Delivery Note', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists delivery_note_item_select on public.delivery_note_item;
create policy delivery_note_item_select on public.delivery_note_item for select to authenticated
  using (exists (select 1 from public.delivery_note p where p.id = parent_id));
drop policy if exists delivery_note_item_insert on public.delivery_note_item;
create policy delivery_note_item_insert on public.delivery_note_item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Delivery Note', 'create'))::uuid[]));
drop policy if exists delivery_note_item_update on public.delivery_note_item;
create policy delivery_note_item_update on public.delivery_note_item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]));
drop policy if exists delivery_note_item_delete on public.delivery_note_item;
create policy delivery_note_item_delete on public.delivery_note_item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]));

drop policy if exists packed_item_select on public.packed_item;
create policy packed_item_select on public.packed_item for select to authenticated
  using (
    (parent_doctype = 'Delivery Note' and exists (select 1 from public.delivery_note p where p.id = parent_id))
    or (parent_doctype = 'Quotation' and exists (select 1 from public.quotation p where p.id = parent_id))
    or (parent_doctype = 'Sales Order' and exists (select 1 from public.sales_order p where p.id = parent_id))
  );
drop policy if exists packed_item_insert on public.packed_item;
create policy packed_item_insert on public.packed_item for insert to authenticated
  with check (
    (parent_doctype = 'Delivery Note' and (
      org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[])
      or org_id = any ((select app.orgs_with_perm('Delivery Note', 'create'))::uuid[])
    ))
    or (parent_doctype = 'Quotation' and (
      org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[])
      or org_id = any ((select app.orgs_with_perm('Quotation', 'create'))::uuid[])
    ))
    or (parent_doctype = 'Sales Order' and (
      org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[])
      or org_id = any ((select app.orgs_with_perm('Sales Order', 'create'))::uuid[])
    ))
  );
drop policy if exists packed_item_update on public.packed_item;
create policy packed_item_update on public.packed_item for update to authenticated
  using (
    (parent_doctype = 'Delivery Note' and org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]))
    or (parent_doctype = 'Quotation' and org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]))
    or (parent_doctype = 'Sales Order' and org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]))
  )
  with check (
    (parent_doctype = 'Delivery Note' and org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]))
    or (parent_doctype = 'Quotation' and org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]))
    or (parent_doctype = 'Sales Order' and org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]))
  );
drop policy if exists packed_item_delete on public.packed_item;
create policy packed_item_delete on public.packed_item for delete to authenticated
  using (
    (parent_doctype = 'Delivery Note' and org_id = any ((select app.orgs_with_perm('Delivery Note', 'write'))::uuid[]))
    or (parent_doctype = 'Quotation' and org_id = any ((select app.orgs_with_perm('Quotation', 'write'))::uuid[]))
    or (parent_doctype = 'Sales Order' and org_id = any ((select app.orgs_with_perm('Sales Order', 'write'))::uuid[]))
  );

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default
) values (
  'Delivery Note', 'delivery_note', 'stock', true, 'customer_name', 'MAT-DN-.YYYY.-'
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Delivery Note Item', 'delivery_note_item', 'stock', true, 'Delivery Note', 'items'),
  ('Packed Item', 'packed_item', 'stock', true, 'Delivery Note', 'packed_items')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Delivery Note', true, false, false, false, false, false, false),
  ('Stock User', 'Delivery Note', true, true, true, true, true, true, true),
  ('Stock Manager', 'Delivery Note', true, true, true, true, true, true, true),
  ('Sales User', 'Delivery Note', true, true, true, true, true, true, true),
  ('Accounts User', 'Delivery Note', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
