-- 0238 stock: Item (docs/modules/04-stock.md §2.1, §2.2, §2.4).
-- ERPNext: erpnext/stock/doctype/item/item.py autoname, validate,
-- add_default_uom_in_conversion_factor_table, validate_conversion_factor, validate_item_type,
-- check_item_tax, validate_barcode, validate_warehouse_for_reorder,
-- update_defaults_from_item_group, validate_item_defaults, validate_has_variants.
-- Naming Series, opening stock, asset category, and the stock-ledger change checks wait.

create table if not exists public.item (
  id                            uuid primary key default gen_random_uuid(),
  org_id                        uuid not null references public.organizations (id) on delete cascade,
  name                          text not null,
  item_code                     text not null check (length(trim(item_code)) > 0),
  item_name                     text not null,
  item_group_id                 uuid not null,
  stock_uom_id                  uuid not null,
  description                   text,
  is_stock_item                 boolean not null default true,
  is_sales_item                 boolean not null default true,
  is_purchase_item              boolean not null default true,
  disabled                      boolean not null default false,
  brand_id                      uuid,
  valuation_method              text check (valuation_method is null or valuation_method in ('FIFO', 'Moving Average')),
  valuation_rate                numeric(21,9),
  standard_rate                 numeric(21,9),
  last_purchase_rate            numeric(21,9),
  weight_per_unit               numeric(21,9),
  weight_uom_id                 uuid,
  has_batch_no                  boolean not null default false,
  create_new_batch              boolean not null default false,
  batch_number_series           text,
  has_expiry_date               boolean not null default false,
  has_serial_no                 boolean not null default false,
  serial_no_series              text,
  has_variants                  boolean not null default false,
  end_of_life                   date not null default '2099-12-31',
  default_material_request_type text not null default 'Purchase'
    check (default_material_request_type in ('Purchase', 'Material Transfer', 'Material Issue', 'Manufacture', 'Customer Provided')),
  min_order_qty                 numeric(21,9) not null default 0,
  safety_stock                  numeric(21,9),
  lead_time_days                int,
  max_discount                  numeric(21,9),
  grant_commission              boolean not null default true,
  over_delivery_receipt_allowance numeric(21,9),
  over_billing_allowance        numeric(21,9),
  allow_negative_stock          boolean not null default false,
  delivered_by_supplier         boolean not null default false,
  is_fixed_asset                boolean not null default false,
  include_item_in_manufacturing boolean not null default true,
  shelf_life_in_days            int,
  created_at                    timestamptz not null default now(),
  created_by                    uuid default auth.uid(),
  updated_at                    timestamptz not null default now(),
  updated_by                    uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, item_group_id) references public.item_group (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id),
  foreign key (org_id, brand_id) references public.brand (org_id, id) on delete set null (brand_id),
  foreign key (org_id, weight_uom_id) references public.uom (org_id, id) on delete set null (weight_uom_id)
);

create unique index if not exists item_code_uniq on public.item (org_id, lower(item_code));
create index if not exists item_group_idx on public.item (org_id, item_group_id);
create index if not exists item_stock_uom_idx on public.item (org_id, stock_uom_id);
create index if not exists item_brand_idx on public.item (org_id, brand_id);
create index if not exists item_weight_uom_idx on public.item (org_id, weight_uom_id);

create table if not exists public.item_uom (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations (id) on delete cascade,
  parent_id         uuid not null,
  idx               int not null,
  uom_id            uuid not null,
  conversion_factor numeric(21,9) not null,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, uom_id),
  foreign key (org_id, parent_id) references public.item (org_id, id) on delete cascade,
  foreign key (org_id, uom_id) references public.uom (org_id, id)
);

create table if not exists public.item_reorder (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  parent_id               uuid not null,
  idx                     int not null,
  warehouse_group_id      uuid,
  warehouse_id            uuid,
  material_request_type   text not null default 'Purchase'
    check (material_request_type in ('Purchase', 'Material Transfer', 'Material Issue', 'Manufacture', 'Customer Provided')),
  warehouse_reorder_level numeric(21,9) not null default 0,
  warehouse_reorder_qty   numeric(21,9) not null default 0,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.item (org_id, id) on delete cascade,
  foreign key (org_id, warehouse_id) references public.warehouse (org_id, id) on delete set null (warehouse_id),
  foreign key (org_id, warehouse_group_id) references public.warehouse (org_id, id) on delete set null (warehouse_group_id)
);

create table if not exists public.item_supplier (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  parent_id        uuid not null,
  idx              int not null,
  supplier_id      uuid not null,
  supplier_part_no text,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.item (org_id, id) on delete cascade,
  foreign key (org_id, supplier_id) references public.supplier (org_id, id)
);

create table if not exists public.item_barcode (
  id        uuid primary key default gen_random_uuid(),
  org_id    uuid not null references public.organizations (id) on delete cascade,
  parent_id uuid not null,
  idx       int not null,
  barcode   text not null check (length(trim(barcode)) > 0),
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.item (org_id, id) on delete cascade
);

create unique index if not exists item_barcode_uniq on public.item_barcode (org_id, lower(barcode));

create table if not exists public.item_default (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations (id) on delete cascade,
  parent_id              uuid not null,
  idx                    int not null,
  company_id             uuid not null,
  default_warehouse_id   uuid,
  default_price_list_id  uuid,
  income_account_id      uuid,
  expense_account_id     uuid,
  buying_cost_center_id  uuid,
  selling_cost_center_id uuid,
  default_supplier_id    uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.item (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, default_warehouse_id) references public.warehouse (org_id, id) on delete set null (default_warehouse_id),
  foreign key (org_id, default_price_list_id) references public.price_list (org_id, id) on delete set null (default_price_list_id),
  foreign key (org_id, income_account_id) references public.account (org_id, id) on delete set null (income_account_id),
  foreign key (org_id, expense_account_id) references public.account (org_id, id) on delete set null (expense_account_id),
  foreign key (org_id, buying_cost_center_id) references public.cost_center (org_id, id) on delete set null (buying_cost_center_id),
  foreign key (org_id, selling_cost_center_id) references public.cost_center (org_id, id) on delete set null (selling_cost_center_id),
  foreign key (org_id, default_supplier_id) references public.supplier (org_id, id) on delete set null (default_supplier_id)
);

create table if not exists public.item_group_default (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations (id) on delete cascade,
  parent_id              uuid not null,
  idx                    int not null,
  company_id             uuid not null,
  default_warehouse_id   uuid,
  default_price_list_id  uuid,
  income_account_id      uuid,
  expense_account_id     uuid,
  buying_cost_center_id  uuid,
  selling_cost_center_id uuid,
  default_supplier_id    uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.item_group (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, default_warehouse_id) references public.warehouse (org_id, id) on delete set null (default_warehouse_id),
  foreign key (org_id, default_price_list_id) references public.price_list (org_id, id) on delete set null (default_price_list_id),
  foreign key (org_id, income_account_id) references public.account (org_id, id) on delete set null (income_account_id),
  foreign key (org_id, expense_account_id) references public.account (org_id, id) on delete set null (expense_account_id),
  foreign key (org_id, buying_cost_center_id) references public.cost_center (org_id, id) on delete set null (buying_cost_center_id),
  foreign key (org_id, selling_cost_center_id) references public.cost_center (org_id, id) on delete set null (selling_cost_center_id),
  foreign key (org_id, default_supplier_id) references public.supplier (org_id, id) on delete set null (default_supplier_id)
);

create table if not exists public.brand_default (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations (id) on delete cascade,
  parent_id              uuid not null,
  idx                    int not null,
  company_id             uuid not null,
  default_warehouse_id   uuid,
  default_price_list_id  uuid,
  income_account_id      uuid,
  expense_account_id     uuid,
  buying_cost_center_id  uuid,
  selling_cost_center_id uuid,
  default_supplier_id    uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.brand (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, default_warehouse_id) references public.warehouse (org_id, id) on delete set null (default_warehouse_id),
  foreign key (org_id, default_price_list_id) references public.price_list (org_id, id) on delete set null (default_price_list_id),
  foreign key (org_id, income_account_id) references public.account (org_id, id) on delete set null (income_account_id),
  foreign key (org_id, expense_account_id) references public.account (org_id, id) on delete set null (expense_account_id),
  foreign key (org_id, buying_cost_center_id) references public.cost_center (org_id, id) on delete set null (buying_cost_center_id),
  foreign key (org_id, selling_cost_center_id) references public.cost_center (org_id, id) on delete set null (selling_cost_center_id),
  foreign key (org_id, default_supplier_id) references public.supplier (org_id, id) on delete set null (default_supplier_id)
);

create table if not exists public.item_tax (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references public.organizations (id) on delete cascade,
  parent_id            uuid not null,
  idx                  int not null,
  item_tax_template_id uuid,
  tax_category_id      uuid,
  valid_from           date,
  minimum_net_rate     numeric(21,9),
  maximum_net_rate     numeric(21,9),
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.item (org_id, id) on delete cascade,
  foreign key (org_id, item_tax_template_id) references public.item_tax_template (org_id, id) on delete set null (item_tax_template_id),
  foreign key (org_id, tax_category_id) references public.tax_category (org_id, id) on delete set null (tax_category_id)
);

create table if not exists public.item_group_tax (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references public.organizations (id) on delete cascade,
  parent_id            uuid not null,
  idx                  int not null,
  item_tax_template_id uuid,
  tax_category_id      uuid,
  valid_from           date,
  minimum_net_rate     numeric(21,9),
  maximum_net_rate     numeric(21,9),
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.item_group (org_id, id) on delete cascade,
  foreign key (org_id, item_tax_template_id) references public.item_tax_template (org_id, id) on delete set null (item_tax_template_id),
  foreign key (org_id, tax_category_id) references public.tax_category (org_id, id) on delete set null (tax_category_id)
);

create index if not exists item_uom_parent_idx on public.item_uom (org_id, parent_id);
create index if not exists item_uom_uom_idx on public.item_uom (org_id, uom_id);
create index if not exists item_reorder_parent_idx on public.item_reorder (org_id, parent_id);
create index if not exists item_reorder_warehouse_idx on public.item_reorder (org_id, warehouse_id);
create index if not exists item_reorder_warehouse_group_idx on public.item_reorder (org_id, warehouse_group_id);
create index if not exists item_supplier_parent_idx on public.item_supplier (org_id, parent_id);
create index if not exists item_supplier_supplier_idx on public.item_supplier (org_id, supplier_id);
create index if not exists item_barcode_parent_idx on public.item_barcode (org_id, parent_id);
create index if not exists item_default_parent_idx on public.item_default (org_id, parent_id);
create index if not exists item_default_company_idx on public.item_default (org_id, company_id);
create index if not exists item_default_warehouse_idx on public.item_default (org_id, default_warehouse_id);
create index if not exists item_default_price_list_idx on public.item_default (org_id, default_price_list_id);
create index if not exists item_default_income_idx on public.item_default (org_id, income_account_id);
create index if not exists item_default_expense_idx on public.item_default (org_id, expense_account_id);
create index if not exists item_default_buying_cc_idx on public.item_default (org_id, buying_cost_center_id);
create index if not exists item_default_selling_cc_idx on public.item_default (org_id, selling_cost_center_id);
create index if not exists item_default_supplier_idx on public.item_default (org_id, default_supplier_id);
create index if not exists item_group_default_parent_idx on public.item_group_default (org_id, parent_id);
create index if not exists item_group_default_company_idx on public.item_group_default (org_id, company_id);
create index if not exists item_group_default_warehouse_idx on public.item_group_default (org_id, default_warehouse_id);
create index if not exists item_group_default_price_list_idx on public.item_group_default (org_id, default_price_list_id);
create index if not exists item_group_default_income_idx on public.item_group_default (org_id, income_account_id);
create index if not exists item_group_default_expense_idx on public.item_group_default (org_id, expense_account_id);
create index if not exists item_group_default_buying_cc_idx on public.item_group_default (org_id, buying_cost_center_id);
create index if not exists item_group_default_selling_cc_idx on public.item_group_default (org_id, selling_cost_center_id);
create index if not exists item_group_default_supplier_idx on public.item_group_default (org_id, default_supplier_id);
create index if not exists brand_default_parent_idx on public.brand_default (org_id, parent_id);
create index if not exists brand_default_company_idx on public.brand_default (org_id, company_id);
create index if not exists brand_default_warehouse_idx on public.brand_default (org_id, default_warehouse_id);
create index if not exists brand_default_price_list_idx on public.brand_default (org_id, default_price_list_id);
create index if not exists brand_default_income_idx on public.brand_default (org_id, income_account_id);
create index if not exists brand_default_expense_idx on public.brand_default (org_id, expense_account_id);
create index if not exists brand_default_buying_cc_idx on public.brand_default (org_id, buying_cost_center_id);
create index if not exists brand_default_selling_cc_idx on public.brand_default (org_id, selling_cost_center_id);
create index if not exists brand_default_supplier_idx on public.brand_default (org_id, default_supplier_id);
create index if not exists item_tax_parent_idx on public.item_tax (org_id, parent_id);
create index if not exists item_tax_template_idx on public.item_tax (org_id, item_tax_template_id);
create index if not exists item_tax_category_idx on public.item_tax (org_id, tax_category_id);
create index if not exists item_group_tax_parent_idx on public.item_group_tax (org_id, parent_id);
create index if not exists item_group_tax_template_idx on public.item_group_tax (org_id, item_tax_template_id);
create index if not exists item_group_tax_category_idx on public.item_group_tax (org_id, tax_category_id);

create or replace function app.item_group_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.item_group_name := trim(new.item_group_name);
  if new.parent_id is null and new.item_group_name <> 'All Item Groups' then
    select id into new.parent_id from public.item_group
     where org_id = new.org_id and parent_id is null;
  end if;
  if tg_op = 'UPDATE' and new.is_group and not old.is_group and exists (
    select 1 from public.item i where i.item_group_id = new.id
  ) then
    raise exception using errcode = 'P0001',
      message = 'item_group_in_use: An Item Group selected on an item cannot become a group';
  end if;
  return new;
end;
$$;

create or replace function app.item_validate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_group boolean;
  v_enabled boolean;
  v_series text;
begin
  new.item_code := trim(new.item_code);
  if nullif(trim(new.item_name), '') is null then
    new.item_name := new.item_code;
  else
    new.item_name := trim(new.item_name);
  end if;
  new.name := new.item_code;
  if new.valuation_method = '' then
    new.valuation_method := null;
  end if;
  if new.has_variants then
    raise exception using errcode = 'P0001', message = 'item_variants: Item variants are not built';
  end if;
  if new.stock_uom_id is null then
    select u.id into new.stock_uom_id from public.uom u
     where u.org_id = new.org_id and lower(u.uom_name) = 'nos'
     limit 1;
  end if;
  select is_group into v_group from public.item_group where id = new.item_group_id;
  if v_group then
    raise exception using errcode = 'P0001', message = 'item_group_leaf: Item Group must be a leaf';
  end if;
  select enabled into v_enabled from public.uom where id = new.stock_uom_id;
  if v_enabled is not true then
    raise exception using errcode = 'P0001', message = 'item_uom: Stock UOM is disabled';
  end if;
  if tg_op = 'INSERT' and new.end_of_life < current_date then
    raise exception using errcode = 'P0001', message = 'item_end_of_life: End of Life cannot be before today';
  end if;
  if new.has_serial_no and not new.is_stock_item and not new.is_fixed_asset then
    raise exception using errcode = 'P0001', message = 'item_serial: Has Serial No cannot be Yes for a non-stock item';
  end if;
  if not new.has_serial_no then
    new.serial_no_series := null;
  end if;
  foreach v_series in array array[new.serial_no_series, new.batch_number_series] loop
    if v_series is not null and position('#' in v_series) > 0 and position('.' in v_series) = 0 then
      raise exception using errcode = 'P0001', message = 'item_series: Invalid naming series (. missing)';
    end if;
  end loop;
  return new;
end;
$$;

create or replace function app.item_uom_validate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_stock uuid;
begin
  if new.conversion_factor is null or new.conversion_factor <= 0 then
    raise exception using errcode = 'P0001',
      message = format('item_uom_factor: Row %s: Conversion Factor must be greater than zero', new.idx);
  end if;
  select stock_uom_id into v_stock from public.item where id = new.parent_id;
  if new.uom_id = v_stock and new.conversion_factor <> 1 then
    raise exception using errcode = 'P0001',
      message = format('item_uom_factor: Conversion factor for default Unit of Measure must be 1 in row %s', new.idx);
  end if;
  return new;
end;
$$;

create or replace function app.item_ensure_stock_uom()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.stock_uom_id is distinct from old.stock_uom_id then
    delete from public.item_uom where parent_id = new.id;
  end if;
  if not exists (
    select 1 from public.item_uom u where u.parent_id = new.id and u.uom_id = new.stock_uom_id
  ) then
    insert into public.item_uom (org_id, parent_id, idx, uom_id, conversion_factor)
    values (
      new.org_id,
      new.id,
      coalesce((select max(u.idx) from public.item_uom u where u.parent_id = new.id), 0) + 1,
      new.stock_uom_id,
      1
    );
  end if;
  return null;
end;
$$;

create or replace function app.item_reorder_validate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.warehouse_group_id is null then
    new.warehouse_group_id := new.warehouse_id;
  end if;
  if exists (
    select 1 from public.item_reorder r
     where r.parent_id = new.parent_id
       and r.id is distinct from new.id
       and r.warehouse_id is not distinct from new.warehouse_id
       and r.material_request_type = new.material_request_type
  ) then
    raise exception using errcode = 'P0001',
      message = format('item_reorder: Row %s: A reorder entry already exists for this warehouse and type', new.idx);
  end if;
  if coalesce(new.warehouse_reorder_level, 0) <> 0 and coalesce(new.warehouse_reorder_qty, 0) = 0 then
    raise exception using errcode = 'P0001',
      message = format('item_reorder: Row %s: Please set reorder quantity', new.idx);
  end if;
  if new.warehouse_id is not null and new.warehouse_group_id is not null and not exists (
    select 1 from public.warehouse w
     join public.warehouse g on g.id = new.warehouse_group_id
     where w.id = new.warehouse_id and w.path operator(extensions.<@) g.path
  ) then
    raise exception using errcode = 'P0001',
      message = format('item_reorder: Row %s: Warehouse is not a child of the group warehouse', new.idx);
  end if;
  return new;
end;
$$;

create or replace function app.item_tax_validate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_hit boolean;
begin
  if coalesce(new.maximum_net_rate, 0) < coalesce(new.minimum_net_rate, 0) then
    raise exception using errcode = 'P0001',
      message = format('item_tax_range: Taxes row %s: Maximum Net Rate cannot be smaller than Minimum Net Rate', new.idx);
  end if;
  if new.item_tax_template_id is not null then
    execute format(
      'select exists (select 1 from public.%I t where t.parent_id = $1 and t.id is distinct from $2 and t.item_tax_template_id = $3 and t.tax_category_id is not distinct from $4)',
      tg_table_name
    ) into v_hit using new.parent_id, new.id, new.item_tax_template_id, new.tax_category_id;
    if v_hit then
      raise exception using errcode = 'P0001', message = 'item_tax_duplicate: Item Tax Template entered twice';
    end if;
  end if;
  return new;
end;
$$;

create or replace function app.item_default_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company uuid;
begin
  if new.default_warehouse_id is not null then
    select company_id into v_company from public.warehouse where id = new.default_warehouse_id;
    if v_company is distinct from new.company_id then
      raise exception using errcode = 'P0001',
        message = format('item_default_company: Row %s: Warehouse does not belong to the company', new.idx);
    end if;
  end if;
  if new.income_account_id is not null then
    select company_id into v_company from public.account where id = new.income_account_id;
    if v_company is distinct from new.company_id then
      raise exception using errcode = 'P0001',
        message = format('item_default_company: Row %s: Income Account does not belong to the company', new.idx);
    end if;
  end if;
  if new.expense_account_id is not null then
    select company_id into v_company from public.account where id = new.expense_account_id;
    if v_company is distinct from new.company_id then
      raise exception using errcode = 'P0001',
        message = format('item_default_company: Row %s: Expense Account does not belong to the company', new.idx);
    end if;
  end if;
  if new.buying_cost_center_id is not null then
    select company_id into v_company from public.cost_center where id = new.buying_cost_center_id;
    if v_company is distinct from new.company_id then
      raise exception using errcode = 'P0001',
        message = format('item_default_company: Row %s: Buying Cost Center does not belong to the company', new.idx);
    end if;
  end if;
  if new.selling_cost_center_id is not null then
    select company_id into v_company from public.cost_center where id = new.selling_cost_center_id;
    if v_company is distinct from new.company_id then
      raise exception using errcode = 'P0001',
        message = format('item_default_company: Row %s: Selling Cost Center does not belong to the company', new.idx);
    end if;
  end if;
  return new;
end;
$$;

create or replace function app.copy_item_group_details(p_item uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_org uuid;
  v_group uuid;
begin
  select org_id, item_group_id into v_org, v_group from public.item where id = p_item;
  if v_group is null then
    return;
  end if;
  if not exists (select 1 from public.item_default where parent_id = p_item) then
    insert into public.item_default (
      org_id, parent_id, idx, company_id, default_warehouse_id, default_price_list_id,
      income_account_id, expense_account_id, buying_cost_center_id, selling_cost_center_id, default_supplier_id
    )
    select v_org, p_item, d.idx, d.company_id, d.default_warehouse_id, d.default_price_list_id,
           d.income_account_id, d.expense_account_id, d.buying_cost_center_id, d.selling_cost_center_id, d.default_supplier_id
      from public.item_group_default d
     where d.parent_id = v_group;
  end if;
  if not exists (select 1 from public.item_tax where parent_id = p_item) then
    insert into public.item_tax (
      org_id, parent_id, idx, item_tax_template_id, tax_category_id, valid_from, minimum_net_rate, maximum_net_rate
    )
    select v_org, p_item, t.idx, t.item_tax_template_id, t.tax_category_id, t.valid_from, t.minimum_net_rate, t.maximum_net_rate
      from public.item_group_tax t
     where t.parent_id = v_group;
  end if;
end;
$$;

create or replace function public.copy_item_group_details(p_item uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.copy_item_group_details(p_item);
$$;

create or replace function app.item_copy_group()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform app.copy_item_group_details(new.id);
  return null;
end;
$$;

create or replace function app.organizations_clear_items()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.item where org_id = old.id;
  return old;
end;
$$;

revoke all on function app.item_validate() from public, anon, authenticated;
revoke all on function app.item_uom_validate() from public, anon, authenticated;
revoke all on function app.item_ensure_stock_uom() from public, anon, authenticated;
revoke all on function app.item_reorder_validate() from public, anon, authenticated;
revoke all on function app.item_tax_validate() from public, anon, authenticated;
revoke all on function app.item_default_validate() from public, anon, authenticated;
revoke all on function app.item_copy_group() from public, anon, authenticated;
revoke all on function app.organizations_clear_items() from public, anon, authenticated;
revoke all on function app.copy_item_group_details(uuid) from public, anon;
grant execute on function app.copy_item_group_details(uuid) to authenticated;
revoke all on function public.copy_item_group_details(uuid) from public, anon;
grant execute on function public.copy_item_group_details(uuid) to authenticated;

drop trigger if exists item_validate on public.item;
create trigger item_validate before insert or update on public.item
  for each row execute function app.item_validate();
drop trigger if exists item_ensure_stock_uom on public.item;
create trigger item_ensure_stock_uom after insert or update on public.item
  for each row execute function app.item_ensure_stock_uom();
drop trigger if exists item_copy_group on public.item;
create trigger item_copy_group after insert or update on public.item
  for each row execute function app.item_copy_group();
drop trigger if exists touch_updated on public.item;
create trigger touch_updated before update on public.item
  for each row execute function app.touch_updated();

drop trigger if exists item_uom_validate on public.item_uom;
create trigger item_uom_validate before insert or update on public.item_uom
  for each row execute function app.item_uom_validate();
drop trigger if exists item_reorder_validate on public.item_reorder;
create trigger item_reorder_validate before insert or update on public.item_reorder
  for each row execute function app.item_reorder_validate();
drop trigger if exists item_tax_validate on public.item_tax;
create trigger item_tax_validate before insert or update on public.item_tax
  for each row execute function app.item_tax_validate();
drop trigger if exists item_group_tax_validate on public.item_group_tax;
create trigger item_group_tax_validate before insert or update on public.item_group_tax
  for each row execute function app.item_tax_validate();
drop trigger if exists item_default_validate on public.item_default;
create trigger item_default_validate before insert or update on public.item_default
  for each row execute function app.item_default_validate();
drop trigger if exists item_group_default_validate on public.item_group_default;
create trigger item_group_default_validate before insert or update on public.item_group_default
  for each row execute function app.item_default_validate();
drop trigger if exists brand_default_validate on public.brand_default;
create trigger brand_default_validate before insert or update on public.brand_default
  for each row execute function app.item_default_validate();

drop trigger if exists organizations_clear_items on public.organizations;
create trigger organizations_clear_items before delete on public.organizations
  for each row execute function app.organizations_clear_items();

alter table public.item enable row level security;
alter table public.item force row level security;
alter table public.item_uom enable row level security;
alter table public.item_uom force row level security;
alter table public.item_reorder enable row level security;
alter table public.item_reorder force row level security;
alter table public.item_supplier enable row level security;
alter table public.item_supplier force row level security;
alter table public.item_barcode enable row level security;
alter table public.item_barcode force row level security;
alter table public.item_default enable row level security;
alter table public.item_default force row level security;
alter table public.item_tax enable row level security;
alter table public.item_tax force row level security;
alter table public.item_group_default enable row level security;
alter table public.item_group_default force row level security;
alter table public.item_group_tax enable row level security;
alter table public.item_group_tax force row level security;
alter table public.brand_default enable row level security;
alter table public.brand_default force row level security;

drop policy if exists item_select on public.item;
create policy item_select on public.item for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'read'))::uuid[]));
drop policy if exists item_insert on public.item;
create policy item_insert on public.item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item', 'create'))::uuid[]));
drop policy if exists item_update on public.item;
create policy item_update on public.item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));
drop policy if exists item_delete on public.item;
create policy item_delete on public.item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'delete'))::uuid[]));

drop policy if exists item_uom_select on public.item_uom;
create policy item_uom_select on public.item_uom for select to authenticated
  using (exists (select 1 from public.item p where p.id = parent_id));
drop policy if exists item_uom_insert on public.item_uom;
create policy item_uom_insert on public.item_uom for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item', 'create'))::uuid[]));
drop policy if exists item_uom_update on public.item_uom;
create policy item_uom_update on public.item_uom for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));
drop policy if exists item_uom_delete on public.item_uom;
create policy item_uom_delete on public.item_uom for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));

drop policy if exists item_reorder_select on public.item_reorder;
create policy item_reorder_select on public.item_reorder for select to authenticated
  using (exists (select 1 from public.item p where p.id = parent_id));
drop policy if exists item_reorder_insert on public.item_reorder;
create policy item_reorder_insert on public.item_reorder for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item', 'create'))::uuid[]));
drop policy if exists item_reorder_update on public.item_reorder;
create policy item_reorder_update on public.item_reorder for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));
drop policy if exists item_reorder_delete on public.item_reorder;
create policy item_reorder_delete on public.item_reorder for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));

drop policy if exists item_supplier_select on public.item_supplier;
create policy item_supplier_select on public.item_supplier for select to authenticated
  using (exists (select 1 from public.item p where p.id = parent_id));
drop policy if exists item_supplier_insert on public.item_supplier;
create policy item_supplier_insert on public.item_supplier for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item', 'create'))::uuid[]));
drop policy if exists item_supplier_update on public.item_supplier;
create policy item_supplier_update on public.item_supplier for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));
drop policy if exists item_supplier_delete on public.item_supplier;
create policy item_supplier_delete on public.item_supplier for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));

drop policy if exists item_barcode_select on public.item_barcode;
create policy item_barcode_select on public.item_barcode for select to authenticated
  using (exists (select 1 from public.item p where p.id = parent_id));
drop policy if exists item_barcode_insert on public.item_barcode;
create policy item_barcode_insert on public.item_barcode for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item', 'create'))::uuid[]));
drop policy if exists item_barcode_update on public.item_barcode;
create policy item_barcode_update on public.item_barcode for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));
drop policy if exists item_barcode_delete on public.item_barcode;
create policy item_barcode_delete on public.item_barcode for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));

drop policy if exists item_default_select on public.item_default;
create policy item_default_select on public.item_default for select to authenticated
  using (exists (select 1 from public.item p where p.id = parent_id));
drop policy if exists item_default_insert on public.item_default;
create policy item_default_insert on public.item_default for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item', 'create'))::uuid[]));
drop policy if exists item_default_update on public.item_default;
create policy item_default_update on public.item_default for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));
drop policy if exists item_default_delete on public.item_default;
create policy item_default_delete on public.item_default for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));

drop policy if exists item_tax_select on public.item_tax;
create policy item_tax_select on public.item_tax for select to authenticated
  using (exists (select 1 from public.item p where p.id = parent_id));
drop policy if exists item_tax_insert on public.item_tax;
create policy item_tax_insert on public.item_tax for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item', 'create'))::uuid[]));
drop policy if exists item_tax_update on public.item_tax;
create policy item_tax_update on public.item_tax for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));
drop policy if exists item_tax_delete on public.item_tax;
create policy item_tax_delete on public.item_tax for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item', 'write'))::uuid[]));

drop policy if exists item_group_default_select on public.item_group_default;
create policy item_group_default_select on public.item_group_default for select to authenticated
  using (exists (
    select 1 from public.item_group p where p.id = item_group_default.parent_id
  ));
drop policy if exists item_group_default_insert on public.item_group_default;
create policy item_group_default_insert on public.item_group_default for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item Group', 'create'))::uuid[]));
drop policy if exists item_group_default_update on public.item_group_default;
create policy item_group_default_update on public.item_group_default for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]));
drop policy if exists item_group_default_delete on public.item_group_default;
create policy item_group_default_delete on public.item_group_default for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]));

drop policy if exists item_group_tax_select on public.item_group_tax;
create policy item_group_tax_select on public.item_group_tax for select to authenticated
  using (exists (
    select 1 from public.item_group p where p.id = item_group_tax.parent_id
  ));
drop policy if exists item_group_tax_insert on public.item_group_tax;
create policy item_group_tax_insert on public.item_group_tax for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item Group', 'create'))::uuid[]));
drop policy if exists item_group_tax_update on public.item_group_tax;
create policy item_group_tax_update on public.item_group_tax for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]));
drop policy if exists item_group_tax_delete on public.item_group_tax;
create policy item_group_tax_delete on public.item_group_tax for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Group', 'write'))::uuid[]));

drop policy if exists brand_default_select on public.brand_default;
create policy brand_default_select on public.brand_default for select to authenticated
  using (exists (select 1 from public.brand p where p.id = parent_id));
drop policy if exists brand_default_insert on public.brand_default;
create policy brand_default_insert on public.brand_default for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Brand', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Brand', 'create'))::uuid[]));
drop policy if exists brand_default_update on public.brand_default;
create policy brand_default_update on public.brand_default for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Brand', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Brand', 'write'))::uuid[]));
drop policy if exists brand_default_delete on public.brand_default;
create policy brand_default_delete on public.brand_default for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Brand', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field, html_columns)
values ('Item', 'item', 'stock', 'item_name', '{description}')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field,
      html_columns = excluded.html_columns;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('UOM Conversion Detail', 'item_uom', 'stock', true, 'Item', 'uoms'),
  ('Item Reorder', 'item_reorder', 'stock', true, 'Item', 'reorder_levels'),
  ('Item Supplier', 'item_supplier', 'stock', true, 'Item', 'supplier_items'),
  ('Item Barcode', 'item_barcode', 'stock', true, 'Item', 'barcodes'),
  ('Item Default', 'item_default', 'stock', true, 'Item', 'item_defaults'),
  ('Item Tax', 'item_tax', 'stock', true, 'Item', 'taxes'),
  ('Item Group Default', 'item_group_default', 'stock', true, 'Item Group', 'item_group_defaults'),
  ('Item Group Tax', 'item_group_tax', 'stock', true, 'Item Group', 'taxes'),
  ('Brand Default', 'brand_default', 'stock', true, 'Brand', 'brand_defaults')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Item', true, false, false, false),
  ('Item Manager', 'Item', true, true, true, true),
  ('Stock Manager', 'Item', true, false, false, false),
  ('Stock User', 'Item', true, false, false, false),
  ('Sales User', 'Item', true, false, false, false),
  ('Purchase User', 'Item', true, false, false, false),
  ('Accounts User', 'Item', true, false, false, false),
  ('Manufacturing User', 'Item', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
