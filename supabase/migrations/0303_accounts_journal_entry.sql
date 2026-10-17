-- 0303 accounts: Journal Entry (docs/modules/01-accounts.md §2.16, §3.6, §4.1).
-- ERPNext: erpnext/accounts/doctype/journal_entry/journal_entry.py, journal_entry.json,
-- services/journal_entry_gl_composer.py (one GL row per account line; merge stays off).
-- party_id is a uuid with no foreign key: it points at customer or supplier depending on party_type.
-- multi_currency is stored and forced false (single company currency). Bank Account, Project and
-- invoice reference checks wait until those tables are posted.

create table if not exists public.journal_entry (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations (id) on delete cascade,
  name                text not null,
  title               text,
  voucher_type        text not null default 'Journal Entry' check (voucher_type in (
                        'Journal Entry', 'Bank Entry', 'Cash Entry', 'Credit Card Entry', 'Debit Note', 'Credit Note',
                        'Contra Entry', 'Excise Entry', 'Write Off Entry', 'Opening Entry', 'Depreciation Entry',
                        'Exchange Gain Or Loss'
                      )),
  naming_series       text not null default 'ACC-JV-.YYYY.-',
  company_id          uuid not null,
  posting_date        date not null default current_date,
  cheque_no           text,
  cheque_date         date,
  user_remark         text,
  total_debit         numeric(21,9) not null default 0,
  total_credit        numeric(21,9) not null default 0,
  difference          numeric(21,9) not null default 0,
  multi_currency      boolean not null default false,
  is_opening          text not null default 'No' check (is_opening in ('No', 'Yes')),
  bill_no             text,
  bill_date           date,
  due_date            date,
  write_off_based_on  text not null default 'Accounts Receivable'
                        check (write_off_based_on in ('Accounts Receivable', 'Accounts Payable')),
  write_off_amount    numeric(21,9) not null default 0,
  pay_to_recd_from    text,
  mode_of_payment_id  uuid,
  letter_head_id      uuid,
  print_heading_id    uuid,
  reversal_of         uuid,
  stock_entry_id      uuid,
  clearance_date      date,
  custom_remark       boolean not null default false,
  docstatus           smallint not null default 0 check (docstatus in (0, 1, 2)),
  amended_from        uuid,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, mode_of_payment_id) references public.mode_of_payment (org_id, id),
  foreign key (org_id, letter_head_id) references public.letter_head (org_id, id),
  foreign key (org_id, print_heading_id) references public.print_heading (org_id, id),
  foreign key (org_id, amended_from) references public.journal_entry (org_id, id) on delete set null (amended_from),
  foreign key (org_id, reversal_of) references public.journal_entry (org_id, id) on delete set null (reversal_of)
);

create index if not exists journal_entry_posting_idx on public.journal_entry (org_id, posting_date);
create index if not exists journal_entry_company_idx on public.journal_entry (org_id, company_id);
create index if not exists journal_entry_mode_of_payment_idx on public.journal_entry (org_id, mode_of_payment_id);
create index if not exists journal_entry_letter_head_idx on public.journal_entry (org_id, letter_head_id);
create index if not exists journal_entry_print_heading_idx on public.journal_entry (org_id, print_heading_id);
create index if not exists journal_entry_amended_idx on public.journal_entry (org_id, amended_from);
create index if not exists journal_entry_reversal_idx on public.journal_entry (org_id, reversal_of);

create table if not exists public.journal_entry_account (
  id                          uuid primary key default gen_random_uuid(),
  org_id                      uuid not null,
  parent_id                   uuid not null,
  idx                         int not null,
  account_id                  uuid not null,
  account_type                text,
  party_type                  text check (party_type is null or party_type in ('Customer', 'Supplier')),
  party_id                    uuid,
  cost_center_id              uuid,
  account_currency            text,
  exchange_rate               numeric(21,9) not null default 1,
  debit_in_account_currency   numeric(21,9) not null default 0,
  debit                       numeric(21,9) not null default 0,
  credit_in_account_currency  numeric(21,9) not null default 0,
  credit                      numeric(21,9) not null default 0,
  reference_type              text check (reference_type is null or reference_type in (
                                'Sales Invoice', 'Purchase Invoice', 'Journal Entry', 'Sales Order', 'Purchase Order'
                              )),
  reference_id                uuid,
  reference_due_date          date,
  is_advance                  text not null default 'No' check (is_advance in ('No', 'Yes')),
  against_account             text,
  user_remark                 text,
  advance_voucher_type        text,
  advance_voucher_id          uuid,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.journal_entry (org_id, id) on delete cascade,
  foreign key (org_id, account_id) references public.account (org_id, id),
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id)
);

create index if not exists journal_entry_account_parent_idx on public.journal_entry_account (org_id, parent_id);
create index if not exists journal_entry_account_account_idx on public.journal_entry_account (org_id, account_id);
create index if not exists journal_entry_account_cost_center_idx on public.journal_entry_account (org_id, cost_center_id);

create or replace function app.journal_entry_validate()
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
    new.naming_series := 'ACC-JV-.YYYY.-';
  end if;
  if new.posting_date is null then
    new.posting_date := current_date;
  end if;
  if new.voucher_type = 'Opening Entry' then
    new.is_opening := 'Yes';
  end if;
  new.multi_currency := false;
  new.write_off_amount := coalesce(new.write_off_amount, 0);
  if new.amended_from is not null and tg_op = 'INSERT' then
    new.clearance_date := null;
    new.docstatus := 0;
  end if;
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  if not new.custom_remark and nullif(btrim(new.user_remark), '') is null and new.cheque_no is not null then
    new.user_remark := 'Reference #' || new.cheque_no || coalesce(' dated ' || new.cheque_date::text, '');
  end if;
  return new;
end;
$$;

create or replace function app.journal_entry_account_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_account record;
  v_company uuid;
begin
  select company_id into v_company from public.journal_entry where id = new.parent_id;
  select a.name, a.account_type, a.account_currency, a.company_id, a.is_group, a.disabled
    into v_account
    from public.account a
   where a.id = new.account_id and a.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001', message = format('je_account: Row %s: Account is required', new.idx);
  end if;
  if v_account.company_id is distinct from v_company then
    raise exception using errcode = 'P0001',
      message = format('je_account: Row %s: Account %s does not belong to the company', new.idx, v_account.name);
  end if;
  if v_account.is_group or v_account.disabled then
    raise exception using errcode = 'P0001',
      message = format('je_account: Row %s: Account %s is inactive', new.idx, v_account.name);
  end if;
  new.account_type := v_account.account_type;
  new.account_currency := v_account.account_currency;
  new.exchange_rate := 1;
  if coalesce(new.debit_in_account_currency, 0) = 0 and coalesce(new.debit, 0) <> 0 then
    new.debit_in_account_currency := new.debit;
  end if;
  if coalesce(new.credit_in_account_currency, 0) = 0 and coalesce(new.credit, 0) <> 0 then
    new.credit_in_account_currency := new.credit;
  end if;
  new.debit := app.round(coalesce(new.debit_in_account_currency, 0), 2);
  new.credit := app.round(coalesce(new.credit_in_account_currency, 0), 2);
  if new.debit <> 0 and new.credit <> 0 then
    raise exception using errcode = 'P0001',
      message = format('je_both: Row %s: Both Debit and Credit values cannot be set', new.idx);
  end if;
  if new.cost_center_id is null then
    select c.cost_center_id into new.cost_center_id
      from public.companies c
     where c.id = v_company;
  end if;
  return new;
end;
$$;

create or replace function app.journal_entry_account_totals()
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
  update public.journal_entry_account r
     set against_account = (
       select string_agg(distinct a.name, ', ' order by a.name)
         from public.journal_entry_account o
         join public.account a on a.id = o.account_id
        where o.parent_id = r.parent_id and o.account_id is distinct from r.account_id
     )
   where r.parent_id = v_parent;

  update public.journal_entry j
     set total_debit = s.debit,
         total_credit = s.credit,
         difference = s.debit - s.credit,
         title = coalesce(nullif(btrim(j.pay_to_recd_from), ''), s.first_name, j.name)
    from (
      select coalesce(sum(r.debit), 0) as debit,
             coalesce(sum(r.credit), 0) as credit,
             (
               select a.name
                 from public.journal_entry_account r2
                 join public.account a on a.id = r2.account_id
                where r2.parent_id = v_parent
                order by r2.idx
                limit 1
             ) as first_name
        from public.journal_entry_account r
       where r.parent_id = v_parent
    ) s
   where j.id = v_parent;
  return null;
end;
$$;

create or replace function app.journal_entry_gl_map(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(to_jsonb(g) order by g.idx), '[]'::jsonb)
    from (
      select r.idx,
             h.org_id,
             h.company_id,
             h.posting_date,
             r.account_id,
             r.party_type,
             r.party_id,
             r.cost_center_id,
             r.debit,
             r.credit,
             r.debit_in_account_currency,
             r.credit_in_account_currency,
             r.against_account as against,
             case when r.reference_type in ('Sales Order', 'Purchase Order') then 'Journal Entry' else r.reference_type end as against_voucher_type,
             case when r.reference_type in ('Sales Order', 'Purchase Order') then h.id else r.reference_id end as against_voucher_id,
             'Journal Entry'::text as voucher_type,
             h.id as voucher_id,
             h.name as voucher_no,
             r.id as voucher_detail_id,
             h.voucher_type as voucher_subtype,
             concat_ws(E'\n', nullif(r.user_remark, ''), nullif(h.user_remark, '')) as remarks,
             (h.is_opening = 'Yes') as is_opening,
             (r.is_advance = 'Yes') as is_advance,
             h.due_date,
             case when r.reference_type in ('Sales Order', 'Purchase Order') then r.reference_type end as advance_voucher_type,
             case when r.reference_type in ('Sales Order', 'Purchase Order') then r.reference_id end as advance_voucher_id
        from public.journal_entry h
        join public.journal_entry_account r on r.parent_id = h.id
       where h.id = p_id
         and (r.debit <> 0 or r.credit <> 0)
    ) g;
$$;

create or replace function app.on_submit__journal_entry(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.journal_entry;
  r record;
  v_limit numeric;
  v_bypass boolean;
  v_outstanding numeric;
  v_party text;
begin
  select * into h from public.journal_entry where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Journal Entry not found';
  end if;
  if not exists (select 1 from public.journal_entry_account where parent_id = p_id) then
    raise exception using errcode = 'P0001', message = 'je_accounts: Accounts table cannot be blank.';
  end if;
  if h.voucher_type = 'Bank Entry' and (nullif(btrim(h.cheque_no), '') is null or h.cheque_date is null) then
    raise exception using errcode = 'P0001',
      message = 'je_reference: Reference No & Reference Date is required for Bank Entry';
  end if;
  if h.cheque_date is not null and nullif(btrim(h.cheque_no), '') is null then
    raise exception using errcode = 'P0001',
      message = 'je_reference: Reference No is mandatory if you entered Reference Date';
  end if;

  for r in
    select row_number() over (order by a.idx) as n, a.*, acc.name as account_name, acc.account_type as acc_type,
           c.enable_perpetual_inventory
      from public.journal_entry_account a
      join public.account acc on acc.id = a.account_id
      join public.companies c on c.id = h.company_id
     where a.parent_id = p_id
     order by a.idx
  loop
    if r.debit = 0 and r.credit = 0 then
      raise exception using errcode = 'P0001',
        message = format('je_zero: Row %s: Both Debit and Credit values cannot be zero', r.n);
    end if;
    if r.enable_perpetual_inventory and r.acc_type in (
      'Stock', 'Stock Received But Not Billed', 'Asset Received But Not Billed',
      'Expenses Included In Valuation', 'Expenses Included In Asset Valuation'
    ) then
      raise exception using errcode = 'P0001',
        message = format('je_stock: Account: %s can only be updated via Stock Transactions', r.account_name);
    end if;
    if r.acc_type in ('Receivable', 'Payable') and (r.party_type is null or r.party_id is null) then
      raise exception using errcode = 'P0001',
        message = format('je_party: Row %s: Party Type and Party is required for Receivable / Payable account %s', r.n, r.account_name);
    end if;
    if r.acc_type = 'Receivable' and r.party_type is distinct from 'Customer' and r.party_type is not null then
      raise exception using errcode = 'P0001',
        message = format('je_party_type: Row %s: Account %s and Party Type %s have different account types', r.n, r.account_name, r.party_type);
    end if;
    if r.acc_type = 'Payable' and r.party_type is distinct from 'Supplier' and r.party_type is not null then
      raise exception using errcode = 'P0001',
        message = format('je_party_type: Row %s: Account %s and Party Type %s have different account types', r.n, r.account_name, r.party_type);
    end if;
    if r.party_type = 'Customer' and not exists (
      select 1 from public.customer c where c.id = r.party_id and c.org_id = h.org_id
    ) then
      raise exception using errcode = 'P0001', message = format('je_party: Row %s: Customer was not found', r.n);
    end if;
    if r.party_type = 'Supplier' then
      select s.supplier_name into v_party from public.supplier s where s.id = r.party_id and s.org_id = h.org_id;
      if v_party is null then
        raise exception using errcode = 'P0001', message = format('je_party: Row %s: Supplier was not found', r.n);
      end if;
      if exists (
        select 1 from public.supplier s
         where s.id = r.party_id and s.on_hold and s.hold_type in ('All', 'Invoices')
      ) then
        raise exception using errcode = 'P0001', message = format('je_supplier_hold: Supplier %s is on hold', v_party);
      end if;
    end if;
    if r.party_type = 'Customer' and r.acc_type = 'Receivable' then
      select l.credit_limit, l.bypass_credit_limit_check into v_limit, v_bypass
        from public.customer_credit_limit l
       where l.parent_id = r.party_id and l.company_id = h.company_id;
      if found and not coalesce(v_bypass, false) and coalesce(v_limit, 0) > 0 then
        select coalesce(sum(g.debit - g.credit), 0) into v_outstanding
          from public.gl_entry g
          join public.account a on a.id = g.account_id
         where g.party_id = r.party_id and g.company_id = h.company_id and not g.is_cancelled and a.account_type = 'Receivable';
        if v_outstanding + r.debit - r.credit > v_limit then
          raise exception using errcode = 'P0001',
            message = format('je_credit_limit: Credit limit of %s exceeded for this customer', v_limit);
        end if;
      end if;
    end if;
  end loop;

  if exists (
    select 1
      from public.journal_entry_account d
      join public.journal_entry_account c on c.parent_id = d.parent_id and c.account_id = d.account_id and c.credit > 0
     where d.parent_id = p_id and d.debit > 0
  ) then
    raise exception using errcode = 'P0001', message = 'je_same_account: You cannot credit and debit same account at the same time';
  end if;

  -- Differences inside the Journal Entry allowance (0.05) are left for app.make_gl_entries to round off.
  if abs(app.round(h.total_debit - h.total_credit, 2)) > 0.05 then
    raise exception using errcode = 'P0001',
      message = format(
        'je_difference: Total Debit must be equal to Total Credit. The difference is %s',
        app.round(h.total_debit - h.total_credit, 2)
      );
  end if;

  perform app.make_gl_entries(app.journal_entry_gl_map(p_id), '{"merge": false}'::jsonb);
end;
$$;

revoke execute on function
  app.journal_entry_validate(), app.journal_entry_account_validate(), app.journal_entry_account_totals(),
  app.journal_entry_gl_map(uuid), app.on_submit__journal_entry(uuid)
from public, anon, authenticated;

drop trigger if exists journal_entry_validate on public.journal_entry;
create trigger journal_entry_validate before insert or update on public.journal_entry
  for each row execute function app.journal_entry_validate();
drop trigger if exists touch_updated on public.journal_entry;
create trigger touch_updated before update on public.journal_entry
  for each row execute function app.touch_updated();
drop trigger if exists journal_entry_account_validate on public.journal_entry_account;
create trigger journal_entry_account_validate before insert or update on public.journal_entry_account
  for each row execute function app.journal_entry_account_validate();
drop trigger if exists journal_entry_account_totals on public.journal_entry_account;
create trigger journal_entry_account_totals after insert or update or delete on public.journal_entry_account
  for each row execute function app.journal_entry_account_totals();

alter table public.journal_entry enable row level security;
alter table public.journal_entry force row level security;
alter table public.journal_entry_account enable row level security;
alter table public.journal_entry_account force row level security;

drop policy if exists journal_entry_select on public.journal_entry;
create policy journal_entry_select on public.journal_entry for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Journal Entry', 'read'))::uuid[]));
drop policy if exists journal_entry_insert on public.journal_entry;
create policy journal_entry_insert on public.journal_entry for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Journal Entry', 'create'))::uuid[]));
drop policy if exists journal_entry_update on public.journal_entry;
create policy journal_entry_update on public.journal_entry for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Journal Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Journal Entry', 'write'))::uuid[]));
drop policy if exists journal_entry_delete on public.journal_entry;
create policy journal_entry_delete on public.journal_entry for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Journal Entry', 'delete'))::uuid[]) and docstatus = 0);

drop policy if exists journal_entry_account_select on public.journal_entry_account;
create policy journal_entry_account_select on public.journal_entry_account for select to authenticated
  using (exists (select 1 from public.journal_entry p where p.id = parent_id));
drop policy if exists journal_entry_account_insert on public.journal_entry_account;
create policy journal_entry_account_insert on public.journal_entry_account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Journal Entry', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Journal Entry', 'create'))::uuid[]));
drop policy if exists journal_entry_account_update on public.journal_entry_account;
create policy journal_entry_account_update on public.journal_entry_account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Journal Entry', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Journal Entry', 'write'))::uuid[]));
drop policy if exists journal_entry_account_delete on public.journal_entry_account;
create policy journal_entry_account_delete on public.journal_entry_account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Journal Entry', 'write'))::uuid[]));

insert into public.doctype_meta (
  doctype, table_name, module, is_submittable, title_field, naming_series_default, allow_on_submit
) values (
  'Journal Entry', 'journal_entry', 'accounts', true, 'title', 'ACC-JV-.YYYY.-', array['clearance_date']
)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, naming_series_default = excluded.naming_series_default,
      allow_on_submit = excluded.allow_on_submit;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Journal Entry Account', 'journal_entry_account', 'accounts', true, 'Journal Entry', 'accounts')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true, parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Journal Entry', true, false, false, false, false, false, false),
  ('Accounts Manager', 'Journal Entry', true, true, true, true, true, true, true),
  ('Accounts User', 'Journal Entry', true, true, true, true, true, true, true),
  ('Auditor', 'Journal Entry', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
