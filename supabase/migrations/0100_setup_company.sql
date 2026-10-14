-- 0100 setup: Company -> public.companies (tree master, naming = company_name).
-- Spec: docs/modules/00-setup.md §2.1. Sources: erpnext/setup/doctype/company/company.json, company.py
-- (validate_abbr, validate_coa_input, set_chart_of_accounts, validate_parent_company, set_reporting_currency,
-- validate_sdbnb_configuration), test_company.py.
-- Links to tables that do not exist yet (account, cost_center, warehouse, letter_head, holiday_list, contact,
-- terms_and_conditions, payment_terms_template, finance_book) are plain uuid columns; their FKs and the
-- corresponding validations (validate_default_accounts, validate_warehouses, ...) are added by the migrations
-- that create those tables.

create table if not exists public.companies (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations (id) on delete cascade,
  name                   text not null,
  company_name           text not null check (length(trim(company_name)) > 0),
  abbr                   text not null,
  disabled               boolean not null default false,

  -- tree
  is_group               boolean not null default false,
  parent_id              uuid,
  path                   extensions.ltree not null,

  -- Details
  default_currency       text not null,
  reporting_currency     text,
  country                text not null,
  create_chart_of_accounts_based_on text not null default 'Standard Template'
    check (create_chart_of_accounts_based_on in ('Standard Template', 'Existing Company')),
  chart_of_accounts      text,
  existing_company_id    uuid,
  domain                 text,
  company_logo           text,
  company_description    text,
  tax_id                 text,
  phone_no               text,
  fax                    text,
  email                  text,
  website                text,
  date_of_establishment  date,
  date_of_incorporation  date,
  date_of_commencement   date,
  registration_details   text,
  default_letter_head_id uuid,
  default_holiday_list_id uuid,
  default_finance_book_id uuid,

  -- Accounts
  default_bank_account_id               uuid,
  default_cash_account_id               uuid,
  default_receivable_account_id         uuid,
  default_payable_account_id            uuid,
  default_expense_account_id            uuid,
  default_income_account_id             uuid,
  round_off_account_id                  uuid,
  round_off_cost_center_id              uuid,
  round_off_for_opening_id              uuid,
  write_off_account_id                  uuid,
  bank_charges_account_id               uuid,
  exchange_gain_loss_account_id         uuid,
  exchange_gain_account_id              uuid,
  exchange_loss_account_id              uuid,
  unrealized_exchange_gain_loss_account_id uuid,
  unrealized_profit_loss_account_id     uuid,
  default_discount_account_id           uuid,
  default_advance_received_account_id   uuid,
  default_advance_paid_account_id       uuid,
  book_advance_payments_in_separate_party_account boolean not null default false,
  default_deferred_revenue_account_id   uuid,
  default_deferred_expense_account_id   uuid,
  allow_account_creation_against_child_company boolean not null default false,
  cost_center_id                        uuid,
  credit_limit                          numeric(21, 9) not null default 0,
  payment_terms_id                      uuid,
  accounts_frozen_till_date             date,
  role_allowed_for_frozen_entries       text,
  reconciliation_takes_effect_on        text not null default 'Oldest Of Invoice Or Advance'
    check (reconciliation_takes_effect_on in ('Advance Payment Date', 'Oldest Of Invoice Or Advance', 'Reconciliation Date')),
  auto_exchange_rate_revaluation        boolean not null default false,
  auto_err_frequency                    text check (auto_err_frequency in ('Daily', 'Weekly', 'Monthly')),
  submit_err_jv                         boolean not null default false,
  exception_budget_approver_role        text,

  -- Assets (Accounts tab)
  accumulated_depreciation_account_id   uuid,
  depreciation_expense_account_id       uuid,
  series_for_depreciation_entry         text,
  disposal_account_id                   uuid,
  depreciation_cost_center_id           uuid,
  capital_work_in_progress_account_id   uuid,
  asset_received_but_not_billed_id      uuid,

  -- Buying and Selling
  default_selling_terms_id              uuid,
  default_buying_terms_id               uuid,
  default_warehouse_for_sales_return_id uuid,
  default_sales_contact_id              uuid,

  -- Dashboard
  monthly_sales_target                  numeric(21, 9) not null default 0,
  total_monthly_sales                   numeric(21, 9) not null default 0,
  sales_monthly_history                 jsonb,
  transactions_annual_history           jsonb,

  -- Stock and Manufacturing
  enable_perpetual_inventory            boolean not null default true,
  enable_item_wise_inventory_account    boolean not null default false,
  default_inventory_account_id          uuid,
  stock_adjustment_account_id           uuid,
  stock_received_but_not_billed_id      uuid,
  stock_delivered_but_not_billed_id     uuid,
  enable_stock_delivered_but_not_billed boolean not null default false,
  disable_sdbnb_in_sr                   boolean not null default false,
  default_purchase_price_variance_account_id uuid,
  default_manufacturing_variance_account_id  uuid,
  purchase_expense_account_id           uuid,
  purchase_expense_contra_account_id    uuid,
  service_expense_account_id            uuid,
  expenses_added_to_stock_account_id    uuid,
  expenses_added_to_stock_contra_account_id uuid,
  enable_provisional_accounting_for_non_stock_items boolean not null default false,
  default_provisional_account_id        uuid,
  default_operating_cost_account_id     uuid,
  valuation_method                      text not null default 'FIFO'
    check (valuation_method in ('FIFO', 'Moving Average', 'LIFO')),
  default_warehouse_id                  uuid,
  default_in_transit_warehouse_id       uuid,
  default_wip_warehouse_id              uuid,
  default_fg_warehouse_id               uuid,
  default_scrap_warehouse_id            uuid,
  sample_retention_warehouse_id         uuid,

  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,

  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, parent_id) references public.companies (org_id, id) on delete restrict,
  foreign key (org_id, existing_company_id) references public.companies (org_id, id) on delete set null (existing_company_id),
  foreign key (org_id, role_allowed_for_frozen_entries) references public.roles (org_id, name) on update cascade on delete set null (role_allowed_for_frozen_entries),
  foreign key (org_id, exception_budget_approver_role) references public.roles (org_id, name) on update cascade on delete set null (exception_budget_approver_role)
);

create unique index if not exists companies_abbr_uniq on public.companies (org_id, lower(abbr));
create index if not exists companies_parent_idx on public.companies (org_id, parent_id);
create index if not exists companies_path_idx on public.companies using gist (path);

------------------------------------------------------------------------------------------------------------------------
-- Validations (company.py: validate)
------------------------------------------------------------------------------------------------------------------------

-- Security definer so uniqueness/parent lookups see companies hidden from the caller by user permissions.
create or replace function app.companies_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.organizations;
  v_parent_reporting text;
begin
  new.company_name := trim(new.company_name);
  new.name := new.company_name;

  -- defaults from the organization (setup wizard passes them explicitly)
  if new.default_currency is null or new.country is null then
    select * into v_org from public.organizations where id = new.org_id;
    new.default_currency := coalesce(new.default_currency, v_org.default_currency);
    new.country := coalesce(new.country, v_org.country);
  end if;

  -- validate_abbr
  if new.abbr is null or trim(new.abbr) = '' then
    new.abbr := upper(array_to_string(array(
      select left(w, 1) from regexp_split_to_table(new.company_name, '\s+') w where w <> ''), ''));
  end if;
  new.abbr := trim(new.abbr);
  if new.abbr = '' then
    raise exception using errcode = 'P0001', message = 'abbr_required: Abbreviation is mandatory';
  end if;
  if exists (select 1 from public.companies c
             where c.org_id = new.org_id and lower(c.abbr) = lower(new.abbr) and c.id <> new.id) then
    raise exception using errcode = 'P0001', message = 'abbr_taken: Abbreviation already used for another company';
  end if;

  -- set_chart_of_accounts: a parent company forces the parent's chart
  if new.parent_id is not null then
    new.create_chart_of_accounts_based_on := 'Existing Company';
    new.existing_company_id := new.parent_id;
  end if;

  -- validate_coa_input
  if new.create_chart_of_accounts_based_on = 'Existing Company' then
    new.chart_of_accounts := null;
    if new.existing_company_id is null then
      raise exception using errcode = 'P0001', message = 'coa_input: Please select Existing Company for creating Chart of Accounts';
    end if;
  else
    new.existing_company_id := null;
    new.chart_of_accounts := coalesce(nullif(new.chart_of_accounts, ''), 'Standard');
  end if;

  -- set_reporting_currency (validate_parent_company is enforced by app.tree_maintain_path)
  new.reporting_currency := new.default_currency;
  if new.parent_id is not null then
    select c.reporting_currency into v_parent_reporting from public.companies c where c.id = new.parent_id;
    new.reporting_currency := coalesce(v_parent_reporting, new.default_currency);
  end if;

  -- validate_sdbnb_configuration (skipped for new documents, as in ERPNext)
  if tg_op = 'UPDATE' and new.enable_stock_delivered_but_not_billed and new.stock_delivered_but_not_billed_id is null then
    raise exception using errcode = 'P0001', message = 'sdbnb_account_required: Please select Stock Delivered But Not Billed Account';
  end if;

  return new;
end;
$$;

revoke execute on function app.companies_validate() from public, anon, authenticated;

drop trigger if exists companies_validate on public.companies;
create trigger companies_validate
  before insert or update on public.companies
  for each row execute function app.companies_validate();

drop trigger if exists tree_path on public.companies;
create trigger tree_path
  before insert or update on public.companies
  for each row execute function app.tree_maintain_path('Company');

drop trigger if exists tree_path_descendants on public.companies;
create trigger tree_path_descendants
  after update on public.companies
  for each row execute function app.tree_update_descendants();

drop trigger if exists touch_updated on public.companies;
create trigger touch_updated
  before update on public.companies
  for each row execute function app.touch_updated();

------------------------------------------------------------------------------------------------------------------------
-- RLS (template from docs/architecture/01-tenancy-auth-rls.md; Company is restricted by User Permission on itself)
------------------------------------------------------------------------------------------------------------------------

alter table public.companies enable row level security;
alter table public.companies force row level security;

drop policy if exists companies_select on public.companies;
create policy companies_select on public.companies for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Company', 'read'))::uuid[]) and app.company_allowed(org_id, id));
drop policy if exists companies_insert on public.companies;
create policy companies_insert on public.companies for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Company', 'create'))::uuid[]));
drop policy if exists companies_update on public.companies;
create policy companies_update on public.companies for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Company', 'write'))::uuid[]) and app.company_allowed(org_id, id))
  with check (org_id = any ((select app.orgs_with_perm('Company', 'write'))::uuid[]) and app.company_allowed(org_id, id));
drop policy if exists companies_delete on public.companies;
create policy companies_delete on public.companies for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Company', 'delete'))::uuid[]) and app.company_allowed(org_id, id));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (company.json permissions; HR/Employee rows dropped per 00-setup.md §2.1)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field, user_permission_target)
values ('Company', 'companies', 'setup', true, 'company_name', true)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field, user_permission_target = excluded.user_permission_target;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager',   'Company', true, true,  true,  true),
  ('Accounts Manager', 'Company', true, true,  true,  true),
  ('Accounts User',    'Company', true, false, false, false),
  ('Sales Manager',    'Company', true, false, false, false),
  ('Sales User',       'Company', true, false, false, false),
  ('Purchase User',    'Company', true, false, false, false),
  ('Stock User',       'Company', true, false, false, false),
  ('Projects User',    'Company', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
