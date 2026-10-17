-- 0300 accounts: GL Entry and Payment Ledger Entry (docs/architecture/03-posting-engine.md, 01-accounts §2.24).
-- Append-only. The only in-place update is the cancel flag, and only from app.make_gl_entries / app.reverse_gl_entries.
-- ERPNext: erpnext/accounts/doctype/gl_entry, payment_ledger_entry.

create table if not exists public.gl_entry (
  id                              uuid primary key default gen_random_uuid(),
  org_id                          uuid not null references public.organizations (id) on delete cascade,
  company_id                      uuid not null,
  posting_date                    date not null,
  fiscal_year_id                  uuid,
  account_id                      uuid not null,
  party_type                      text,
  party_id                        uuid,
  cost_center_id                  uuid,
  project_id                      uuid,
  debit                           numeric(21,9) not null default 0,
  credit                          numeric(21,9) not null default 0,
  account_currency                text,
  debit_in_account_currency       numeric(21,9) not null default 0,
  credit_in_account_currency      numeric(21,9) not null default 0,
  against                         text,
  against_voucher_type            text,
  against_voucher_id              uuid,
  voucher_type                    text not null,
  voucher_id                      uuid not null,
  voucher_no                      text not null,
  voucher_detail_id               uuid,
  voucher_subtype                 text,
  remarks                         text,
  is_opening                      boolean not null default false,
  is_advance                      boolean not null default false,
  due_date                        date,
  is_cancelled                    boolean not null default false,
  transaction_currency            text,
  transaction_exchange_rate       numeric(21,9) not null default 1,
  debit_in_transaction_currency   numeric(21,9) not null default 0,
  credit_in_transaction_currency  numeric(21,9) not null default 0,
  advance_voucher_type            text,
  advance_voucher_id              uuid,
  is_system_generated             boolean not null default false,
  created_at                      timestamptz not null default now(),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  foreign key (org_id, fiscal_year_id) references public.fiscal_year (org_id, id),
  check (debit >= 0 and credit >= 0),
  check (party_type is null or party_type in ('Customer', 'Supplier'))
);

create index if not exists gl_entry_voucher_idx on public.gl_entry (org_id, voucher_type, voucher_id);
create index if not exists gl_entry_account_idx on public.gl_entry (org_id, account_id, posting_date);
create index if not exists gl_entry_company_idx on public.gl_entry (org_id, company_id, posting_date);
create index if not exists gl_entry_cost_center_idx on public.gl_entry (org_id, cost_center_id);
create index if not exists gl_entry_fiscal_year_idx on public.gl_entry (org_id, fiscal_year_id);

create table if not exists public.payment_ledger_entry (
  id                         uuid primary key default gen_random_uuid(),
  org_id                     uuid not null references public.organizations (id) on delete cascade,
  company_id                 uuid not null,
  posting_date               date not null,
  account_type               text not null check (account_type in ('Receivable', 'Payable')),
  account_id                 uuid not null,
  party_type                 text not null,
  party_id                   uuid not null,
  voucher_type               text not null,
  voucher_id                 uuid not null,
  voucher_no                 text,
  against_voucher_type       text,
  against_voucher_id         uuid,
  against_voucher_no         text,
  amount                     numeric(21,9) not null,
  account_currency           text,
  amount_in_account_currency numeric(21,9) not null,
  due_date                   date,
  cost_center_id             uuid,
  project_id                 uuid,
  delinked                   boolean not null default false,
  voucher_detail_id          uuid,
  remarks                    text,
  advance_voucher_type       text,
  advance_voucher_id         uuid,
  created_at                 timestamptz not null default now(),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  check (party_type in ('Customer', 'Supplier'))
);

create index if not exists ple_voucher_idx on public.payment_ledger_entry (org_id, voucher_type, voucher_id);
create index if not exists ple_against_idx on public.payment_ledger_entry (org_id, against_voucher_type, against_voucher_id);
create index if not exists ple_company_idx on public.payment_ledger_entry (org_id, company_id);
create index if not exists ple_account_idx on public.payment_ledger_entry (org_id, account_id);
create index if not exists ple_cost_center_idx on public.payment_ledger_entry (org_id, cost_center_id);

-- Reject every change except flipping the cancel flag on.
create or replace function app.gl_entry_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = 'P0001', message = 'ledger_append_only: General Ledger rows cannot be deleted';
  end if;
  if old.is_cancelled or not new.is_cancelled
     or (to_jsonb(new) - 'is_cancelled') is distinct from (to_jsonb(old) - 'is_cancelled') then
    raise exception using errcode = 'P0001', message = 'ledger_append_only: General Ledger rows cannot be changed';
  end if;
  return new;
end;
$$;

create or replace function app.payment_ledger_entry_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = 'P0001', message = 'ledger_append_only: Payment Ledger rows cannot be deleted';
  end if;
  if old.delinked or not new.delinked
     or (to_jsonb(new) - 'delinked') is distinct from (to_jsonb(old) - 'delinked') then
    raise exception using errcode = 'P0001', message = 'ledger_append_only: Payment Ledger rows cannot be changed';
  end if;
  return new;
end;
$$;

revoke execute on function app.gl_entry_guard(), app.payment_ledger_entry_guard() from public, anon, authenticated;

drop trigger if exists gl_entry_guard on public.gl_entry;
create trigger gl_entry_guard before update or delete on public.gl_entry
  for each row execute function app.gl_entry_guard();
drop trigger if exists payment_ledger_entry_guard on public.payment_ledger_entry;
create trigger payment_ledger_entry_guard before update or delete on public.payment_ledger_entry
  for each row execute function app.payment_ledger_entry_guard();

alter table public.gl_entry enable row level security;
alter table public.gl_entry force row level security;
alter table public.payment_ledger_entry enable row level security;
alter table public.payment_ledger_entry force row level security;

drop policy if exists gl_entry_select on public.gl_entry;
create policy gl_entry_select on public.gl_entry for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));
drop policy if exists payment_ledger_entry_select on public.payment_ledger_entry;
create policy payment_ledger_entry_select on public.payment_ledger_entry for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));
