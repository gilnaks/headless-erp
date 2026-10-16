-- 0218 accounts: Mode of Payment (docs/modules/01-accounts.md §2.5, 00-setup A11 B10).
-- ERPNext: erpnext/accounts/doctype/mode_of_payment/mode_of_payment.{json,py,js},
-- mode_of_payment_account/mode_of_payment_account.json,
-- erpnext/setup/setup_wizard/operations/install_fixtures.py,
-- erpnext/setup/doctype/company/company.py (set_mode_of_payment_account).
-- POS profile checks are out of scope.

create table if not exists public.mode_of_payment (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  name             text not null,
  mode_of_payment  text not null check (length(trim(mode_of_payment)) > 0),
  enabled          boolean not null default true,
  type             text check (type is null or type in ('Cash', 'Bank', 'General', 'Phone')),
  created_at       timestamptz not null default now(),
  created_by       uuid default auth.uid(),
  updated_at       timestamptz not null default now(),
  updated_by       uuid,
  unique (org_id, id)
);

create unique index if not exists mode_of_payment_name_uniq on public.mode_of_payment (org_id, lower(mode_of_payment));

create table if not exists public.mode_of_payment_account (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null,
  parent_id          uuid not null,
  idx                int not null,
  company_id         uuid not null,
  default_account_id uuid,
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.mode_of_payment (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, default_account_id) references public.account (org_id, id)
);

create index if not exists mode_of_payment_account_parent_idx on public.mode_of_payment_account (org_id, parent_id);
create index if not exists mode_of_payment_account_company_idx on public.mode_of_payment_account (org_id, company_id);
create index if not exists mode_of_payment_account_account_idx on public.mode_of_payment_account (org_id, default_account_id);

create or replace function app.mode_of_payment_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.mode_of_payment := trim(new.mode_of_payment);
  new.name := new.mode_of_payment;
  new.type := nullif(new.type, '');
  return new;
end;
$$;

create or replace function app.mode_of_payment_account_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_company uuid;
begin
  if exists (
    select 1 from public.mode_of_payment_account a
    where a.parent_id = new.parent_id
      and a.company_id = new.company_id
      and a.id is distinct from new.id
  ) then
    raise exception using errcode = 'P0001',
      message = 'mode_of_payment_company: Same Company is entered more than once';
  end if;
  if new.default_account_id is null then
    return new;
  end if;
  select company_id into v_company
    from public.account
   where id = new.default_account_id and org_id = new.org_id;
  if v_company is distinct from new.company_id then
    raise exception using errcode = 'P0001',
      message = 'mode_of_payment_account: Account does not match with Company in Mode of Payment';
  end if;
  return new;
end;
$$;

-- A11. Cheque is Check in the United States.
create or replace function app.seed_modes_of_payment(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_country text;
  v_cheque text;
begin
  select country into v_country from public.organizations where id = p_org;
  v_cheque := case when v_country = 'United States' then 'Check' else 'Cheque' end;
  insert into public.mode_of_payment (org_id, mode_of_payment, type)
  values
    (p_org, v_cheque, 'Bank'),
    (p_org, 'Cash', 'Cash'),
    (p_org, 'Credit Card', 'Bank'),
    (p_org, 'Wire Transfer', 'Bank'),
    (p_org, 'Bank Draft', 'Bank')
  on conflict (org_id, lower(mode_of_payment)) do nothing;
end;
$$;

create or replace function app.organizations_seed_modes_of_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_modes_of_payment(new.id);
  return null;
end;
$$;

-- B10. Link Cash to the company cash account when that company has no row yet.
-- companies_seed_mode_of_payment sorts after companies_seed_accounts, so the cash account exists.
create or replace function app.set_mode_of_payment_account(p_company uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_cash_account uuid;
  v_mode uuid;
begin
  select org_id, default_cash_account_id into v_org, v_cash_account from public.companies where id = p_company;
  if v_cash_account is null then
    return;
  end if;
  select id into v_mode from public.mode_of_payment
   where org_id = v_org and mode_of_payment = 'Cash';
  if v_mode is null then
    return;
  end if;
  if exists (
    select 1 from public.mode_of_payment_account
    where parent_id = v_mode and company_id = p_company
  ) then
    return;
  end if;
  insert into public.mode_of_payment_account (org_id, parent_id, idx, company_id, default_account_id)
  values (
    v_org, v_mode,
    coalesce((select max(a.idx) from public.mode_of_payment_account a where a.parent_id = v_mode), 0) + 1,
    p_company, v_cash_account
  );
end;
$$;

create or replace function app.companies_seed_mode_of_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.set_mode_of_payment_account(new.id);
  return null;
end;
$$;

revoke execute on function
  app.mode_of_payment_validate(), app.mode_of_payment_account_validate(),
  app.seed_modes_of_payment(uuid), app.organizations_seed_modes_of_payment(),
  app.set_mode_of_payment_account(uuid), app.companies_seed_mode_of_payment()
from public, anon, authenticated;

drop trigger if exists mode_of_payment_validate on public.mode_of_payment;
create trigger mode_of_payment_validate before insert or update on public.mode_of_payment
  for each row execute function app.mode_of_payment_validate();
drop trigger if exists touch_updated on public.mode_of_payment;
create trigger touch_updated before update on public.mode_of_payment
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_modes_of_payment on public.organizations;
create trigger organizations_seed_modes_of_payment after insert on public.organizations
  for each row execute function app.organizations_seed_modes_of_payment();

drop trigger if exists mode_of_payment_account_validate on public.mode_of_payment_account;
create trigger mode_of_payment_account_validate before insert or update on public.mode_of_payment_account
  for each row execute function app.mode_of_payment_account_validate();
drop trigger if exists companies_seed_mode_of_payment on public.companies;
create trigger companies_seed_mode_of_payment after insert on public.companies
  for each row execute function app.companies_seed_mode_of_payment();

alter table public.mode_of_payment enable row level security;
alter table public.mode_of_payment force row level security;
alter table public.mode_of_payment_account enable row level security;
alter table public.mode_of_payment_account force row level security;

drop policy if exists mode_of_payment_select on public.mode_of_payment;
create policy mode_of_payment_select on public.mode_of_payment for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'read'))::uuid[]));
drop policy if exists mode_of_payment_insert on public.mode_of_payment;
create policy mode_of_payment_insert on public.mode_of_payment for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'create'))::uuid[]));
drop policy if exists mode_of_payment_update on public.mode_of_payment;
create policy mode_of_payment_update on public.mode_of_payment for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'write'))::uuid[]));
drop policy if exists mode_of_payment_delete on public.mode_of_payment;
create policy mode_of_payment_delete on public.mode_of_payment for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'delete'))::uuid[]));

drop policy if exists mode_of_payment_account_select on public.mode_of_payment_account;
create policy mode_of_payment_account_select on public.mode_of_payment_account for select to authenticated
  using (exists (select 1 from public.mode_of_payment p where p.id = parent_id));
drop policy if exists mode_of_payment_account_insert on public.mode_of_payment_account;
create policy mode_of_payment_account_insert on public.mode_of_payment_account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Mode of Payment', 'create'))::uuid[]));
drop policy if exists mode_of_payment_account_update on public.mode_of_payment_account;
create policy mode_of_payment_account_update on public.mode_of_payment_account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'write'))::uuid[]));
drop policy if exists mode_of_payment_account_delete on public.mode_of_payment_account;
create policy mode_of_payment_account_delete on public.mode_of_payment_account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Mode of Payment', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Mode of Payment', 'mode_of_payment', 'accounts', 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Mode of Payment Account', 'mode_of_payment_account', 'accounts', true, 'Mode of Payment', 'accounts')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true, parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Mode of Payment', true, false, false, false),
  ('Accounts Manager', 'Mode of Payment', true, true, true, false),
  ('Accounts User', 'Mode of Payment', true, false, false, false),
  ('Sales User', 'Mode of Payment', true, false, false, false),
  ('Purchase User', 'Mode of Payment', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

select app.seed_modes_of_payment(o.id) from public.organizations o;
select app.set_mode_of_payment_account(c.id) from public.companies c;
