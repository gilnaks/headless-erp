-- 0212 accounts: Account tree, chart expansion, default-account wiring (docs/modules/01-accounts.md §2.1, 00-setup B3 B4 B9).
-- ERPNext: erpnext/accounts/doctype/account, accounts/utils.py get_autoname_with_number, company.py create_charts.

create table if not exists public.account (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations (id) on delete cascade,
  name               text not null,
  account_name       text not null check (length(trim(account_name)) > 0),
  account_number     text,
  is_group           boolean not null default false,
  company_id         uuid not null,
  root_type          text not null check (root_type in ('Asset', 'Liability', 'Income', 'Expense', 'Equity')),
  report_type        text not null check (report_type in ('Balance Sheet', 'Profit and Loss')),
  account_currency   text not null,
  parent_id          uuid,
  account_type       text check (account_type is null or account_type in (
    'Accumulated Depreciation', 'Asset Received But Not Billed', 'Bank', 'Cash', 'Chargeable',
    'Capital Work in Progress', 'Cost of Goods Sold', 'Current Asset', 'Current Liability', 'Depreciation',
    'Direct Expense', 'Direct Income', 'Equity', 'Expense Account', 'Expenses Included In Asset Valuation',
    'Expenses Included In Valuation', 'Fixed Asset', 'Income Account', 'Indirect Expense', 'Indirect Income',
    'Liability', 'Payable', 'Receivable', 'Round Off', 'Round Off for Opening', 'Stock', 'Stock Adjustment',
    'Stock Received But Not Billed', 'Stock Delivered But Not Billed', 'Service Received But Not Billed', 'Tax',
    'Temporary'
  )),
  tax_rate           numeric(21,9) not null default 0,
  freeze_account     text not null default 'No' check (freeze_account in ('No', 'Yes')),
  balance_must_be    text not null default '' check (balance_must_be in ('', 'Debit', 'Credit')),
  include_in_gross   boolean not null default false,
  account_category_id uuid,
  disabled           boolean not null default false,
  path               extensions.ltree not null,
  created_at         timestamptz not null default now(),
  created_by         uuid default auth.uid(),
  updated_at         timestamptz not null default now(),
  updated_by         uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, parent_id) references public.account (org_id, id),
  foreign key (org_id, account_category_id) references public.account_category (org_id, id)
);

create unique index if not exists account_number_uniq
  on public.account (org_id, company_id, account_number) where account_number is not null;
create index if not exists account_parent_idx on public.account (org_id, parent_id);
create index if not exists account_company_idx on public.account (org_id, company_id);
create index if not exists account_category_idx on public.account (org_id, account_category_id);
create index if not exists account_path_idx on public.account using gist (path);

create or replace function app.account_display_name(p_number text, p_name text, p_abbr text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when nullif(trim(p_number), '') is not null then trim(p_number) || ' - ' || trim(p_name) || ' - ' || p_abbr
    else trim(p_name) || ' - ' || p_abbr
  end;
$$;

create or replace function app.account_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_company uuid;
  v_currency text;
  v_base text;
  v_name text;
  v_n int;
begin
  new.account_name := trim(new.account_name);
  if tg_op = 'UPDATE' and new.company_id is distinct from old.company_id then
    raise exception using errcode = 'P0001', message = 'account_company: Company cannot be changed for an existing account';
  end if;
  if new.parent_id is null and new.root_type is null then
    raise exception using errcode = 'P0001', message = 'root_type_required: Root Type is mandatory';
  end if;
  if new.parent_id is not null then
    select company_id into v_parent_company from public.account where id = new.parent_id and org_id = new.org_id;
    if v_parent_company is distinct from new.company_id then
      raise exception using errcode = 'P0001', message = 'account_parent_company: Parent account must belong to the same company';
    end if;
  end if;
  new.report_type := case
    when new.root_type in ('Asset', 'Liability', 'Equity') then 'Balance Sheet'
    else 'Profit and Loss'
  end;
  select default_currency into v_currency from public.companies where id = new.company_id;
  if new.account_currency is null or new.account_currency = '' then
    new.account_currency := v_currency;
  elsif new.account_currency is distinct from v_currency then
    raise exception using errcode = 'P0001', message = 'account_currency: Account currency must be the company currency';
  end if;
  v_base := app.account_display_name(new.account_number, new.account_name, (
    select abbr from public.companies where id = new.company_id
  ));
  v_name := v_base;
  v_n := 1;
  while exists (
    select 1 from public.account a
    where a.org_id = new.org_id and a.name = v_name and a.id is distinct from new.id
  ) loop
    v_name := v_base || ' ' || v_n;
    v_n := v_n + 1;
  end loop;
  new.name := v_name;
  return new;
end;
$$;

-- One row per chart node, in file order, with the fields the preview omits.
create or replace function app.coa_template_nodes(p_template text)
returns table (
  idx int, node_key text, parent_key text, account_name text, is_group boolean, root_type text,
  account_type text, account_number text, account_category text, tax_rate numeric
)
language sql
stable
set search_path = ''
as $$
  with recursive nodes as (
    select e.key as account_name, e.value as node, null::text as parent_key,
           e.value ->> 'root_type' as root_type, array[e.ord] as path, 'r' || e.ord::text as node_key
      from public.coa_template t, json_each(t.tree) with ordinality e(key, value, ord)
     where t.name = p_template and json_typeof(e.value) = 'object'
       and e.key <> all (array['account_name', 'account_number', 'account_type', 'account_category', 'root_type',
                               'is_group', 'tax_rate', 'account_currency'])
    union all
    select c.key, c.value, n.node_key, coalesce(c.value ->> 'root_type', n.root_type), n.path || c.ord,
           n.node_key || '.' || c.ord::text
      from nodes n, json_each(n.node) with ordinality c(key, value, ord)
     where json_typeof(c.value) = 'object'
       and c.key <> all (array['account_name', 'account_number', 'account_type', 'account_category', 'root_type',
                               'is_group', 'tax_rate', 'account_currency'])
  )
  select row_number() over (order by path)::int,
         node_key,
         parent_key,
         account_name,
         coalesce(nullif(node ->> 'is_group', '') not in ('0', 'false'), false)
           or exists (select 1 from json_object_keys(node) k
                       where k <> all (array['account_name', 'account_number', 'account_type', 'account_category',
                                             'root_type', 'is_group', 'tax_rate', 'account_currency'])),
         root_type,
         nullif(node ->> 'account_type', ''),
         nullif(trim(node ->> 'account_number'), ''),
         nullif(node ->> 'account_category', ''),
         coalesce(nullif(node ->> 'tax_rate', '')::numeric, 0)
    from nodes
   order by path;
$$;

create or replace function app.create_charts(p_company uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_abbr text;
  v_currency text;
  v_template text;
  v_based_on text;
  v_parent uuid;
  r record;
  v_map jsonb := '{}'::jsonb;
  v_parent_id uuid;
  v_category uuid;
  v_id uuid;
begin
  select org_id, abbr, default_currency, coalesce(nullif(chart_of_accounts, ''), 'Standard'),
         create_chart_of_accounts_based_on, parent_id
    into v_org, v_abbr, v_currency, v_template, v_based_on, v_parent
  from public.companies where id = p_company;

  if exists (select 1 from public.account where company_id = p_company) then
    return;
  end if;

  if v_based_on = 'Existing Company' and v_parent is not null then
    for r in
      select a.* from public.account a where a.company_id = v_parent order by a.path
    loop
      v_parent_id := null;
      if r.parent_id is not null then
        v_parent_id := (v_map ->> r.parent_id::text)::uuid;
      end if;
      insert into public.account (
        org_id, account_name, account_number, is_group, company_id, root_type, account_currency,
        parent_id, account_type, tax_rate, account_category_id, disabled
      ) values (
        v_org, r.account_name, r.account_number, r.is_group, p_company, r.root_type, v_currency,
        v_parent_id, r.account_type, r.tax_rate, r.account_category_id, r.disabled
      ) returning id into v_id;
      v_map := v_map || jsonb_build_object(r.id::text, v_id);
    end loop;
    return;
  end if;

  for r in select * from app.coa_template_nodes(v_template) order by idx loop
    v_parent_id := null;
    if r.parent_key is not null then
      v_parent_id := (v_map ->> r.parent_key)::uuid;
    end if;
    v_category := null;
    if r.account_category is not null then
      select id into v_category from public.account_category
      where org_id = v_org and lower(account_category_name) = lower(r.account_category);
    end if;
    insert into public.account (
      org_id, account_name, account_number, is_group, company_id, root_type, account_currency,
      parent_id, account_type, tax_rate, account_category_id
    ) values (
      v_org, r.account_name, r.account_number, r.is_group, p_company, r.root_type, v_currency,
      v_parent_id, r.account_type, r.tax_rate, v_category
    ) returning id into v_id;
    v_map := v_map || jsonb_build_object(r.node_key, v_id);
  end loop;
end;
$$;

create or replace function app._account_by_type(p_company uuid, p_type text, p_root text default null)
returns uuid
language sql
stable
set search_path = ''
as $$
  select id from public.account
  where company_id = p_company and is_group = false and account_type = p_type
    and (p_root is null or root_type = p_root)
  order by name
  limit 1;
$$;

create or replace function app._account_by_name(p_company uuid, p_name text)
returns uuid
language sql
stable
set search_path = ''
as $$
  select id from public.account
  where company_id = p_company and is_group = false and account_name = p_name
  order by name
  limit 1;
$$;

create or replace function app.set_default_accounts(p_company uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.companies c set
    default_receivable_account_id = app._account_by_type(c.id, 'Receivable', 'Asset'),
    default_payable_account_id = app._account_by_type(c.id, 'Payable', 'Liability'),
    default_cash_account_id = app._account_by_type(c.id, 'Cash'),
    default_bank_account_id = coalesce(c.default_bank_account_id, app._account_by_type(c.id, 'Bank')),
    round_off_account_id = app._account_by_type(c.id, 'Round Off'),
    accumulated_depreciation_account_id = app._account_by_type(c.id, 'Accumulated Depreciation'),
    depreciation_expense_account_id = app._account_by_type(c.id, 'Depreciation'),
    capital_work_in_progress_account_id = app._account_by_type(c.id, 'Capital Work in Progress'),
    asset_received_but_not_billed_id = app._account_by_type(c.id, 'Asset Received But Not Billed'),
    default_expense_account_id = app._account_by_type(c.id, 'Cost of Goods Sold'),
    stock_received_but_not_billed_id = app._account_by_type(c.id, 'Stock Received But Not Billed'),
    stock_delivered_but_not_billed_id = app._account_by_type(c.id, 'Stock Delivered But Not Billed'),
    default_inventory_account_id = coalesce(
      app._account_by_name(c.id, 'Stock In Hand'),
      app._account_by_type(c.id, 'Stock')
    ),
    stock_adjustment_account_id = app._account_by_type(c.id, 'Stock Adjustment'),
    default_income_account_id = coalesce(
      app._account_by_name(c.id, 'Sales'),
      app._account_by_name(c.id, 'Sales Account'),
      app._account_by_type(c.id, 'Income Account')
    ),
    write_off_account_id = app._account_by_name(c.id, 'Write Off'),
    bank_charges_account_id = app._account_by_name(c.id, 'Bank Charges'),
    exchange_gain_loss_account_id = app._account_by_name(c.id, 'Exchange Gain/Loss'),
    exchange_gain_account_id = app._account_by_name(c.id, 'Exchange Gain'),
    exchange_loss_account_id = app._account_by_name(c.id, 'Exchange Loss'),
    disposal_account_id = app._account_by_name(c.id, 'Gain/Loss on Asset Disposal')
  where c.id = p_company;
end;
$$;

create or replace function app.companies_seed_accounts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.create_charts(new.id);
  perform app.set_default_accounts(new.id);
  return null;
end;
$$;

revoke execute on function
  app.account_display_name(text, text, text), app.account_validate(), app.coa_template_nodes(text),
  app.create_charts(uuid), app._account_by_type(uuid, text, text), app._account_by_name(uuid, text),
  app.set_default_accounts(uuid), app.companies_seed_accounts()
from public, anon, authenticated;

drop trigger if exists account_validate on public.account;
create trigger account_validate before insert or update on public.account
  for each row execute function app.account_validate();
drop trigger if exists tree_path on public.account;
create trigger tree_path before insert or update on public.account
  for each row execute function app.tree_maintain_path('Account');
drop trigger if exists tree_path_descendants on public.account;
create trigger tree_path_descendants after update on public.account
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.account;
create trigger touch_updated before update on public.account
  for each row execute function app.touch_updated();

drop trigger if exists companies_seed_accounts on public.companies;
create trigger companies_seed_accounts after insert on public.companies
  for each row execute function app.companies_seed_accounts();

select app.create_charts(c.id) from public.companies c;
select app.set_default_accounts(c.id) from public.companies c;

alter table public.account enable row level security;
alter table public.account force row level security;
drop policy if exists account_select on public.account;
create policy account_select on public.account for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Account', 'read'))::uuid[]));
drop policy if exists account_insert on public.account;
create policy account_insert on public.account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Account', 'create'))::uuid[]));
drop policy if exists account_update on public.account;
create policy account_update on public.account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Account', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Account', 'write'))::uuid[]));
drop policy if exists account_delete on public.account;
create policy account_delete on public.account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Account', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Account', 'account', 'accounts', true, 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Account', true, false, false, false),
  ('Accounts User', 'Account', true, true, true, true),
  ('Accounts Manager', 'Account', true, true, true, true),
  ('Auditor', 'Account', true, false, false, false),
  ('Sales User', 'Account', true, false, false, false),
  ('Purchase User', 'Account', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

-- Cover the composite foreign keys below. The other default-account columns stay plain uuid.
create index if not exists companies_receivable_account_idx on public.companies (org_id, default_receivable_account_id);
create index if not exists companies_payable_account_idx on public.companies (org_id, default_payable_account_id);
create index if not exists companies_cash_account_idx on public.companies (org_id, default_cash_account_id);
create index if not exists companies_bank_account_idx on public.companies (org_id, default_bank_account_id);
create index if not exists companies_expense_account_idx on public.companies (org_id, default_expense_account_id);
create index if not exists companies_income_account_idx on public.companies (org_id, default_income_account_id);
create index if not exists companies_round_off_account_idx on public.companies (org_id, round_off_account_id);
create index if not exists companies_write_off_account_idx on public.companies (org_id, write_off_account_id);
create index if not exists companies_inventory_account_idx on public.companies (org_id, default_inventory_account_id);
create index if not exists companies_stock_adjustment_idx on public.companies (org_id, stock_adjustment_account_id);
create index if not exists companies_srbnb_idx on public.companies (org_id, stock_received_but_not_billed_id);

-- Company default-account columns now point at real accounts.
alter table public.companies
  add constraint companies_receivable_account_fk foreign key (org_id, default_receivable_account_id) references public.account (org_id, id),
  add constraint companies_payable_account_fk foreign key (org_id, default_payable_account_id) references public.account (org_id, id),
  add constraint companies_cash_account_fk foreign key (org_id, default_cash_account_id) references public.account (org_id, id),
  add constraint companies_bank_account_fk foreign key (org_id, default_bank_account_id) references public.account (org_id, id),
  add constraint companies_expense_account_fk foreign key (org_id, default_expense_account_id) references public.account (org_id, id),
  add constraint companies_income_account_fk foreign key (org_id, default_income_account_id) references public.account (org_id, id),
  add constraint companies_round_off_account_fk foreign key (org_id, round_off_account_id) references public.account (org_id, id),
  add constraint companies_write_off_account_fk foreign key (org_id, write_off_account_id) references public.account (org_id, id),
  add constraint companies_inventory_account_fk foreign key (org_id, default_inventory_account_id) references public.account (org_id, id),
  add constraint companies_stock_adjustment_fk foreign key (org_id, stock_adjustment_account_id) references public.account (org_id, id),
  add constraint companies_srbnb_fk foreign key (org_id, stock_received_but_not_billed_id) references public.account (org_id, id);
