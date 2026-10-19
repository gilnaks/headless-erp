-- 0307 accounts: Payment Entry (docs/modules/01-accounts.md §2.17, §3.7, §4.2).
-- ERPNext: erpnext/accounts/doctype/payment_entry/payment_entry.py,
-- payment_entry/services/payment_entry_gl_composer.py (merge stays off so party rows keep their against-voucher).
-- Advance taxes, bank-account masters, TDS and book_advance_payments_in_separate_party_account are not built.
-- party_id is a uuid with no foreign key, same as Journal Entry. Exchange rates stay 1.
-- Outstanding references are Journal Entry party rows until invoices and orders exist.

create table if not exists public.payment_entry (
  id                            uuid primary key default gen_random_uuid(),
  org_id                        uuid not null references public.organizations (id) on delete cascade,
  name                          text not null,
  title                         text,
  naming_series                 text not null default 'ACC-PAY-.YYYY.-',
  payment_type                  text not null default 'Receive'
                                  check (payment_type in ('Receive', 'Pay', 'Internal Transfer')),
  status                        text not null default 'Draft' check (status in ('Draft', 'Submitted', 'Cancelled')),
  docstatus                     smallint not null default 0 check (docstatus in (0, 1, 2)),
  company_id                    uuid not null,
  posting_date                  date not null default current_date,
  party_type                    text check (party_type is null or party_type in ('Customer', 'Supplier')),
  party_id                      uuid,
  party_name                    text,
  contact_person_id             uuid,
  contact_email                 text,
  mode_of_payment_id            uuid,
  party_balance                 numeric(21,9) not null default 0,
  paid_from_account_id          uuid not null,
  paid_from_account_type        text,
  paid_from_account_currency    text,
  paid_from_account_balance     numeric(21,9) not null default 0,
  paid_to_account_id            uuid not null,
  paid_to_account_type          text,
  paid_to_account_currency      text,
  paid_to_account_balance       numeric(21,9) not null default 0,
  paid_amount                   numeric(21,9) not null default 0,
  source_exchange_rate          numeric(21,9) not null default 1,
  base_paid_amount              numeric(21,9) not null default 0,
  received_amount               numeric(21,9) not null default 0,
  target_exchange_rate          numeric(21,9) not null default 1,
  base_received_amount          numeric(21,9) not null default 0,
  total_allocated_amount        numeric(21,9) not null default 0,
  base_total_allocated_amount   numeric(21,9) not null default 0,
  unallocated_amount            numeric(21,9) not null default 0,
  difference_amount             numeric(21,9) not null default 0,
  reference_no                  text,
  reference_date                date,
  clearance_date                date,
  cost_center_id                uuid,
  remarks                       text,
  custom_remarks                boolean not null default false,
  is_opening                    text not null default 'No' check (is_opening in ('No', 'Yes')),
  amended_from                  uuid,
  created_at                    timestamptz not null default now(),
  created_by                    uuid default auth.uid(),
  updated_at                    timestamptz not null default now(),
  updated_by                    uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, mode_of_payment_id) references public.mode_of_payment (org_id, id),
  foreign key (org_id, contact_person_id) references public.contact (org_id, id),
  foreign key (org_id, paid_from_account_id) references public.account (org_id, id),
  foreign key (org_id, paid_to_account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  foreign key (org_id, amended_from) references public.payment_entry (org_id, id) on delete set null (amended_from)
);

create index if not exists payment_entry_posting_idx on public.payment_entry (org_id, posting_date);
create index if not exists payment_entry_party_idx on public.payment_entry (org_id, party_type, party_id);
create index if not exists payment_entry_company_idx on public.payment_entry (org_id, company_id);
create index if not exists payment_entry_mode_of_payment_idx on public.payment_entry (org_id, mode_of_payment_id);
create index if not exists payment_entry_contact_idx on public.payment_entry (org_id, contact_person_id);
create index if not exists payment_entry_paid_from_idx on public.payment_entry (org_id, paid_from_account_id);
create index if not exists payment_entry_paid_to_idx on public.payment_entry (org_id, paid_to_account_id);
create index if not exists payment_entry_cost_center_idx on public.payment_entry (org_id, cost_center_id);
create index if not exists payment_entry_amended_idx on public.payment_entry (org_id, amended_from);

create table if not exists public.payment_entry_reference (
  id                        uuid primary key default gen_random_uuid(),
  org_id                    uuid not null,
  parent_id                 uuid not null,
  idx                       int not null,
  reference_doctype         text not null check (reference_doctype in (
                              'Sales Invoice', 'Purchase Invoice', 'Journal Entry', 'Sales Order', 'Purchase Order', 'Payment Entry'
                            )),
  reference_id              uuid not null,
  due_date                  date,
  bill_no                   text,
  payment_term_id           uuid,
  payment_term_outstanding  numeric(21,9) not null default 0,
  account_type              text,
  payment_type              text,
  total_amount              numeric(21,9) not null default 0,
  outstanding_amount        numeric(21,9) not null default 0,
  allocated_amount          numeric(21,9) not null default 0,
  exchange_rate             numeric(21,9) not null default 1,
  exchange_gain_loss        numeric(21,9) not null default 0,
  account_id                uuid,
  advance_voucher_type      text,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.payment_entry (org_id, id) on delete cascade,
  foreign key (org_id, account_id) references public.account (org_id, id),
  foreign key (org_id, payment_term_id) references public.payment_term (org_id, id)
);

create index if not exists payment_entry_reference_parent_idx on public.payment_entry_reference (org_id, parent_id);
create index if not exists payment_entry_reference_account_idx on public.payment_entry_reference (org_id, account_id);
create index if not exists payment_entry_reference_term_idx on public.payment_entry_reference (org_id, payment_term_id);

create table if not exists public.payment_entry_deduction (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null,
  parent_id             uuid not null,
  idx                   int not null,
  account_id            uuid not null,
  cost_center_id        uuid not null,
  amount                numeric(21,9) not null default 0,
  is_exchange_gain_loss boolean not null default false,
  description           text,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.payment_entry (org_id, id) on delete cascade,
  foreign key (org_id, account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id)
);

create index if not exists payment_entry_deduction_parent_idx on public.payment_entry_deduction (org_id, parent_id);
create index if not exists payment_entry_deduction_account_idx on public.payment_entry_deduction (org_id, account_id);
create index if not exists payment_entry_deduction_cost_center_idx on public.payment_entry_deduction (org_id, cost_center_id);

create or replace function app.payment_entry_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_from record;
  v_to record;
  v_allocated numeric;
  v_deductions numeric;
  v_party_account uuid;
  v_currency text;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
  end if;
  if new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'ACC-PAY-.YYYY.-';
  end if;
  if new.posting_date is null then
    new.posting_date := current_date;
  end if;
  if new.is_opening is null then
    new.is_opening := 'No';
  end if;
  if new.amended_from is not null and tg_op = 'INSERT' then
    new.clearance_date := null;
    new.docstatus := 0;
  end if;
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;

  new.paid_amount := coalesce(new.paid_amount, 0);
  if new.received_amount is null then
    new.received_amount := new.paid_amount;
  end if;
  new.received_amount := coalesce(new.received_amount, 0);
  new.source_exchange_rate := 1;
  new.target_exchange_rate := 1;
  new.party_balance := coalesce(new.party_balance, 0);
  new.paid_from_account_balance := coalesce(new.paid_from_account_balance, 0);
  new.paid_to_account_balance := coalesce(new.paid_to_account_balance, 0);
  new.total_allocated_amount := coalesce(new.total_allocated_amount, 0);
  new.base_total_allocated_amount := coalesce(new.base_total_allocated_amount, 0);
  new.unallocated_amount := coalesce(new.unallocated_amount, 0);
  new.difference_amount := coalesce(new.difference_amount, 0);

  if new.payment_type = 'Internal Transfer' then
    new.party_type := null;
    new.party_id := null;
    new.party_name := null;
  elsif new.party_type = 'Customer' and new.party_id is not null then
    select c.customer_name into new.party_name
      from public.customer c
     where c.id = new.party_id and c.org_id = new.org_id;
  elsif new.party_type = 'Supplier' and new.party_id is not null then
    select s.supplier_name into new.party_name
      from public.supplier s
     where s.id = new.party_id and s.org_id = new.org_id;
  end if;

  if new.paid_from_account_id is null and new.payment_type = 'Receive' and new.party_id is not null then
    new.paid_from_account_id := app.get_party_account(new.party_type, new.party_id, new.company_id);
  elsif new.paid_from_account_id is null and new.payment_type in ('Pay', 'Internal Transfer') then
    select coalesce(
             (select m.default_account_id from public.mode_of_payment_account m
               where m.parent_id = new.mode_of_payment_id and m.company_id = new.company_id and m.default_account_id is not null
               limit 1),
             c.default_bank_account_id,
             c.default_cash_account_id
           )
      into new.paid_from_account_id
      from public.companies c
     where c.id = new.company_id;
  end if;

  if new.paid_to_account_id is null and new.payment_type = 'Pay' and new.party_id is not null then
    new.paid_to_account_id := app.get_party_account(new.party_type, new.party_id, new.company_id);
  elsif new.paid_to_account_id is null and new.payment_type in ('Receive', 'Internal Transfer') then
    select coalesce(
             (select m.default_account_id from public.mode_of_payment_account m
               where m.parent_id = new.mode_of_payment_id and m.company_id = new.company_id and m.default_account_id is not null
               limit 1),
             c.default_bank_account_id,
             c.default_cash_account_id
           )
      into new.paid_to_account_id
      from public.companies c
     where c.id = new.company_id;
  end if;

  if new.paid_from_account_id is null or new.paid_to_account_id is null then
    raise exception using errcode = 'P0001', message = 'pe_accounts: Paid From and Paid To are required';
  end if;

  select a.name, a.account_type, a.account_currency, a.company_id
    into v_from
    from public.account a
   where a.id = new.paid_from_account_id and a.org_id = new.org_id;
  if not found or v_from.company_id is distinct from new.company_id then
    raise exception using errcode = 'P0001', message = 'pe_accounts: Paid From does not belong to the company';
  end if;
  select a.name, a.account_type, a.account_currency, a.company_id
    into v_to
    from public.account a
   where a.id = new.paid_to_account_id and a.org_id = new.org_id;
  if not found or v_to.company_id is distinct from new.company_id then
    raise exception using errcode = 'P0001', message = 'pe_accounts: Paid To does not belong to the company';
  end if;
  new.paid_from_account_type := v_from.account_type;
  new.paid_from_account_currency := v_from.account_currency;
  new.paid_to_account_type := v_to.account_type;
  new.paid_to_account_currency := v_to.account_currency;

  if new.cost_center_id is null then
    select c.cost_center_id into new.cost_center_id from public.companies c where c.id = new.company_id;
  end if;

  select coalesce(abs(sum(r.allocated_amount)), 0) into v_allocated
    from public.payment_entry_reference r
   where r.parent_id = new.id;
  select coalesce(sum(d.amount), 0) into v_deductions
    from public.payment_entry_deduction d
   where d.parent_id = new.id;

  new.base_paid_amount := app.round(new.paid_amount, 2);
  new.base_received_amount := app.round(new.received_amount, 2);
  new.total_allocated_amount := app.round(v_allocated, 2);
  new.base_total_allocated_amount := new.total_allocated_amount;

  if new.party_id is null then
    new.unallocated_amount := 0;
  elsif new.payment_type = 'Receive' and new.base_total_allocated_amount < new.base_paid_amount + v_deductions then
    new.unallocated_amount := app.round(new.base_paid_amount + v_deductions - new.base_total_allocated_amount, 2);
  elsif new.payment_type = 'Pay' and new.base_total_allocated_amount < new.base_received_amount - v_deductions then
    new.unallocated_amount := app.round(new.base_received_amount - v_deductions - new.base_total_allocated_amount, 2);
  else
    new.unallocated_amount := 0;
  end if;

  new.difference_amount := app.round(case new.payment_type
    when 'Receive' then (new.base_total_allocated_amount + new.unallocated_amount) - new.base_received_amount - v_deductions
    when 'Pay' then new.base_paid_amount - (new.base_total_allocated_amount + new.unallocated_amount) - v_deductions
    else new.base_paid_amount - new.base_received_amount - v_deductions
  end, 2);

  v_party_account := case
    when new.payment_type = 'Pay' then new.paid_to_account_id
    else new.paid_from_account_id
  end;
  if new.party_id is not null and v_party_account is not null then
    select coalesce(sum(p.amount), 0) into new.party_balance
      from public.payment_ledger_entry p
     where p.company_id = new.company_id
       and p.party_type = new.party_type
       and p.party_id = new.party_id
       and p.account_id = v_party_account
       and not p.delinked;
  else
    new.party_balance := 0;
  end if;

  new.paid_from_account_balance := coalesce((
    select sum(g.debit - g.credit) from public.gl_entry g
     where g.account_id = new.paid_from_account_id and not g.is_cancelled
  ), 0);
  new.paid_to_account_balance := coalesce((
    select sum(g.debit - g.credit) from public.gl_entry g
     where g.account_id = new.paid_to_account_id and not g.is_cancelled
  ), 0);

  if new.payment_type = 'Internal Transfer' then
    new.title := v_from.name || ' → ' || v_to.name;
  else
    new.title := coalesce(new.party_name, new.name);
  end if;

  if not new.custom_remarks then
    select c.default_currency into v_currency from public.companies c where c.id = new.company_id;
    new.remarks := format(
      'Amount %s %s %s %s',
      coalesce(v_currency, ''),
      case when new.payment_type = 'Pay' then new.base_paid_amount else new.base_received_amount end,
      case when new.payment_type = 'Pay' then 'paid to' else 'received from' end,
      coalesce(new.party_name, new.title, '')
    );
    if nullif(btrim(new.reference_no), '') is not null then
      new.remarks := new.remarks || format(
        E'\nTransaction reference no %s dated %s',
        btrim(new.reference_no),
        coalesce(new.reference_date::text, '')
      );
    end if;
  end if;

  new.status := case new.docstatus when 1 then 'Submitted' when 2 then 'Cancelled' else 'Draft' end;
  return new;
end;
$$;

create or replace function app.payment_entry_reference_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_header public.payment_entry;
  v_account record;
begin
  select * into v_header from public.payment_entry where id = new.parent_id;
  new.org_id := v_header.org_id;
  new.exchange_rate := 1;
  new.exchange_gain_loss := 0;
  new.allocated_amount := coalesce(new.allocated_amount, 0);
  new.total_amount := coalesce(new.total_amount, 0);
  new.outstanding_amount := coalesce(new.outstanding_amount, 0);
  new.payment_term_outstanding := coalesce(new.payment_term_outstanding, 0);
  new.payment_type := v_header.payment_type;
  if new.account_id is null then
    new.account_id := case
      when v_header.payment_type = 'Pay' then v_header.paid_to_account_id
      else v_header.paid_from_account_id
    end;
  end if;
  if new.account_id is not null then
    select a.account_type, a.company_id into v_account
      from public.account a
     where a.id = new.account_id and a.org_id = new.org_id;
    if v_account.company_id is distinct from v_header.company_id then
      raise exception using errcode = 'P0001',
        message = format('pe_reference: Row %s: Account does not belong to the company', new.idx);
    end if;
    new.account_type := v_account.account_type;
  end if;
  return new;
end;
$$;

create or replace function app.payment_entry_deduction_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_header public.payment_entry;
  v_company uuid;
begin
  select * into v_header from public.payment_entry where id = new.parent_id;
  new.org_id := v_header.org_id;
  new.amount := coalesce(new.amount, 0);
  new.is_exchange_gain_loss := false;
  if new.cost_center_id is null then
    new.cost_center_id := v_header.cost_center_id;
  end if;
  if new.cost_center_id is null then
    select c.cost_center_id into new.cost_center_id
      from public.companies c
     where c.id = v_header.company_id;
  end if;
  select a.company_id into v_company from public.account a where a.id = new.account_id and a.org_id = new.org_id;
  if v_company is distinct from v_header.company_id then
    raise exception using errcode = 'P0001',
      message = format('pe_deduction: Row %s: Account does not belong to the company', new.idx);
  end if;
  return new;
end;
$$;

create or replace function app.payment_entry_refresh()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent uuid := coalesce(new.parent_id, old.parent_id);
begin
  if pg_trigger_depth() > 1 then
    return null;
  end if;
  update public.payment_entry set updated_at = updated_at where id = v_parent;
  return null;
end;
$$;

create or replace function app.payment_entry_gl_map(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  h public.payment_entry;
  v_rows jsonb := '[]'::jsonb;
  v_party_account uuid;
  v_from_name text;
  v_to_name text;
  r record;
begin
  select * into h from public.payment_entry where id = p_id;
  if not found then
    return '[]'::jsonb;
  end if;
  select a.name into v_from_name from public.account a where a.id = h.paid_from_account_id;
  select a.name into v_to_name from public.account a where a.id = h.paid_to_account_id;
  v_party_account := case when h.payment_type = 'Pay' then h.paid_to_account_id else h.paid_from_account_id end;

  if h.payment_type in ('Receive', 'Pay') then
    for r in
      select * from public.payment_entry_reference
       where parent_id = h.id and allocated_amount <> 0
       order by idx
    loop
      v_rows := v_rows || jsonb_build_array(jsonb_build_object(
        'org_id', h.org_id,
        'company_id', h.company_id,
        'posting_date', h.posting_date,
        'account_id', v_party_account,
        'party_type', h.party_type,
        'party_id', h.party_id,
        'cost_center_id', h.cost_center_id,
        'debit', case when h.payment_type = 'Pay' then r.allocated_amount else 0 end,
        'credit', case when h.payment_type = 'Receive' then r.allocated_amount else 0 end,
        'against', case when h.payment_type = 'Receive' then v_to_name else v_from_name end,
        'against_voucher_type', r.reference_doctype,
        'against_voucher_id', r.reference_id,
        'voucher_type', 'Payment Entry',
        'voucher_id', h.id,
        'voucher_no', h.name,
        'voucher_detail_id', r.id,
        'voucher_subtype', h.payment_type,
        'remarks', h.remarks,
        'is_opening', h.is_opening = 'Yes',
        'is_advance', false,
        'due_date', r.due_date
      ));
    end loop;

    if h.unallocated_amount <> 0 then
      v_rows := v_rows || jsonb_build_array(jsonb_build_object(
        'org_id', h.org_id,
        'company_id', h.company_id,
        'posting_date', h.posting_date,
        'account_id', v_party_account,
        'party_type', h.party_type,
        'party_id', h.party_id,
        'cost_center_id', h.cost_center_id,
        'debit', case when h.payment_type = 'Pay' then h.unallocated_amount else 0 end,
        'credit', case when h.payment_type = 'Receive' then h.unallocated_amount else 0 end,
        'against', case when h.payment_type = 'Receive' then v_to_name else v_from_name end,
        'voucher_type', 'Payment Entry',
        'voucher_id', h.id,
        'voucher_no', h.name,
        'voucher_subtype', h.payment_type,
        'remarks', h.remarks,
        'is_opening', h.is_opening = 'Yes',
        'is_advance', true
      ));
    end if;
  end if;

  if h.payment_type in ('Receive', 'Internal Transfer') and h.base_received_amount <> 0 then
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'org_id', h.org_id,
      'company_id', h.company_id,
      'posting_date', h.posting_date,
      'account_id', h.paid_to_account_id,
      'cost_center_id', h.cost_center_id,
      'debit', h.base_received_amount,
      'credit', 0,
      'against', coalesce(h.party_name, v_from_name),
      'voucher_type', 'Payment Entry',
      'voucher_id', h.id,
      'voucher_no', h.name,
      'voucher_subtype', h.payment_type,
      'remarks', h.remarks,
      'is_opening', h.is_opening = 'Yes',
      'is_advance', false
    ));
  end if;

  if h.payment_type in ('Pay', 'Internal Transfer') and h.base_paid_amount <> 0 then
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'org_id', h.org_id,
      'company_id', h.company_id,
      'posting_date', h.posting_date,
      'account_id', h.paid_from_account_id,
      'cost_center_id', h.cost_center_id,
      'debit', 0,
      'credit', h.base_paid_amount,
      'against', coalesce(h.party_name, v_to_name),
      'voucher_type', 'Payment Entry',
      'voucher_id', h.id,
      'voucher_no', h.name,
      'voucher_subtype', h.payment_type,
      'remarks', h.remarks,
      'is_opening', h.is_opening = 'Yes',
      'is_advance', false
    ));
  end if;

  for r in
    select * from public.payment_entry_deduction
     where parent_id = h.id and amount <> 0
     order by idx
  loop
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'org_id', h.org_id,
      'company_id', h.company_id,
      'posting_date', h.posting_date,
      'account_id', r.account_id,
      'cost_center_id', r.cost_center_id,
      'debit', case when r.amount > 0 then r.amount else 0 end,
      'credit', case when r.amount < 0 then abs(r.amount) else 0 end,
      'against', coalesce(h.party_name, h.title),
      'voucher_type', 'Payment Entry',
      'voucher_id', h.id,
      'voucher_no', h.name,
      'voucher_detail_id', r.id,
      'voucher_subtype', h.payment_type,
      'remarks', coalesce(r.description, h.remarks),
      'is_opening', h.is_opening = 'Yes',
      'is_advance', false
    ));
  end loop;

  return v_rows;
end;
$$;

create or replace function app.on_submit__payment_entry(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.payment_entry;
  v_from record;
  v_to record;
  r record;
  v_status int;
  v_name text;
  v_outstanding numeric;
  v_party_account uuid;
  v_seen int;
begin
  select * into h from public.payment_entry where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Payment Entry not found';
  end if;

  if h.payment_type <> 'Internal Transfer' and (h.party_type is null or h.party_id is null) then
    raise exception using errcode = 'P0001',
      message = format('pe_party: Party Type and Party is mandatory for %s payment', h.payment_type);
  end if;
  if h.payment_type = 'Internal Transfer' and exists (
    select 1 from public.payment_entry_reference where parent_id = p_id
  ) then
    raise exception using errcode = 'P0001', message = 'pe_references: Internal Transfer cannot have references';
  end if;

  if h.party_type = 'Customer' and not exists (
    select 1 from public.customer c where c.id = h.party_id and c.org_id = h.org_id
  ) then
    raise exception using errcode = 'P0001', message = 'pe_party: Customer was not found';
  end if;
  if h.party_type = 'Supplier' then
    select s.supplier_name into v_name from public.supplier s where s.id = h.party_id and s.org_id = h.org_id;
    if v_name is null then
      raise exception using errcode = 'P0001', message = 'pe_party: Supplier was not found';
    end if;
    if exists (
      select 1 from public.supplier s
       where s.id = h.party_id and s.on_hold and s.hold_type in ('All', 'Payments')
    ) then
      raise exception using errcode = 'P0001', message = format('pe_supplier_hold: Supplier %s is on hold', v_name);
    end if;
  end if;

  select a.name, a.account_type, a.is_group, a.disabled, a.company_id
    into v_from
    from public.account a
   where a.id = h.paid_from_account_id;
  select a.name, a.account_type, a.is_group, a.disabled, a.company_id
    into v_to
    from public.account a
   where a.id = h.paid_to_account_id;
  if v_from.is_group or v_from.disabled or v_to.is_group or v_to.disabled then
    raise exception using errcode = 'P0001', message = 'pe_accounts: Cannot create accounting entries against a disabled or group account';
  end if;
  if v_from.company_id is distinct from h.company_id or v_to.company_id is distinct from h.company_id then
    raise exception using errcode = 'P0001', message = 'pe_accounts: Paid From and Paid To must belong to the company';
  end if;

  if h.payment_type = 'Internal Transfer' then
    if h.paid_from_account_id = h.paid_to_account_id then
      raise exception using errcode = 'P0001', message = 'pe_accounts: paid_from and paid_to must differ';
    end if;
    if v_from.account_type not in ('Cash', 'Bank') or v_to.account_type not in ('Cash', 'Bank') then
      raise exception using errcode = 'P0001', message = 'pe_accounts: Internal Transfer accounts must be Cash or Bank';
    end if;
  elsif h.payment_type = 'Receive' then
    if h.party_type = 'Customer' and v_from.account_type is distinct from 'Receivable' then
      raise exception using errcode = 'P0001', message = 'pe_party_account: Paid From must be the party account';
    end if;
    if h.party_type = 'Supplier' and v_from.account_type is distinct from 'Payable' then
      raise exception using errcode = 'P0001', message = 'pe_party_account: Paid From must be the party account';
    end if;
    if v_to.account_type not in ('Cash', 'Bank') then
      raise exception using errcode = 'P0001', message = 'pe_bank: Paid To must be a Bank or Cash account';
    end if;
  else
    if h.party_type = 'Supplier' and v_to.account_type is distinct from 'Payable' then
      raise exception using errcode = 'P0001', message = 'pe_party_account: Paid To must be the party account';
    end if;
    if h.party_type = 'Customer' and v_to.account_type is distinct from 'Receivable' then
      raise exception using errcode = 'P0001', message = 'pe_party_account: Paid To must be the party account';
    end if;
    if v_from.account_type not in ('Cash', 'Bank') then
      raise exception using errcode = 'P0001', message = 'pe_bank: Paid From must be a Bank or Cash account';
    end if;
  end if;

  if (v_from.account_type = 'Bank' or v_to.account_type = 'Bank')
     and (nullif(btrim(h.reference_no), '') is null or h.reference_date is null) then
    raise exception using errcode = 'P0001',
      message = 'pe_reference: Reference No and Reference Date is mandatory for Bank transaction';
  end if;

  if h.paid_amount <= 0 or h.received_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'pe_amount: Paid Amount and Received Amount are mandatory';
  end if;

  delete from public.payment_entry_reference
   where parent_id = p_id and allocated_amount = 0;

  update public.payment_entry set posting_date = posting_date where id = p_id;
  select * into h from public.payment_entry where id = p_id;

  if h.difference_amount <> 0 then
    raise exception using errcode = 'P0001', message = 'pe_difference: Difference Amount must be zero';
  end if;

  v_party_account := case when h.payment_type = 'Pay' then h.paid_to_account_id else h.paid_from_account_id end;
  for r in
    select ref.*, row_number() over (order by ref.idx) as n
      from public.payment_entry_reference ref
     where ref.parent_id = p_id
     order by ref.idx
  loop
    if r.allocated_amount < 0 then
      raise exception using errcode = 'P0001',
        message = format('pe_allocated: Row #%s: Allocated Amount cannot be negative', r.n);
    end if;
    if r.reference_doctype is distinct from 'Journal Entry' then
      raise exception using errcode = 'P0001',
        message = format('pe_reference: %s is not available yet', r.reference_doctype);
    end if;
    select j.docstatus, j.name into v_status, v_name
      from public.journal_entry j
     where j.id = r.reference_id and j.org_id = h.org_id;
    if v_status is distinct from 1 then
      raise exception using errcode = 'P0001',
        message = format('pe_reference: Journal Entry %s must be submitted', coalesce(v_name, ''));
    end if;
    if not exists (
      select 1 from public.journal_entry_account a
       where a.parent_id = r.reference_id
         and a.account_id = coalesce(r.account_id, v_party_account)
         and a.party_type = h.party_type
         and a.party_id = h.party_id
    ) then
      raise exception using errcode = 'P0001',
        message = format('pe_reference: Party / Account does not match Journal Entry %s', coalesce(v_name, ''));
    end if;
    select count(*) into v_seen
      from public.payment_entry_reference d
     where d.parent_id = p_id and d.reference_doctype = r.reference_doctype and d.reference_id = r.reference_id;
    if v_seen > 1 then
      raise exception using errcode = 'P0001',
        message = format('pe_duplicate: Row #%s: Duplicate entry in References %s', r.n, coalesce(v_name, ''));
    end if;
    select coalesce(sum(p.amount), 0) into v_outstanding
      from public.payment_ledger_entry p
     where p.against_voucher_type = 'Journal Entry'
       and p.against_voucher_id = r.reference_id
       and p.account_id = coalesce(r.account_id, v_party_account)
       and not p.delinked;
    if r.allocated_amount > v_outstanding + 0.01 then
      raise exception using errcode = 'P0001',
        message = format('pe_allocated: Row #%s: Allocated Amount cannot be greater than outstanding amount.', r.n);
    end if;
  end loop;

  perform app.make_gl_entries(app.payment_entry_gl_map(p_id), '{"merge": false}'::jsonb);
end;
$$;

create or replace function app.get_outstanding_reference_documents(
  p_company uuid,
  p_party_type text,
  p_party uuid,
  p_account uuid,
  p_amount numeric
) returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_org uuid;
  v_left numeric := p_amount;
  v_alloc numeric;
  v_rows jsonb := '[]'::jsonb;
  r record;
begin
  if p_company is null or p_party is null or p_account is null or nullif(btrim(p_party_type), '') is null then
    return '[]'::jsonb;
  end if;
  select c.org_id into v_org from public.companies c where c.id = p_company;
  if v_org is null or not app.has_perm(v_org, 'Payment Entry', 'read') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;

  for r in
    select ple.against_voucher_id as reference_id,
           je.name as reference_name,
           min(ple.due_date) as due_date,
           sum(ple.amount) as outstanding,
           (
             select greatest(a.debit, a.credit)
               from public.journal_entry_account a
              where a.parent_id = ple.against_voucher_id
                and a.account_id = p_account
                and a.party_id = p_party
              order by a.idx
              limit 1
           ) as total_amount
      from public.payment_ledger_entry ple
      join public.journal_entry je on je.id = ple.against_voucher_id and je.org_id = ple.org_id
     where ple.company_id = p_company
       and ple.party_type = p_party_type
       and ple.party_id = p_party
       and ple.account_id = p_account
       and not ple.delinked
       and ple.against_voucher_type = 'Journal Entry'
       and je.docstatus = 1
     group by ple.against_voucher_id, je.name
    having sum(ple.amount) > 0.005
     order by min(ple.due_date) nulls last, min(ple.posting_date), je.name
  loop
    if v_left is null then
      v_alloc := r.outstanding;
    else
      v_alloc := least(r.outstanding, greatest(v_left, 0));
      v_left := v_left - v_alloc;
    end if;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'reference_doctype', 'Journal Entry',
      'reference_id', r.reference_id,
      'reference_name', r.reference_name,
      'due_date', r.due_date,
      'total_amount', coalesce(r.total_amount, r.outstanding),
      'outstanding_amount', r.outstanding,
      'allocated_amount', v_alloc,
      'account_id', p_account,
      'exchange_rate', 1
    ));
  end loop;
  return v_rows;
end;
$$;

revoke execute on function
  app.payment_entry_validate(),
  app.payment_entry_reference_validate(),
  app.payment_entry_deduction_validate(),
  app.payment_entry_refresh(),
  app.payment_entry_gl_map(uuid),
  app.on_submit__payment_entry(uuid)
from public, anon, authenticated;

revoke execute on function app.get_outstanding_reference_documents(uuid, text, uuid, uuid, numeric)
  from public, anon;
grant execute on function app.get_outstanding_reference_documents(uuid, text, uuid, uuid, numeric)
  to authenticated;

create or replace function public.get_outstanding_reference_documents(
  p_company uuid,
  p_party_type text,
  p_party uuid,
  p_account uuid,
  p_amount numeric
) returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.get_outstanding_reference_documents(p_company, p_party_type, p_party, p_account, p_amount);
$$;

revoke execute on function public.get_outstanding_reference_documents(uuid, text, uuid, uuid, numeric)
  from public, anon;
grant execute on function public.get_outstanding_reference_documents(uuid, text, uuid, uuid, numeric)
  to authenticated;

drop trigger if exists payment_entry_validate on public.payment_entry;
create trigger payment_entry_validate before insert or update on public.payment_entry
  for each row execute function app.payment_entry_validate();
drop trigger if exists touch_updated on public.payment_entry;
create trigger touch_updated before update on public.payment_entry
  for each row execute function app.touch_updated();

drop trigger if exists payment_entry_reference_validate on public.payment_entry_reference;
create trigger payment_entry_reference_validate before insert or update on public.payment_entry_reference
  for each row execute function app.payment_entry_reference_validate();
drop trigger if exists payment_entry_reference_refresh on public.payment_entry_reference;
create trigger payment_entry_reference_refresh after insert or update or delete on public.payment_entry_reference
  for each row execute function app.payment_entry_refresh();

drop trigger if exists payment_entry_deduction_validate on public.payment_entry_deduction;
create trigger payment_entry_deduction_validate before insert or update on public.payment_entry_deduction
  for each row execute function app.payment_entry_deduction_validate();
drop trigger if exists payment_entry_deduction_refresh on public.payment_entry_deduction;
create trigger payment_entry_deduction_refresh after insert or update or delete on public.payment_entry_deduction
  for each row execute function app.payment_entry_refresh();

alter table public.payment_entry enable row level security;
alter table public.payment_entry force row level security;
alter table public.payment_entry_reference enable row level security;
alter table public.payment_entry_reference force row level security;
alter table public.payment_entry_deduction enable row level security;
alter table public.payment_entry_deduction force row level security;

drop policy if exists payment_entry_select on public.payment_entry;
create policy payment_entry_select on public.payment_entry for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Entry', 'read'))::uuid[]));
drop policy if exists payment_entry_insert on public.payment_entry;
create policy payment_entry_insert on public.payment_entry for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Payment Entry', 'create'))::uuid[]));
drop policy if exists payment_entry_update on public.payment_entry;
create policy payment_entry_update on public.payment_entry for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]));
drop policy if exists payment_entry_delete on public.payment_entry;
create policy payment_entry_delete on public.payment_entry for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Entry', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists payment_entry_reference_select on public.payment_entry_reference;
create policy payment_entry_reference_select on public.payment_entry_reference for select to authenticated
  using (exists (select 1 from public.payment_entry p where p.id = parent_id));
drop policy if exists payment_entry_reference_insert on public.payment_entry_reference;
create policy payment_entry_reference_insert on public.payment_entry_reference for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Payment Entry', 'create'))::uuid[]));
drop policy if exists payment_entry_reference_update on public.payment_entry_reference;
create policy payment_entry_reference_update on public.payment_entry_reference for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]));
drop policy if exists payment_entry_reference_delete on public.payment_entry_reference;
create policy payment_entry_reference_delete on public.payment_entry_reference for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]));

drop policy if exists payment_entry_deduction_select on public.payment_entry_deduction;
create policy payment_entry_deduction_select on public.payment_entry_deduction for select to authenticated
  using (exists (select 1 from public.payment_entry p where p.id = parent_id));
drop policy if exists payment_entry_deduction_insert on public.payment_entry_deduction;
create policy payment_entry_deduction_insert on public.payment_entry_deduction for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Payment Entry', 'create'))::uuid[]));
drop policy if exists payment_entry_deduction_update on public.payment_entry_deduction;
create policy payment_entry_deduction_update on public.payment_entry_deduction for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]));
drop policy if exists payment_entry_deduction_delete on public.payment_entry_deduction;
create policy payment_entry_deduction_delete on public.payment_entry_deduction for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Entry', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default, allow_on_submit
) values (
  'Payment Entry', 'payment_entry', 'accounts', true, 'title', 'ACC-PAY-.YYYY.-', array['clearance_date']
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default,
      allow_on_submit = excluded.allow_on_submit;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Payment Entry Reference', 'payment_entry_reference', 'accounts', true, 'Payment Entry', 'references'),
  ('Payment Entry Deduction', 'payment_entry_deduction', 'accounts', true, 'Payment Entry', 'deductions')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true, parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Payment Entry', true, false, false, false, false, false, false),
  ('Accounts Manager', 'Payment Entry', true, true, true, true, true, true, true),
  ('Accounts User', 'Payment Entry', true, true, true, true, true, true, true),
  ('Auditor', 'Payment Entry', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
