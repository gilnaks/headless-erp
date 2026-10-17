-- 0235 selling: Customer (docs/modules/02-selling.md §2.1–2.2, §2.6; 01-accounts §2.9, §3.5).
-- ERPNext: erpnext/selling/doctype/customer/customer.py autoname and validate;
-- erpnext/accounts/party.py validate_party_accounts.
-- Naming Series waits for Selling Settings. Supplier party accounts wait for Supplier.
-- The GL-currency override waits for the ledger.

alter table public.customer_group
  add column if not exists default_price_list_id uuid,
  add column if not exists payment_terms_id uuid;

alter table public.customer_group drop constraint if exists customer_group_price_list_fk;
alter table public.customer_group
  add constraint customer_group_price_list_fk
  foreign key (org_id, default_price_list_id) references public.price_list (org_id, id)
  on delete set null (default_price_list_id);
alter table public.customer_group drop constraint if exists customer_group_payment_terms_fk;
alter table public.customer_group
  add constraint customer_group_payment_terms_fk
  foreign key (org_id, payment_terms_id) references public.payment_terms_template (org_id, id)
  on delete set null (payment_terms_id);

create index if not exists customer_group_price_list_idx on public.customer_group (org_id, default_price_list_id);
create index if not exists customer_group_payment_terms_idx on public.customer_group (org_id, payment_terms_id);

create table if not exists public.customer (
  id                       uuid primary key default gen_random_uuid(),
  org_id                   uuid not null references public.organizations (id) on delete cascade,
  name                     text not null,
  customer_name            text not null check (length(trim(customer_name)) > 0),
  customer_type            text not null default 'Company' check (customer_type in ('Company', 'Individual', 'Partnership')),
  customer_group_id        uuid,
  territory_id             uuid,
  tax_id                   text,
  tax_category_id          uuid,
  default_currency         text,
  default_price_list_id    uuid,
  language                 text,
  website                  text,
  customer_primary_contact uuid,
  customer_primary_address uuid,
  payment_terms_id         uuid,
  customer_details         text,
  industry_id              uuid,
  disabled                 boolean not null default false,
  is_frozen                boolean not null default false,
  on_hold                  boolean not null default false,
  release_date             date,
  so_required              boolean not null default false,
  dn_required              boolean not null default false,
  alias                    text,
  created_at               timestamptz not null default now(),
  created_by               uuid default auth.uid(),
  updated_at               timestamptz not null default now(),
  updated_by               uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, customer_group_id) references public.customer_group (org_id, id),
  foreign key (org_id, territory_id) references public.territory (org_id, id),
  foreign key (org_id, tax_category_id) references public.tax_category (org_id, id)
    on delete set null (tax_category_id),
  foreign key (org_id, default_price_list_id) references public.price_list (org_id, id)
    on delete set null (default_price_list_id),
  foreign key (org_id, customer_primary_contact) references public.contact (org_id, id)
    on delete set null (customer_primary_contact),
  foreign key (org_id, customer_primary_address) references public.address (org_id, id)
    on delete set null (customer_primary_address),
  foreign key (org_id, payment_terms_id) references public.payment_terms_template (org_id, id)
    on delete set null (payment_terms_id),
  foreign key (org_id, industry_id) references public.industry_type (org_id, id)
    on delete set null (industry_id)
);

create unique index if not exists customer_alias_uniq on public.customer (org_id, lower(alias)) where alias is not null;
create index if not exists customer_group_idx on public.customer (org_id, customer_group_id);
create index if not exists customer_territory_idx on public.customer (org_id, territory_id);
create index if not exists customer_tax_category_idx on public.customer (org_id, tax_category_id);
create index if not exists customer_price_list_idx on public.customer (org_id, default_price_list_id);
create index if not exists customer_contact_idx on public.customer (org_id, customer_primary_contact);
create index if not exists customer_address_idx on public.customer (org_id, customer_primary_address);
create index if not exists customer_payment_terms_idx on public.customer (org_id, payment_terms_id);
create index if not exists customer_industry_idx on public.customer (org_id, industry_id);

create table if not exists public.customer_party_account (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  parent_id  uuid not null,
  idx        int not null,
  company_id uuid not null,
  account_id uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.customer (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, account_id) references public.account (org_id, id) on delete cascade
);

create table if not exists public.customer_group_party_account (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  parent_id  uuid not null,
  idx        int not null,
  company_id uuid not null,
  account_id uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.customer_group (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, account_id) references public.account (org_id, id) on delete cascade
);

create table if not exists public.customer_credit_limit (
  id                        uuid primary key default gen_random_uuid(),
  org_id                    uuid not null references public.organizations (id) on delete cascade,
  parent_id                 uuid not null,
  idx                       int not null,
  company_id                uuid not null,
  credit_limit              numeric(21,9) not null default 0,
  bypass_credit_limit_check boolean not null default false,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.customer (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade
);

create table if not exists public.customer_group_credit_limit (
  id                        uuid primary key default gen_random_uuid(),
  org_id                    uuid not null references public.organizations (id) on delete cascade,
  parent_id                 uuid not null,
  idx                       int not null,
  company_id                uuid not null,
  credit_limit              numeric(21,9) not null default 0,
  bypass_credit_limit_check boolean not null default false,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.customer_group (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade
);

create table if not exists public.customer_sales_team (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references public.organizations (id) on delete cascade,
  parent_id            uuid not null,
  idx                  int not null,
  sales_person_id      uuid not null,
  allocated_percentage numeric(21,9) not null default 0,
  commission_rate      numeric(21,9),
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.customer (org_id, id) on delete cascade,
  foreign key (org_id, sales_person_id) references public.sales_person (org_id, id) on delete cascade
);

create index if not exists customer_party_account_parent_idx on public.customer_party_account (org_id, parent_id);
create index if not exists customer_party_account_company_idx on public.customer_party_account (org_id, company_id);
create index if not exists customer_party_account_account_idx on public.customer_party_account (org_id, account_id);
create index if not exists customer_group_party_account_parent_idx on public.customer_group_party_account (org_id, parent_id);
create index if not exists customer_group_party_account_company_idx on public.customer_group_party_account (org_id, company_id);
create index if not exists customer_group_party_account_account_idx on public.customer_group_party_account (org_id, account_id);
create index if not exists customer_credit_limit_parent_idx on public.customer_credit_limit (org_id, parent_id);
create index if not exists customer_credit_limit_company_idx on public.customer_credit_limit (org_id, company_id);
create index if not exists customer_group_credit_limit_parent_idx on public.customer_group_credit_limit (org_id, parent_id);
create index if not exists customer_group_credit_limit_company_idx on public.customer_group_credit_limit (org_id, company_id);
create index if not exists customer_sales_team_parent_idx on public.customer_sales_team (org_id, parent_id);
create index if not exists customer_sales_team_person_idx on public.customer_sales_team (org_id, sales_person_id);

-- Keeps the shipped parent default and adds the in-use and selling-list checks.
create or replace function app.customer_group_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_selling boolean;
begin
  new.customer_group_name := trim(new.customer_group_name);
  if new.parent_id is null and new.customer_group_name <> 'All Customer Groups' then
    select id into new.parent_id from public.customer_group
    where org_id = new.org_id and parent_id is null;
  end if;
  if tg_op = 'UPDATE' and new.is_group and not old.is_group and exists (
    select 1 from public.customer c where c.customer_group_id = new.id
  ) then
    raise exception using errcode = 'P0001',
      message = 'customer_group_in_use: A Customer Group selected on a customer cannot become a group';
  end if;
  if new.default_price_list_id is not null then
    select selling into v_selling from public.price_list where id = new.default_price_list_id;
    if not coalesce(v_selling, false) then
      raise exception using errcode = 'P0001',
        message = 'customer_price_list: Default price list must be a selling list';
    end if;
  end if;
  return new;
end;
$$;

create or replace function app.customer_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group boolean;
  v_selling boolean;
  v_base text;
  v_like text;
  v_n int;
begin
  new.customer_name := trim(new.customer_name);
  if not new.on_hold then
    new.release_date := null;
  end if;
  if new.customer_group_id is not null then
    select is_group into v_group from public.customer_group where id = new.customer_group_id;
    if coalesce(v_group, false) then
      raise exception using errcode = 'P0001',
        message = 'customer_group_leaf: Cannot select a group type Customer Group';
    end if;
  end if;
  if new.default_price_list_id is not null then
    select selling into v_selling from public.price_list where id = new.default_price_list_id;
    if not coalesce(v_selling, false) then
      raise exception using errcode = 'P0001',
        message = 'customer_price_list: Default price list must be a selling list';
    end if;
  end if;
  if tg_op = 'INSERT' or new.customer_name is distinct from old.customer_name then
    v_base := new.customer_name;
    if not exists (
      select 1 from public.customer c
       where c.org_id = new.org_id and c.name = v_base and c.id is distinct from new.id
    ) then
      new.name := v_base;
    else
      v_like := replace(replace(replace(v_base, '\', '\\'), '%', '\%'), '_', '\_') || ' - %';
      select coalesce(max(
        case
          when c.name = v_base then 1
          when substring(c.name from char_length(v_base) + 4) ~ '^[0-9]+$'
            then substring(c.name from char_length(v_base) + 4)::int
          else 0
        end
      ), 1) + 1 into v_n
      from public.customer c
      where c.org_id = new.org_id
        and c.id is distinct from new.id
        and (c.name = v_base or c.name like v_like escape '\');
      new.name := v_base || ' - ' || v_n;
    end if;
  end if;
  return new;
end;
$$;

create or replace function app.party_account_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company uuid;
  v_type text;
  v_group boolean;
  v_expect text := tg_argv[0];
begin
  if new.account_id is null then
    return new;
  end if;
  select company_id, account_type, is_group into v_company, v_type, v_group
    from public.account where id = new.account_id;
  if v_company is distinct from new.company_id or v_type is distinct from v_expect or coalesce(v_group, false) then
    raise exception using errcode = 'P0001',
      message = format('party_account_type: Row %s: Account must be a %s account', new.idx, v_expect);
  end if;
  return new;
end;
$$;

create or replace function app.customer_sales_team_refresh(p_customer uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sum numeric;
  v_disabled text;
begin
  if p_customer is null or not exists (select 1 from public.customer where id = p_customer) then
    return;
  end if;
  if exists (select 1 from public.customer_sales_team where parent_id = p_customer) then
    select coalesce(sum(allocated_percentage), 0) into v_sum
      from public.customer_sales_team where parent_id = p_customer;
    if v_sum <> 100 then
      raise exception using errcode = 'P0001',
        message = 'sales_team_total: Total contribution percentage should be equal to 100';
    end if;
  end if;
  select s.sales_person_name into v_disabled
    from public.customer_sales_team t
    join public.sales_person s on s.id = t.sales_person_id
   where t.parent_id = p_customer and not s.enabled
   limit 1;
  if found then
    raise exception using errcode = 'P0001',
      message = format('sales_person_disabled: Sales Person %s is disabled', v_disabled);
  end if;
end;
$$;

create or replace function app.customer_sales_team_refresh_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.customer_sales_team_refresh(coalesce(new.parent_id, old.parent_id));
  return null;
end;
$$;

create or replace function app.get_party_account(p_party_type text, p_party uuid, p_company uuid)
returns uuid
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_account uuid;
  v_group uuid;
  v_company_name text;
begin
  if p_party_type = 'Customer' then
    select account_id into v_account from public.customer_party_account
     where parent_id = p_party and company_id = p_company and account_id is not null;
    if v_account is not null then
      return v_account;
    end if;
    select customer_group_id into v_group from public.customer where id = p_party;
    select account_id into v_account from public.customer_group_party_account
     where parent_id = v_group and company_id = p_company and account_id is not null;
    if v_account is not null then
      return v_account;
    end if;
    select default_receivable_account_id, company_name into v_account, v_company_name
      from public.companies where id = p_company;
    if v_account is null then
      raise exception using errcode = 'P0001',
        message = format('party_account_missing: Please set default Receivable account in Company %s', v_company_name);
    end if;
  end if;
  return v_account;
end;
$$;

create or replace function app.get_customer_group_details(p_customer uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_org uuid;
  v_group uuid;
begin
  select org_id, customer_group_id into v_org, v_group from public.customer where id = p_customer;
  if v_group is null then
    return;
  end if;
  update public.customer c
     set default_price_list_id = g.default_price_list_id,
         payment_terms_id = g.payment_terms_id
    from public.customer_group g
   where c.id = p_customer and g.id = v_group;
  delete from public.customer_party_account where parent_id = p_customer;
  insert into public.customer_party_account (org_id, parent_id, idx, company_id, account_id)
  select v_org, p_customer, a.idx, a.company_id, a.account_id
    from public.customer_group_party_account a
   where a.parent_id = v_group;
  delete from public.customer_credit_limit where parent_id = p_customer;
  insert into public.customer_credit_limit (org_id, parent_id, idx, company_id, credit_limit, bypass_credit_limit_check)
  select v_org, p_customer, l.idx, l.company_id, l.credit_limit, l.bypass_credit_limit_check
    from public.customer_group_credit_limit l
   where l.parent_id = v_group;
end;
$$;

create or replace function public.get_party_account(p_party_type text, p_party uuid, p_company uuid)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select app.get_party_account(p_party_type, p_party, p_company);
$$;

create or replace function public.get_customer_group_details(p_customer uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.get_customer_group_details(p_customer);
$$;

revoke all on function app.customer_validate() from public, anon, authenticated;
revoke all on function app.party_account_validate() from public, anon, authenticated;
revoke all on function app.customer_sales_team_refresh(uuid) from public, anon, authenticated;
revoke all on function app.customer_sales_team_refresh_trigger() from public, anon, authenticated;
revoke all on function app.get_party_account(text, uuid, uuid) from public, anon;
grant execute on function app.get_party_account(text, uuid, uuid) to authenticated;
revoke all on function public.get_party_account(text, uuid, uuid) from public, anon;
grant execute on function public.get_party_account(text, uuid, uuid) to authenticated;
revoke all on function app.get_customer_group_details(uuid) from public, anon;
grant execute on function app.get_customer_group_details(uuid) to authenticated;
revoke all on function public.get_customer_group_details(uuid) from public, anon;
grant execute on function public.get_customer_group_details(uuid) to authenticated;

drop trigger if exists customer_validate on public.customer;
create trigger customer_validate before insert or update on public.customer
  for each row execute function app.customer_validate();
drop trigger if exists touch_updated on public.customer;
create trigger touch_updated before update on public.customer
  for each row execute function app.touch_updated();

drop trigger if exists customer_party_account_validate on public.customer_party_account;
create trigger customer_party_account_validate before insert or update on public.customer_party_account
  for each row execute function app.party_account_validate('Receivable');
drop trigger if exists customer_group_party_account_validate on public.customer_group_party_account;
create trigger customer_group_party_account_validate before insert or update on public.customer_group_party_account
  for each row execute function app.party_account_validate('Receivable');

drop trigger if exists customer_sales_team_refresh on public.customer_sales_team;
create constraint trigger customer_sales_team_refresh
  after insert or update or delete on public.customer_sales_team
  deferrable initially deferred
  for each row execute function app.customer_sales_team_refresh_trigger();

alter table public.customer enable row level security;
alter table public.customer force row level security;
alter table public.customer_party_account enable row level security;
alter table public.customer_party_account force row level security;
alter table public.customer_group_party_account enable row level security;
alter table public.customer_group_party_account force row level security;
alter table public.customer_credit_limit enable row level security;
alter table public.customer_credit_limit force row level security;
alter table public.customer_group_credit_limit enable row level security;
alter table public.customer_group_credit_limit force row level security;
alter table public.customer_sales_team enable row level security;
alter table public.customer_sales_team force row level security;

drop policy if exists customer_select on public.customer;
create policy customer_select on public.customer for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'read'))::uuid[]));
drop policy if exists customer_insert on public.customer;
create policy customer_insert on public.customer for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'create'))::uuid[]));
drop policy if exists customer_update on public.customer;
create policy customer_update on public.customer for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]));
drop policy if exists customer_delete on public.customer;
create policy customer_delete on public.customer for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'delete'))::uuid[]));

drop policy if exists customer_party_account_select on public.customer_party_account;
create policy customer_party_account_select on public.customer_party_account for select to authenticated
  using (exists (select 1 from public.customer p where p.id = parent_id));
drop policy if exists customer_party_account_insert on public.customer_party_account;
create policy customer_party_account_insert on public.customer_party_account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Customer', 'create'))::uuid[]));
drop policy if exists customer_party_account_update on public.customer_party_account;
create policy customer_party_account_update on public.customer_party_account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]));
drop policy if exists customer_party_account_delete on public.customer_party_account;
create policy customer_party_account_delete on public.customer_party_account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]));

drop policy if exists customer_group_party_account_select on public.customer_group_party_account;
create policy customer_group_party_account_select on public.customer_group_party_account for select to authenticated
  using (exists (
    select 1 from public.customer_group p
    where p.id = customer_group_party_account.parent_id
  ));
drop policy if exists customer_group_party_account_insert on public.customer_group_party_account;
create policy customer_group_party_account_insert on public.customer_group_party_account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Customer Group', 'create'))::uuid[]));
drop policy if exists customer_group_party_account_update on public.customer_group_party_account;
create policy customer_group_party_account_update on public.customer_group_party_account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]));
drop policy if exists customer_group_party_account_delete on public.customer_group_party_account;
create policy customer_group_party_account_delete on public.customer_group_party_account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]));

drop policy if exists customer_credit_limit_select on public.customer_credit_limit;
create policy customer_credit_limit_select on public.customer_credit_limit for select to authenticated
  using (exists (select 1 from public.customer p where p.id = parent_id));
drop policy if exists customer_credit_limit_insert on public.customer_credit_limit;
create policy customer_credit_limit_insert on public.customer_credit_limit for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Customer', 'create'))::uuid[]));
drop policy if exists customer_credit_limit_update on public.customer_credit_limit;
create policy customer_credit_limit_update on public.customer_credit_limit for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]));
drop policy if exists customer_credit_limit_delete on public.customer_credit_limit;
create policy customer_credit_limit_delete on public.customer_credit_limit for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]));

drop policy if exists customer_group_credit_limit_select on public.customer_group_credit_limit;
create policy customer_group_credit_limit_select on public.customer_group_credit_limit for select to authenticated
  using (exists (
    select 1 from public.customer_group p
    where p.id = customer_group_credit_limit.parent_id
  ));
drop policy if exists customer_group_credit_limit_insert on public.customer_group_credit_limit;
create policy customer_group_credit_limit_insert on public.customer_group_credit_limit for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Customer Group', 'create'))::uuid[]));
drop policy if exists customer_group_credit_limit_update on public.customer_group_credit_limit;
create policy customer_group_credit_limit_update on public.customer_group_credit_limit for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]));
drop policy if exists customer_group_credit_limit_delete on public.customer_group_credit_limit;
create policy customer_group_credit_limit_delete on public.customer_group_credit_limit for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer Group', 'write'))::uuid[]));

drop policy if exists customer_sales_team_select on public.customer_sales_team;
create policy customer_sales_team_select on public.customer_sales_team for select to authenticated
  using (exists (select 1 from public.customer p where p.id = parent_id));
drop policy if exists customer_sales_team_insert on public.customer_sales_team;
create policy customer_sales_team_insert on public.customer_sales_team for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Customer', 'create'))::uuid[]));
drop policy if exists customer_sales_team_update on public.customer_sales_team;
create policy customer_sales_team_update on public.customer_sales_team for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]));
drop policy if exists customer_sales_team_delete on public.customer_sales_team;
create policy customer_sales_team_delete on public.customer_sales_team for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Customer', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Customer', 'customer', 'selling', 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Party Account', 'customer_party_account', 'accounts', true, 'Customer', 'accounts'),
  ('Customer Credit Limit', 'customer_credit_limit', 'selling', true, 'Customer', 'credit_limits'),
  ('Sales Team', 'customer_sales_team', 'selling', true, 'Customer', 'sales_team'),
  ('Customer Group Account', 'customer_group_party_account', 'accounts', true, 'Customer Group', 'accounts'),
  ('Customer Group Credit Limit', 'customer_group_credit_limit', 'selling', true, 'Customer Group', 'credit_limits')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Customer', true, false, false, false),
  ('Sales User', 'Customer', true, true, true, false),
  ('Sales Manager', 'Customer', true, true, true, true),
  ('Stock User', 'Customer', true, false, false, false),
  ('Stock Manager', 'Customer', true, false, false, false),
  ('Accounts User', 'Customer', true, false, false, false),
  ('Accounts Manager', 'Customer', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
