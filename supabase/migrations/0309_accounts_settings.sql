-- 0309 accounts: Accounts Settings, one row per organization.
-- ERPNext source: erpnext/accounts/doctype/accounts_settings/accounts_settings.json.
-- Exposed columns are the form (§6.1). Fixed columns keep their defaults and stay off the form.
-- Dropped columns are omitted. Posting and exchange rates do not read this row yet.

create table if not exists public.accounts_settings (
  id                                              uuid primary key default gen_random_uuid(),
  org_id                                          uuid not null unique references public.organizations (id) on delete cascade,
  unlink_payment_on_cancellation_of_invoice       boolean not null default true,
  unlink_advance_payment_on_cancelation_of_order  boolean not null default true,
  check_supplier_invoice_uniqueness               boolean not null default false,
  automatically_fetch_payment_terms               boolean not null default false,
  confirm_before_resetting_posting_date           boolean not null default true,
  over_billing_allowance                          numeric(21,9) not null default 0 check (over_billing_allowance >= 0),
  role_allowed_to_over_bill                       text,
  credit_controller                               text,
  enable_overdue_billing_threshold                boolean not null default false,
  role_allowed_to_bypass_overdue_billing          text,
  determine_address_tax_category_from             text not null default 'Billing Address'
    check (determine_address_tax_category_from in ('Billing Address', 'Shipping Address')),
  add_taxes_from_item_tax_template                boolean not null default true,
  add_taxes_from_taxes_and_charges_template       boolean not null default false,
  round_row_wise_tax                              boolean not null default false,
  merge_similar_account_heads                     boolean not null default false,
  show_balance_in_coa                             boolean not null default true,
  allow_stale                                     boolean not null default true,
  stale_days                                      int not null default 1 check (stale_days >= 0),
  transfer_match_days                             int not null default 3 check (transfer_match_days >= 0),
  ignore_is_opening_check_for_reporting           boolean not null default false,
  general_ledger_remarks_length                   int not null default 0 check (general_ledger_remarks_length >= 0),
  receivable_payable_remarks_length               int not null default 0 check (receivable_payable_remarks_length >= 0),
  default_ageing_range                            text not null default '30, 60, 90, 120' check (length(btrim(default_ageing_range)) > 0),
  show_inclusive_tax_in_print                     boolean not null default false,
  show_payment_schedule_in_print                  boolean not null default false,
  show_taxes_as_table_in_print                    boolean not null default false,
  book_asset_depreciation_entry_automatically     boolean not null default true,
  calculate_depr_using_total_days                 boolean not null default false,
  role_to_notify_on_depreciation_failure          text,
  delete_linked_ledger_entries                    boolean not null default false,
  enable_immutable_ledger                         boolean not null default false,
  enable_common_party_accounting                  boolean not null default false,
  book_tax_discount_loss                          boolean not null default false,
  make_payment_via_journal_entry                  boolean not null default false,
  exchange_gain_loss_posting_date                 text not null default 'Payment'
    check (exchange_gain_loss_posting_date in ('Invoice', 'Payment', 'Reconciliation Date')),
  auto_reconcile_payments                         boolean not null default false,
  enable_party_matching                           boolean not null default false,
  enable_fuzzy_matching                           boolean not null default false,
  ignore_account_closing_balance                  boolean not null default true,
  use_legacy_budget_controller                    boolean not null default false,
  enable_discounts_and_margin                     boolean not null default true,
  book_stock_expense_gl_entries                   boolean not null default false,
  created_at                                      timestamptz not null default now(),
  created_by                                      uuid default auth.uid(),
  updated_at                                      timestamptz not null default now(),
  updated_by                                      uuid,
  foreign key (org_id, role_allowed_to_over_bill) references public.roles (org_id, name)
    on update cascade on delete set null (role_allowed_to_over_bill),
  foreign key (org_id, credit_controller) references public.roles (org_id, name)
    on update cascade on delete set null (credit_controller),
  foreign key (org_id, role_allowed_to_bypass_overdue_billing) references public.roles (org_id, name)
    on update cascade on delete set null (role_allowed_to_bypass_overdue_billing),
  foreign key (org_id, role_to_notify_on_depreciation_failure) references public.roles (org_id, name)
    on update cascade on delete set null (role_to_notify_on_depreciation_failure)
);

create index if not exists accounts_settings_over_bill_role_idx
  on public.accounts_settings (org_id, role_allowed_to_over_bill);
create index if not exists accounts_settings_credit_controller_idx
  on public.accounts_settings (org_id, credit_controller);
create index if not exists accounts_settings_overdue_role_idx
  on public.accounts_settings (org_id, role_allowed_to_bypass_overdue_billing);
create index if not exists accounts_settings_depr_role_idx
  on public.accounts_settings (org_id, role_to_notify_on_depreciation_failure);

drop trigger if exists touch_updated on public.accounts_settings;
create trigger touch_updated before update on public.accounts_settings
  for each row execute function app.touch_updated();

create or replace function app.organizations_seed_accounts_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.accounts_settings (org_id) values (new.id) on conflict (org_id) do nothing;
  return null;
end;
$$;

revoke execute on function app.organizations_seed_accounts_settings() from public, anon, authenticated;

drop trigger if exists organizations_seed_accounts_settings on public.organizations;
create trigger organizations_seed_accounts_settings
  after insert on public.organizations
  for each row execute function app.organizations_seed_accounts_settings();

------------------------------------------------------------------------------------------------------------------------
-- RLS: read and write follow role_permissions. No insert or delete: the row is seeded.
------------------------------------------------------------------------------------------------------------------------

alter table public.accounts_settings enable row level security;
alter table public.accounts_settings force row level security;

drop policy if exists accounts_settings_select on public.accounts_settings;
create policy accounts_settings_select on public.accounts_settings for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Accounts Settings', 'read'))::uuid[]));
drop policy if exists accounts_settings_update on public.accounts_settings;
create policy accounts_settings_update on public.accounts_settings for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Accounts Settings', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Accounts Settings', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry. System Manager reads. Accounts Manager writes. Accounts, Sales, and Purchase users read.
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_single)
values ('Accounts Settings', 'accounts_settings', 'accounts', true)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_single = excluded.is_single;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Accounts Settings', true, false, false, false, false, false, false),
  ('Accounts Manager', 'Accounts Settings', true, true, false, false, false, false, false),
  ('Accounts User', 'Accounts Settings', true, false, false, false, false, false, false),
  ('Sales User', 'Accounts Settings', true, false, false, false, false, false, false),
  ('Purchase User', 'Accounts Settings', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();

insert into public.accounts_settings (org_id)
select o.id from public.organizations o
on conflict (org_id) do nothing;
