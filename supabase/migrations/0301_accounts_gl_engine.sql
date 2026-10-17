-- 0301 accounts: make_gl_entries / reverse_gl_entries (docs/modules/01-accounts.md §4.0, 03-posting-engine).
-- ERPNext: erpnext/accounts/general_ledger.py, gl_entry.py. Budget check is a no-op until P7.
-- Outstanding refresh exists and does nothing until Sales Invoice / Purchase Invoice land.

create or replace function app.refresh_outstanding(p_voucher_type text, p_voucher_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Invoices are not tables yet. Callers still invoke this so later doctypes can replace the body.
  if p_voucher_type is null or p_voucher_id is null then
    return;
  end if;
end;
$$;

create or replace function app.make_gl_entries(p_entries jsonb, p_opts jsonb default '{}')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_merge boolean := coalesce((p_opts ->> 'merge')::boolean, false);
  v_precision int := 2;
  v_allowance numeric;
  v_unit numeric;
  v_diff numeric;
  v_company uuid;
  v_org uuid;
  v_voucher_type text;
  v_voucher_no text;
  v_posting date;
  v_opening boolean;
  v_frozen date;
  v_frozen_role text;
  v_round_account uuid;
  v_round_cc uuid;
  v_fy uuid;
  v_count int;
  r record;
  v_account record;
  v_balance numeric;
  v_cc uuid;
begin
  if jsonb_typeof(p_entries) is distinct from 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception using errcode = 'P0001',
      message = 'gl_entries: Incorrect number of General Ledger Entries found. You might have selected a wrong Account in the transaction.';
  end if;

  drop table if exists pg_temp._gl;
  create temp table _gl (
    idx int,
    org_id uuid,
    company_id uuid,
    posting_date date,
    fiscal_year_id uuid,
    account_id uuid,
    party_type text,
    party_id uuid,
    cost_center_id uuid,
    debit numeric,
    credit numeric,
    debit_in_account_currency numeric,
    credit_in_account_currency numeric,
    account_currency text,
    against text,
    against_voucher_type text,
    against_voucher_id uuid,
    voucher_type text,
    voucher_id uuid,
    voucher_no text,
    voucher_detail_id uuid,
    voucher_subtype text,
    remarks text,
    is_opening boolean,
    is_advance boolean,
    due_date date,
    advance_voucher_type text,
    advance_voucher_id uuid,
    transaction_currency text,
    transaction_exchange_rate numeric,
    debit_in_transaction_currency numeric,
    credit_in_transaction_currency numeric,
    is_system_generated boolean,
    account_name text,
    account_type text,
    report_type text
  ) on commit drop;

  insert into _gl (
    idx, org_id, company_id, posting_date, account_id, party_type, party_id, cost_center_id,
    debit, credit, debit_in_account_currency, credit_in_account_currency, against,
    against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, voucher_detail_id,
    voucher_subtype, remarks, is_opening, is_advance, due_date, advance_voucher_type, advance_voucher_id,
    transaction_exchange_rate, is_system_generated
  )
  select
    ordinality::int,
    nullif(e ->> 'org_id', '')::uuid,
    nullif(e ->> 'company_id', '')::uuid,
    (e ->> 'posting_date')::date,
    nullif(e ->> 'account_id', '')::uuid,
    nullif(e ->> 'party_type', ''),
    nullif(e ->> 'party_id', '')::uuid,
    nullif(e ->> 'cost_center_id', '')::uuid,
    coalesce((e ->> 'debit')::numeric, 0),
    coalesce((e ->> 'credit')::numeric, 0),
    coalesce((e ->> 'debit_in_account_currency')::numeric, (e ->> 'debit')::numeric, 0),
    coalesce((e ->> 'credit_in_account_currency')::numeric, (e ->> 'credit')::numeric, 0),
    e ->> 'against',
    nullif(e ->> 'against_voucher_type', ''),
    nullif(e ->> 'against_voucher_id', '')::uuid,
    e ->> 'voucher_type',
    nullif(e ->> 'voucher_id', '')::uuid,
    e ->> 'voucher_no',
    nullif(e ->> 'voucher_detail_id', '')::uuid,
    nullif(e ->> 'voucher_subtype', ''),
    e ->> 'remarks',
    coalesce((e ->> 'is_opening')::boolean, false),
    coalesce((e ->> 'is_advance')::boolean, false),
    nullif(e ->> 'due_date', '')::date,
    nullif(e ->> 'advance_voucher_type', ''),
    nullif(e ->> 'advance_voucher_id', '')::uuid,
    coalesce((e ->> 'transaction_exchange_rate')::numeric, 1),
    coalesce((e ->> 'is_system_generated')::boolean, false)
  from jsonb_array_elements(p_entries) with ordinality as t(e, ordinality);

  select company_id, org_id, voucher_type, voucher_no, posting_date, is_opening
    into v_company, v_org, v_voucher_type, v_voucher_no, v_posting, v_opening
    from _gl
   order by idx
   limit 1;

  if v_org is null then
    select org_id into v_org from public.companies where id = v_company;
    update _gl set org_id = v_org where idx is not null;
  end if;

  select accounts_frozen_till_date, role_allowed_for_frozen_entries, round_off_account_id, round_off_cost_center_id, cost_center_id
    into v_frozen, v_frozen_role, v_round_account, v_round_cc, v_cc
    from public.companies
   where id = v_company;

  if v_frozen is not null and v_posting <= v_frozen then
    if v_frozen_role is null or not exists (
      select 1 from public.org_members m
       where m.org_id = v_org and m.user_id = auth.uid() and m.status = 'active' and v_frozen_role = any (m.roles)
    ) then
      raise exception using errcode = 'P0001',
        message = format('gl_frozen: You are not authorized to add or update entries before %s', v_frozen);
    end if;
  end if;

  select fy.id into v_fy
    from public.fiscal_year fy
   where fy.org_id = v_org and not fy.disabled
     and v_posting between fy.year_start_date and fy.year_end_date
     and (
       not exists (select 1 from public.fiscal_year_company c where c.parent_id = fy.id)
       or exists (select 1 from public.fiscal_year_company c where c.parent_id = fy.id and c.company_id = v_company)
     )
   order by fy.year_start_date
   limit 1;
  if v_fy is null then
    raise exception using errcode = 'P0001',
      message = format('fiscal_year: Date %s is not in any active Fiscal Year', v_posting);
  end if;
  update _gl set fiscal_year_id = v_fy where idx is not null;

  for r in select * from _gl order by idx loop
    select a.name, a.account_type, a.report_type, a.is_group, a.disabled, a.company_id, a.freeze_account,
           a.balance_must_be, a.account_currency, a.root_type
      into v_account
      from public.account a
     where a.id = r.account_id and a.org_id = r.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'gl_account: Account is required';
    end if;
    if v_account.company_id is distinct from r.company_id then
      raise exception using errcode = 'P0001',
        message = format('gl_account_company: %s %s: Account %s does not belong to the company', v_voucher_type, v_voucher_no, v_account.name);
    end if;
    if v_account.is_group or v_account.disabled then
      raise exception using errcode = 'P0001',
        message = format('gl_account_inactive: %s %s: Account %s is inactive', v_voucher_type, v_voucher_no, v_account.name);
    end if;
    if v_account.freeze_account = 'Yes' then
      raise exception using errcode = 'P0001', message = format('gl_account_frozen: Account %s is frozen', v_account.name);
    end if;
    if v_opening and v_account.report_type = 'Profit and Loss' then
      raise exception using errcode = 'P0001',
        message = format('gl_opening_pl: Profit and Loss account %s cannot be used in an Opening Entry', v_account.name);
    end if;
    if v_account.account_type in ('Receivable', 'Payable') and r.party_id is null then
      raise exception using errcode = 'P0001',
        message = format(
          'gl_party: %s %s: %s is required against %s account %s',
          v_voucher_type, v_voucher_no,
          case when v_account.account_type = 'Receivable' then 'Customer' else 'Supplier' end,
          v_account.account_type, v_account.name
        );
    end if;
    if v_account.report_type = 'Profit and Loss' and r.cost_center_id is null then
      if v_cc is null then
        raise exception using errcode = 'P0001',
          message = format('gl_cost_center: %s %s: Cost Center is required for Profit and Loss account %s', v_voucher_type, v_voucher_no, v_account.name);
      end if;
      update _gl set cost_center_id = v_cc where idx = r.idx;
    end if;

    update _gl
       set account_name = v_account.name,
           account_type = v_account.account_type,
           report_type = v_account.report_type,
           account_currency = v_account.account_currency,
           transaction_currency = v_account.account_currency
     where idx = r.idx;
  end loop;

  -- Negative debit becomes credit, and the reverse (toggle_debit_credit_if_negative).
  update _gl set credit = credit + abs(debit), credit_in_account_currency = credit_in_account_currency + abs(debit_in_account_currency),
                 debit = 0, debit_in_account_currency = 0
   where debit < 0 or debit_in_account_currency < 0;
  update _gl set debit = debit + abs(credit), debit_in_account_currency = debit_in_account_currency + abs(credit_in_account_currency),
                 credit = 0, credit_in_account_currency = 0
   where credit < 0 or credit_in_account_currency < 0;

  if v_merge then
    drop table if exists pg_temp._gl_merged;
    create temp table _gl_merged on commit drop as
    select min(idx) as idx, org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id,
           sum(debit) as debit, sum(credit) as credit,
           sum(debit_in_account_currency) as debit_in_account_currency, sum(credit_in_account_currency) as credit_in_account_currency,
           max(account_currency) as account_currency, max(against) as against, against_voucher_type, against_voucher_id,
           voucher_type, voucher_id, voucher_no, min(voucher_detail_id::text)::uuid as voucher_detail_id, max(voucher_subtype) as voucher_subtype,
           max(remarks) as remarks, bool_or(is_opening) as is_opening, bool_or(is_advance) as is_advance, max(due_date) as due_date,
           advance_voucher_type, advance_voucher_id, max(transaction_currency) as transaction_currency,
           max(transaction_exchange_rate) as transaction_exchange_rate,
           sum(debit) as debit_in_transaction_currency, sum(credit) as credit_in_transaction_currency,
           bool_or(is_system_generated) as is_system_generated, max(account_name) as account_name,
           max(account_type) as account_type, max(report_type) as report_type
      from _gl
     group by org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id,
              against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, advance_voucher_type, advance_voucher_id;
    delete from _gl where idx is not null;
    insert into _gl select * from _gl_merged;
    update _gl set
      debit = debit - least(debit, credit),
      credit = credit - least(debit, credit),
      debit_in_account_currency = debit_in_account_currency - least(debit_in_account_currency, credit_in_account_currency),
      credit_in_account_currency = credit_in_account_currency - least(debit_in_account_currency, credit_in_account_currency)
     where idx is not null;
    delete from _gl where debit = 0 and credit = 0;
  end if;

  update _gl set
    debit = app.round(debit, v_precision),
    credit = app.round(credit, v_precision),
    debit_in_account_currency = app.round(debit_in_account_currency, v_precision),
    credit_in_account_currency = app.round(credit_in_account_currency, v_precision),
    debit_in_transaction_currency = app.round(debit, v_precision),
    credit_in_transaction_currency = app.round(credit, v_precision)
   where idx is not null;

  v_diff := app.round(coalesce((select sum(debit) - sum(credit) from _gl), 0), v_precision);
  v_allowance := case when v_voucher_type in ('Journal Entry', 'Payment Entry') then 5.0 / power(10, v_precision) else 0.5 end;
  v_unit := 1.0 / power(10, v_precision);
  if abs(v_diff) > v_allowance then
    raise exception using errcode = 'P0001',
      message = format(
        'gl_unbalanced: Debit and Credit not equal for %s #%s. Difference is %s.',
        v_voucher_type, v_voucher_no, v_diff
      );
  elsif abs(v_diff) >= v_unit then
    v_round_account := coalesce(v_round_account, (select default_expense_account_id from public.companies where id = v_company));
    if v_round_account is null or v_round_cc is null then
      raise exception using errcode = 'P0001',
        message = 'gl_round_off: Please mention Round Off Account and Round Off Cost Center in the Company';
    end if;
    insert into _gl (
      idx, org_id, company_id, posting_date, fiscal_year_id, account_id, cost_center_id,
      debit, credit, debit_in_account_currency, credit_in_account_currency,
      voucher_type, voucher_id, voucher_no, voucher_subtype, remarks, is_opening, is_advance, is_system_generated,
      transaction_exchange_rate, debit_in_transaction_currency, credit_in_transaction_currency, account_type
    )
    select 1000, v_org, v_company, v_posting, v_fy, v_round_account, v_round_cc,
           case when v_diff < 0 then abs(v_diff) else 0 end,
           case when v_diff > 0 then v_diff else 0 end,
           case when v_diff < 0 then abs(v_diff) else 0 end,
           case when v_diff > 0 then v_diff else 0 end,
           v_voucher_type, (select voucher_id from _gl limit 1), v_voucher_no,
           (select voucher_subtype from _gl limit 1), 'Round Off', v_opening, false, true,
           1, case when v_diff < 0 then abs(v_diff) else 0 end, case when v_diff > 0 then v_diff else 0 end,
           'Round Off';
  end if;

  for r in
    select g.account_id, a.name, a.balance_must_be, sum(g.debit - g.credit) as delta
      from _gl g
      join public.account a on a.id = g.account_id
     where a.balance_must_be in ('Debit', 'Credit')
     group by g.account_id, a.name, a.balance_must_be
  loop
    v_balance := coalesce((
      select sum(e.debit - e.credit) from public.gl_entry e
       where e.account_id = r.account_id and not e.is_cancelled
    ), 0) + r.delta;
    if r.balance_must_be = 'Debit' and v_balance < 0 then
      raise exception using errcode = 'P0001',
        message = format('gl_balance: Balance for Account %s must always be Debit', r.name);
    end if;
    if r.balance_must_be = 'Credit' and v_balance > 0 then
      raise exception using errcode = 'P0001',
        message = format('gl_balance: Balance for Account %s must always be Credit', r.name);
    end if;
  end loop;

  select count(*) into v_count from _gl where debit <> 0 or credit <> 0;
  if v_count < 2 then
    raise exception using errcode = 'P0001',
      message = 'gl_entries: Incorrect number of General Ledger Entries found. You might have selected a wrong Account in the transaction.';
  end if;

  insert into public.payment_ledger_entry (
    org_id, company_id, posting_date, account_type, account_id, party_type, party_id,
    voucher_type, voucher_id, voucher_no, against_voucher_type, against_voucher_id, against_voucher_no,
    amount, account_currency, amount_in_account_currency, due_date, cost_center_id, voucher_detail_id, remarks,
    advance_voucher_type, advance_voucher_id
  )
  select g.org_id, g.company_id, g.posting_date, g.account_type, g.account_id, g.party_type, g.party_id,
         g.voucher_type, g.voucher_id, g.voucher_no,
         coalesce(g.against_voucher_type, g.voucher_type),
         coalesce(g.against_voucher_id, g.voucher_id),
         g.voucher_no,
         case when g.account_type = 'Receivable' then g.debit - g.credit else g.credit - g.debit end,
         g.account_currency,
         case when g.account_type = 'Receivable' then g.debit_in_account_currency - g.credit_in_account_currency
              else g.credit_in_account_currency - g.debit_in_account_currency end,
         g.due_date, g.cost_center_id, g.voucher_detail_id, g.remarks, g.advance_voucher_type, g.advance_voucher_id
    from _gl g
   where g.account_type in ('Receivable', 'Payable') and g.party_id is not null;

  insert into public.gl_entry (
    org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id,
    debit, credit, account_currency, debit_in_account_currency, credit_in_account_currency, against,
    against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, voucher_detail_id, voucher_subtype,
    remarks, is_opening, is_advance, due_date, transaction_currency, transaction_exchange_rate,
    debit_in_transaction_currency, credit_in_transaction_currency, advance_voucher_type, advance_voucher_id, is_system_generated
  )
  select org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id,
         debit, credit, account_currency, debit_in_account_currency, credit_in_account_currency, against,
         against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, voucher_detail_id, voucher_subtype,
         remarks, is_opening, is_advance, due_date, transaction_currency, transaction_exchange_rate,
         debit_in_transaction_currency, credit_in_transaction_currency, advance_voucher_type, advance_voucher_id, is_system_generated
    from _gl
   where debit <> 0 or credit <> 0;

  perform app.refresh_outstanding(g.against_voucher_type, g.against_voucher_id)
    from (
      select distinct coalesce(against_voucher_type, voucher_type) as against_voucher_type,
                      coalesce(against_voucher_id, voucher_id) as against_voucher_id
        from _gl
       where account_type in ('Receivable', 'Payable')
    ) g;
end;
$$;

create or replace function app.reverse_gl_entries(p_voucher_type text, p_voucher_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  drop table if exists pg_temp._ple_old;
  create temp table _ple_old on commit drop as
  select * from public.payment_ledger_entry
   where voucher_type = p_voucher_type and voucher_id = p_voucher_id and not delinked;

  insert into public.payment_ledger_entry (
    org_id, company_id, posting_date, account_type, account_id, party_type, party_id,
    voucher_type, voucher_id, voucher_no, against_voucher_type, against_voucher_id, against_voucher_no,
    amount, account_currency, amount_in_account_currency, due_date, cost_center_id, project_id,
    delinked, voucher_detail_id, remarks, advance_voucher_type, advance_voucher_id
  )
  select org_id, company_id, posting_date, account_type, account_id, party_type, party_id,
         voucher_type, voucher_id, voucher_no, against_voucher_type, against_voucher_id, against_voucher_no,
         -amount, account_currency, -amount_in_account_currency, due_date, cost_center_id, project_id,
         true, voucher_detail_id, remarks, advance_voucher_type, advance_voucher_id
    from _ple_old;

  update public.payment_ledger_entry set delinked = true
   where id in (select id from _ple_old);

  drop table if exists pg_temp._gl_old;
  create temp table _gl_old on commit drop as
  select * from public.gl_entry
   where voucher_type = p_voucher_type and voucher_id = p_voucher_id and not is_cancelled;

  update public.gl_entry set is_cancelled = true
   where id in (select id from _gl_old);

  insert into public.gl_entry (
    org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id, project_id,
    debit, credit, account_currency, debit_in_account_currency, credit_in_account_currency, against,
    against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, voucher_detail_id, voucher_subtype,
    remarks, is_opening, is_advance, due_date, is_cancelled, transaction_currency, transaction_exchange_rate,
    debit_in_transaction_currency, credit_in_transaction_currency, advance_voucher_type, advance_voucher_id, is_system_generated
  )
  select org_id, company_id, posting_date, fiscal_year_id, account_id, party_type, party_id, cost_center_id, project_id,
         credit, debit, account_currency, credit_in_account_currency, debit_in_account_currency, against,
         against_voucher_type, against_voucher_id, voucher_type, voucher_id, voucher_no, voucher_detail_id, voucher_subtype,
         'On cancellation of ' || voucher_no, is_opening, is_advance, due_date, true, transaction_currency, transaction_exchange_rate,
         credit_in_transaction_currency, debit_in_transaction_currency, advance_voucher_type, advance_voucher_id, is_system_generated
    from _gl_old;

  perform app.refresh_outstanding(against_voucher_type, against_voucher_id)
    from (select distinct against_voucher_type, against_voucher_id from _ple_old) p;
end;
$$;

revoke execute on function
  app.refresh_outstanding(text, uuid), app.make_gl_entries(jsonb, jsonb), app.reverse_gl_entries(text, uuid)
from public, anon, authenticated;
