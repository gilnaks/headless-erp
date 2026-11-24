-- 0510 accounts: Sales Invoice document and its general-ledger pair.
-- ERPNext: erpnext/accounts/doctype/sales_invoice/sales_invoice.json
-- ERPNext: erpnext/accounts/doctype/sales_invoice/sales_invoice.py
-- ERPNext: erpnext/accounts/doctype/sales_invoice/services/gl_composer.py
-- ERPNext: erpnext/accounts/doctype/sales_invoice/services/status.py
-- Header totals are the sum of the item amounts. Taxes, returns, stock, the payment
-- schedule, advances, and billed_amt stay on their own checklist lines.
-- A later payment does not change status: app.refresh_outstanding still no-ops.

create table if not exists public.sales_invoice (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  name                    text not null,
  customer_name           text,
  naming_series           text not null default 'ACC-SINV-.YYYY.-',
  customer_id             uuid not null,
  company_id              uuid not null,
  posting_date            date not null default current_date,
  posting_time            time not null default current_time,
  due_date                date not null,
  currency                text not null,
  conversion_rate         numeric(21,9) not null default 1,
  selling_price_list_id   uuid not null,
  debit_to_id             uuid not null,
  cost_center_id          uuid,
  status                  text not null default 'Draft'
    check (status in (
      'Draft', 'Return', 'Credit Note Issued', 'Submitted', 'Paid', 'Partly Paid', 'Unpaid',
      'Unpaid and Discounted', 'Partly Paid and Discounted', 'Overdue and Discounted',
      'Overdue', 'Cancelled', 'Internal Transfer'
    )),
  total                   numeric(21,9) not null default 0,
  net_total               numeric(21,9) not null default 0,
  grand_total             numeric(21,9) not null default 0,
  base_grand_total        numeric(21,9) not null default 0,
  outstanding_amount      numeric(21,9) not null default 0,
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
  foreign key (org_id, debit_to_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  foreign key (org_id, amended_from) references public.sales_invoice (org_id, id) on delete set null (amended_from)
);

create index if not exists sales_invoice_customer_idx on public.sales_invoice (org_id, customer_id);
create index if not exists sales_invoice_company_idx on public.sales_invoice (org_id, company_id);
create index if not exists sales_invoice_price_list_idx on public.sales_invoice (org_id, selling_price_list_id);
create index if not exists sales_invoice_debit_to_idx on public.sales_invoice (org_id, debit_to_id);
create index if not exists sales_invoice_cost_center_idx on public.sales_invoice (org_id, cost_center_id);
create index if not exists sales_invoice_amended_idx on public.sales_invoice (org_id, amended_from);

create table if not exists public.sales_invoice_item (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations (id) on delete cascade,
  parent_id          uuid not null,
  idx                int not null,
  item_id            uuid not null,
  item_name          text,
  qty                numeric(21,9) not null,
  rate               numeric(21,9) not null default 0,
  amount             numeric(21,9) not null default 0,
  income_account_id  uuid not null,
  cost_center_id     uuid not null,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.sales_invoice (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, income_account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id)
);

create index if not exists sales_invoice_item_parent_idx on public.sales_invoice_item (org_id, parent_id);
create index if not exists sales_invoice_item_item_idx on public.sales_invoice_item (org_id, item_id);
create index if not exists sales_invoice_item_income_idx on public.sales_invoice_item (org_id, income_account_id);
create index if not exists sales_invoice_item_cost_center_idx on public.sales_invoice_item (org_id, cost_center_id);

create or replace function app.sales_invoice_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  v_customer_name text;
  v_currency text;
  v_cc uuid;
  v_acc_company uuid;
  v_acc_type text;
  v_group boolean;
  v_disabled boolean;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
  end if;
  if new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'ACC-SINV-.YYYY.-';
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
  if new.posting_date is null then
    new.posting_date := current_date;
  end if;
  if new.posting_time is null then
    new.posting_time := current_time;
  end if;
  if new.due_date is null then
    new.due_date := new.posting_date;
  end if;
  if new.due_date < new.posting_date then
    raise exception using errcode = 'P0001',
      message = 'si_due_date: Due Date cannot be before Posting Date';
  end if;

  if new.customer_id is null then
    raise exception using errcode = 'P0001', message = 'si_customer: Customer is required';
  end if;
  select c.customer_name into v_customer_name
    from public.customer c
   where c.id = new.customer_id and c.org_id = new.org_id;
  if v_customer_name is null then
    raise exception using errcode = 'P0001', message = 'si_customer: Customer is required';
  end if;
  if new.customer_name is null or btrim(new.customer_name) = '' then
    new.customer_name := v_customer_name;
  end if;

  if new.company_id is null then
    raise exception using errcode = 'P0001', message = 'si_company: Company is required';
  end if;
  select c.default_currency, c.cost_center_id into v_currency, v_cc
    from public.companies c
   where c.id = new.company_id and c.org_id = new.org_id;
  if v_currency is null then
    raise exception using errcode = 'P0001', message = 'si_company: Company is required';
  end if;
  if new.currency is null or btrim(new.currency) = '' then
    new.currency := v_currency;
  end if;
  if new.cost_center_id is null then
    new.cost_center_id := v_cc;
  end if;
  if new.conversion_rate is null or new.conversion_rate = 0 then
    new.conversion_rate := 1;
  end if;
  if new.conversion_rate <= 0 then
    raise exception using errcode = 'P0001',
      message = 'si_conversion: Exchange Rate must be greater than zero';
  end if;

  if new.selling_price_list_id is null then
    select s.selling_price_list_id into new.selling_price_list_id
      from public.selling_settings s
     where s.org_id = new.org_id;
  end if;
  if new.selling_price_list_id is null or not exists (
    select 1 from public.price_list p
     where p.id = new.selling_price_list_id and p.org_id = new.org_id and p.selling and p.enabled
  ) then
    raise exception using errcode = 'P0001',
      message = 'si_price_list: Selling Price List must be a selling price list';
  end if;

  if new.debit_to_id is null then
    new.debit_to_id := app.get_party_account('Customer', new.customer_id, new.company_id);
  end if;
  select a.company_id, a.account_type, a.is_group, a.disabled
    into v_acc_company, v_acc_type, v_group, v_disabled
    from public.account a
   where a.id = new.debit_to_id and a.org_id = new.org_id;
  if v_acc_company is distinct from new.company_id
     or v_acc_type is distinct from 'Receivable'
     or coalesce(v_group, true)
     or coalesce(v_disabled, false) then
    raise exception using errcode = 'P0001',
      message = 'si_receivable: Debit To must be a receivable ledger of this company';
  end if;

  new.total := coalesce(new.total, 0);
  new.net_total := new.total;
  new.grand_total := new.total;
  new.base_grand_total := app.round(new.grand_total * new.conversion_rate, 2);
  if new.status is null or btrim(new.status) = '' then
    new.status := 'Draft';
  end if;
  if new.docstatus = 0 and current_user = 'authenticated' then
    new.status := 'Draft';
    new.outstanding_amount := new.base_grand_total;
  end if;
  return new;
end;
$fn$;

create or replace function app.sales_invoice_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  h public.sales_invoice;
  v_code text;
  v_item_name text;
  v_disabled boolean;
  v_sales boolean;
  v_acc_company uuid;
  v_group boolean;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.parent_id is null then
    raise exception using errcode = 'P0001', message = 'si_item: Sales Invoice is required';
  end if;
  select * into h from public.sales_invoice where id = new.parent_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'si_item: Sales Invoice is required';
  end if;
  if h.docstatus <> 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  new.org_id := h.org_id;

  if new.item_id is null then
    raise exception using errcode = 'P0001', message = 'si_item: Item is required';
  end if;
  select i.item_code, i.item_name, i.disabled, i.is_sales_item
    into v_code, v_item_name, v_disabled, v_sales
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if v_code is null then
    raise exception using errcode = 'P0001', message = 'si_item: Item is required';
  end if;
  if v_disabled then
    raise exception using errcode = 'P0001',
      message = format('si_item: Item %s is disabled', v_code);
  end if;
  if not coalesce(v_sales, false) then
    raise exception using errcode = 'P0001',
      message = format('si_item: Item %s is not a sales item', v_code);
  end if;
  if new.item_name is null or btrim(new.item_name) = '' then
    new.item_name := v_item_name;
  end if;
  if new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001', message = 'si_qty: Qty must be greater than zero';
  end if;
  if new.rate is null then
    new.rate := 0;
  end if;
  if new.rate < 0 then
    raise exception using errcode = 'P0001', message = 'si_rate: Rate cannot be negative';
  end if;
  new.amount := app.round(new.qty * new.rate, 2);

  if new.income_account_id is null then
    select d.income_account_id into new.income_account_id
      from public.item_default d
     where d.parent_id = new.item_id
       and d.company_id = h.company_id
       and d.income_account_id is not null
     limit 1;
  end if;
  if new.income_account_id is null then
    select c.default_income_account_id into new.income_account_id
      from public.companies c
     where c.id = h.company_id and c.org_id = h.org_id;
  end if;
  if new.income_account_id is null then
    raise exception using errcode = 'P0001', message = 'si_income: Income Account is required';
  end if;
  select a.company_id, a.is_group into v_acc_company, v_group
    from public.account a
   where a.id = new.income_account_id and a.org_id = new.org_id;
  if v_acc_company is distinct from h.company_id or coalesce(v_group, true) then
    raise exception using errcode = 'P0001',
      message = 'si_income: Income Account must be a ledger of this company';
  end if;

  if new.cost_center_id is null then
    select d.selling_cost_center_id into new.cost_center_id
      from public.item_default d
     where d.parent_id = new.item_id
       and d.company_id = h.company_id
       and d.selling_cost_center_id is not null
     limit 1;
  end if;
  if new.cost_center_id is null then
    new.cost_center_id := h.cost_center_id;
  end if;
  if new.cost_center_id is null or not exists (
    select 1 from public.cost_center c
     where c.id = new.cost_center_id
       and c.org_id = new.org_id
       and c.company_id = h.company_id
       and not c.is_group
  ) then
    raise exception using errcode = 'P0001',
      message = 'si_cost_center: Cost Center must be a ledger of this company';
  end if;
  return new;
end;
$fn$;

create or replace function app.sales_invoice_item_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_parent uuid := case when tg_op = 'DELETE' then old.parent_id else new.parent_id end;
begin
  update public.sales_invoice q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.base_amt,
         outstanding_amount = case when q.docstatus = 0 then s.base_amt else q.outstanding_amount end
    from (
      select coalesce(sum(i.amount), 0) as amt,
             coalesce(sum(app.round(i.amount * q2.conversion_rate, 2)), 0) as base_amt
        from public.sales_invoice_item i
        join public.sales_invoice q2 on q2.id = i.parent_id
       where i.parent_id = v_parent
    ) s
   where q.id = v_parent;
  return null;
end;
$fn$;

create or replace function app.sales_invoice_gl_map(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  h public.sales_invoice;
  v_against text;
  v_rows jsonb := '[]'::jsonb;
  r record;
  v_idx int := 1;
begin
  select * into h from public.sales_invoice where id = p_id;
  if not found then
    return '[]'::jsonb;
  end if;
  select string_agg(a.name, ', ' order by i.idx) into v_against
    from public.sales_invoice_item i
    join public.account a on a.id = i.income_account_id
   where i.parent_id = h.id;

  v_rows := v_rows || jsonb_build_array(jsonb_build_object(
    'idx', 1,
    'org_id', h.org_id,
    'company_id', h.company_id,
    'posting_date', h.posting_date,
    'account_id', h.debit_to_id,
    'party_type', 'Customer',
    'party_id', h.customer_id,
    'cost_center_id', h.cost_center_id,
    'debit', h.base_grand_total,
    'credit', 0,
    'against', v_against,
    'against_voucher_type', 'Sales Invoice',
    'against_voucher_id', h.id,
    'voucher_type', 'Sales Invoice',
    'voucher_id', h.id,
    'voucher_no', h.name,
    'due_date', h.due_date,
    'is_opening', false,
    'is_advance', false
  ));

  for r in
    select i.id, i.income_account_id, i.cost_center_id,
           app.round(i.amount * h.conversion_rate, 2) as base_amount
      from public.sales_invoice_item i
     where i.parent_id = h.id
     order by i.idx
  loop
    v_idx := v_idx + 1;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'idx', v_idx,
      'org_id', h.org_id,
      'company_id', h.company_id,
      'posting_date', h.posting_date,
      'account_id', r.income_account_id,
      'cost_center_id', r.cost_center_id,
      'debit', 0,
      'credit', r.base_amount,
      'against', h.customer_name,
      'against_voucher_type', 'Sales Invoice',
      'against_voucher_id', h.id,
      'voucher_type', 'Sales Invoice',
      'voucher_id', h.id,
      'voucher_no', h.name,
      'voucher_detail_id', r.id,
      'due_date', h.due_date,
      'is_opening', false,
      'is_advance', false
    ));
  end loop;
  return v_rows;
end;
$fn$;

create or replace function app.on_submit__sales_invoice(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.sales_invoice;
  v_credits numeric;
  v_status text;
begin
  select * into h from public.sales_invoice where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Sales Invoice not found';
  end if;
  if not exists (select 1 from public.sales_invoice_item i where i.parent_id = p_id) then
    raise exception using errcode = 'P0001', message = 'si_items: Items table cannot be blank';
  end if;
  if h.debit_to_id is null then
    raise exception using errcode = 'P0001', message = 'si_receivable: Debit To must be a receivable ledger of this company';
  end if;
  if exists (
    select 1 from public.sales_invoice_item i
     where i.parent_id = p_id and i.income_account_id is null
  ) then
    raise exception using errcode = 'P0001', message = 'si_income: Income Account is required';
  end if;
  if coalesce(h.base_grand_total, 0) <= 0 then
    raise exception using errcode = 'P0001', message = 'si_total: Grand Total must be greater than zero';
  end if;
  select coalesce(sum(app.round(i.amount * h.conversion_rate, 2)), 0) into v_credits
    from public.sales_invoice_item i
   where i.parent_id = p_id;
  if v_credits <> h.base_grand_total then
    raise exception using errcode = 'P0001',
      message = 'si_totals: Item amounts do not match the grand total';
  end if;

  perform app.make_gl_entries(app.sales_invoice_gl_map(p_id), '{"merge": false}'::jsonb);

  v_status := case when h.due_date < current_date then 'Overdue' else 'Unpaid' end;
  update public.sales_invoice
     set status = v_status,
         outstanding_amount = h.base_grand_total
   where id = p_id;
end;
$fn$;

create or replace function app.on_cancel__sales_invoice(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  update public.sales_invoice set status = 'Cancelled' where id = p_id;
end;
$fn$;

revoke all on function app.sales_invoice_validate() from public, anon, authenticated;
revoke all on function app.sales_invoice_item_validate() from public, anon, authenticated;
revoke all on function app.sales_invoice_item_sync() from public, anon, authenticated;
revoke all on function app.sales_invoice_gl_map(uuid) from public, anon, authenticated;
revoke all on function app.on_submit__sales_invoice(uuid) from public, anon, authenticated;
revoke all on function app.on_cancel__sales_invoice(uuid) from public, anon, authenticated;

drop trigger if exists sales_invoice_validate on public.sales_invoice;
create trigger sales_invoice_validate before insert or update on public.sales_invoice
  for each row execute function app.sales_invoice_validate();
drop trigger if exists touch_updated on public.sales_invoice;
create trigger touch_updated before update on public.sales_invoice
  for each row execute function app.touch_updated();
drop trigger if exists sales_invoice_item_validate on public.sales_invoice_item;
create trigger sales_invoice_item_validate before insert or update on public.sales_invoice_item
  for each row execute function app.sales_invoice_item_validate();
drop trigger if exists sales_invoice_item_sync on public.sales_invoice_item;
create trigger sales_invoice_item_sync after insert or update or delete on public.sales_invoice_item
  for each row execute function app.sales_invoice_item_sync();

alter table public.sales_invoice enable row level security;
alter table public.sales_invoice force row level security;
alter table public.sales_invoice_item enable row level security;
alter table public.sales_invoice_item force row level security;

drop policy if exists sales_invoice_select on public.sales_invoice;
create policy sales_invoice_select on public.sales_invoice for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'read'))::uuid[]));
drop policy if exists sales_invoice_insert on public.sales_invoice;
create policy sales_invoice_insert on public.sales_invoice for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'create'))::uuid[]));
drop policy if exists sales_invoice_update on public.sales_invoice;
create policy sales_invoice_update on public.sales_invoice for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'write'))::uuid[]));
drop policy if exists sales_invoice_delete on public.sales_invoice;
create policy sales_invoice_delete on public.sales_invoice for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists sales_invoice_item_select on public.sales_invoice_item;
create policy sales_invoice_item_select on public.sales_invoice_item for select to authenticated
  using (exists (select 1 from public.sales_invoice p where p.id = parent_id));
drop policy if exists sales_invoice_item_insert on public.sales_invoice_item;
create policy sales_invoice_item_insert on public.sales_invoice_item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Sales Invoice', 'create'))::uuid[]));
drop policy if exists sales_invoice_item_update on public.sales_invoice_item;
create policy sales_invoice_item_update on public.sales_invoice_item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'write'))::uuid[]));
drop policy if exists sales_invoice_item_delete on public.sales_invoice_item;
create policy sales_invoice_item_delete on public.sales_invoice_item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Sales Invoice', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default, allow_on_submit
) values (
  'Sales Invoice', 'sales_invoice', 'accounts', true, 'customer_name', 'ACC-SINV-.YYYY.-', array[]::text[]
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default,
      allow_on_submit = excluded.allow_on_submit;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Sales Invoice Item', 'sales_invoice_item', 'accounts', true, 'Sales Invoice', 'items')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Sales Invoice', true, false, false, false, false, false, false),
  ('Accounts Manager', 'Sales Invoice', true, true, true, true, true, true, true),
  ('Accounts User', 'Sales Invoice', true, true, true, true, false, false, false),
  ('Sales User', 'Sales Invoice', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
