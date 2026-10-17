-- 0237 buying: Supplier (docs/modules/03-buying.md §2.1–2.2; 01-accounts §2.9, §3.5).
-- ERPNext: erpnext/buying/doctype/supplier/supplier.py autoname, before_save, validate,
-- get_supplier_group_details; erpnext/accounts/party.py get_party_account.
-- Naming Series waits for Buying Settings. Bank account and tax withholding stay out.
-- The GL-currency override waits for the ledger.

alter table public.supplier_group
  add column if not exists payment_terms_id uuid;

alter table public.supplier_group drop constraint if exists supplier_group_payment_terms_fk;
alter table public.supplier_group
  add constraint supplier_group_payment_terms_fk
  foreign key (org_id, payment_terms_id) references public.payment_terms_template (org_id, id)
  on delete set null (payment_terms_id);

create index if not exists supplier_group_payment_terms_idx on public.supplier_group (org_id, payment_terms_id);

create table if not exists public.supplier (
  id                       uuid primary key default gen_random_uuid(),
  org_id                   uuid not null references public.organizations (id) on delete cascade,
  name                     text not null,
  supplier_name            text not null check (length(trim(supplier_name)) > 0),
  supplier_group_id        uuid,
  supplier_type            text not null default 'Company' check (supplier_type in ('Company', 'Individual', 'Partnership')),
  country                  text references public.country (country_name) on update cascade,
  tax_id                   text,
  tax_category_id          uuid,
  default_currency         text,
  default_price_list_id    uuid,
  language                 text,
  website                  text,
  supplier_details         text,
  supplier_primary_contact uuid,
  supplier_primary_address uuid,
  payment_terms_id         uuid,
  is_transporter           boolean not null default false,
  disabled                 boolean not null default false,
  is_frozen                boolean not null default false,
  on_hold                  boolean not null default false,
  hold_type                text check (hold_type is null or hold_type = '' or hold_type in ('All', 'Invoices', 'Payments')),
  release_date             date,
  allow_purchase_invoice_creation_without_purchase_order boolean not null default false,
  allow_purchase_invoice_creation_without_purchase_receipt boolean not null default false,
  alias                    text,
  warn_rfqs                boolean not null default false,
  prevent_rfqs             boolean not null default false,
  warn_pos                 boolean not null default false,
  prevent_pos              boolean not null default false,
  created_at               timestamptz not null default now(),
  created_by               uuid default auth.uid(),
  updated_at               timestamptz not null default now(),
  updated_by               uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, supplier_group_id) references public.supplier_group (org_id, id),
  foreign key (org_id, tax_category_id) references public.tax_category (org_id, id)
    on delete set null (tax_category_id),
  foreign key (org_id, default_price_list_id) references public.price_list (org_id, id)
    on delete set null (default_price_list_id),
  foreign key (org_id, supplier_primary_contact) references public.contact (org_id, id)
    on delete set null (supplier_primary_contact),
  foreign key (org_id, supplier_primary_address) references public.address (org_id, id)
    on delete set null (supplier_primary_address),
  foreign key (org_id, payment_terms_id) references public.payment_terms_template (org_id, id)
    on delete set null (payment_terms_id)
);

create unique index if not exists supplier_name_uniq on public.supplier (org_id, lower(supplier_name));
create unique index if not exists supplier_alias_uniq on public.supplier (org_id, lower(alias)) where alias is not null;
create index if not exists supplier_group_idx on public.supplier (org_id, supplier_group_id);
create index if not exists supplier_tax_category_idx on public.supplier (org_id, tax_category_id);
create index if not exists supplier_price_list_idx on public.supplier (org_id, default_price_list_id);
create index if not exists supplier_contact_idx on public.supplier (org_id, supplier_primary_contact);
create index if not exists supplier_address_idx on public.supplier (org_id, supplier_primary_address);
create index if not exists supplier_payment_terms_idx on public.supplier (org_id, payment_terms_id);

create table if not exists public.supplier_party_account (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  parent_id  uuid not null,
  idx        int not null,
  company_id uuid not null,
  account_id uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.supplier (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, account_id) references public.account (org_id, id) on delete cascade
);

create table if not exists public.supplier_group_party_account (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  parent_id  uuid not null,
  idx        int not null,
  company_id uuid not null,
  account_id uuid,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.supplier_group (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, account_id) references public.account (org_id, id) on delete cascade
);

create index if not exists supplier_party_account_parent_idx on public.supplier_party_account (org_id, parent_id);
create index if not exists supplier_party_account_company_idx on public.supplier_party_account (org_id, company_id);
create index if not exists supplier_party_account_account_idx on public.supplier_party_account (org_id, account_id);
create index if not exists supplier_group_party_account_parent_idx on public.supplier_group_party_account (org_id, parent_id);
create index if not exists supplier_group_party_account_company_idx on public.supplier_group_party_account (org_id, company_id);
create index if not exists supplier_group_party_account_account_idx on public.supplier_group_party_account (org_id, account_id);

-- Keeps the shipped parent default and adds the in-use check.
create or replace function app.supplier_group_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.supplier_group_name := trim(new.supplier_group_name);
  if new.parent_id is null and new.supplier_group_name <> 'All Supplier Groups' then
    select id into new.parent_id from public.supplier_group
    where org_id = new.org_id and parent_id is null;
  end if;
  if tg_op = 'UPDATE' and new.is_group and not old.is_group and exists (
    select 1 from public.supplier s where s.supplier_group_id = new.id
  ) then
    raise exception using errcode = 'P0001',
      message = 'supplier_group_in_use: A Supplier Group selected on a supplier cannot become a group';
  end if;
  return new;
end;
$$;

create or replace function app.supplier_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group boolean;
  v_buying boolean;
  v_title text;
begin
  new.supplier_name := trim(new.supplier_name);
  if new.hold_type = '' then
    new.hold_type := null;
  end if;
  if not new.on_hold then
    new.release_date := null;
  elsif new.hold_type is null then
    new.hold_type := 'All';
  end if;
  if tg_op = 'INSERT' or new.supplier_name is distinct from old.supplier_name then
    new.name := new.supplier_name;
  end if;
  if new.supplier_group_id is not null then
    select is_group into v_group from public.supplier_group where id = new.supplier_group_id;
    if coalesce(v_group, false) then
      raise exception using errcode = 'P0001',
        message = 'supplier_group_leaf: Cannot select a group type Supplier Group';
    end if;
  end if;
  if new.default_price_list_id is not null then
    select buying into v_buying from public.price_list where id = new.default_price_list_id;
    if not coalesce(v_buying, false) then
      raise exception using errcode = 'P0001',
        message = 'supplier_price_list: Default price list must be a buying list';
    end if;
  end if;
  if new.supplier_primary_contact is not null
     and (tg_op = 'INSERT' or new.supplier_primary_contact is distinct from old.supplier_primary_contact)
     and not exists (
       select 1 from public.contact_link l
        where l.parent_id = new.supplier_primary_contact
          and l.link_doctype = 'Supplier'
          and l.link_id = new.id
     ) then
    select c.name into v_title from public.contact c where c.id = new.supplier_primary_contact;
    raise exception using errcode = 'P0001',
      message = format('supplier_primary_link: Contact %s is not linked to Supplier %s', coalesce(v_title, ''), new.supplier_name);
  end if;
  if new.supplier_primary_address is not null
     and (tg_op = 'INSERT' or new.supplier_primary_address is distinct from old.supplier_primary_address)
     and not exists (
       select 1 from public.address_link l
        where l.parent_id = new.supplier_primary_address
          and l.link_doctype = 'Supplier'
          and l.link_id = new.id
     ) then
    select a.name into v_title from public.address a where a.id = new.supplier_primary_address;
    raise exception using errcode = 'P0001',
      message = format('supplier_primary_link: Address %s is not linked to Supplier %s', coalesce(v_title, ''), new.supplier_name);
  end if;
  return new;
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
  elsif p_party_type = 'Supplier' then
    select account_id into v_account from public.supplier_party_account
     where parent_id = p_party and company_id = p_company and account_id is not null;
    if v_account is not null then
      return v_account;
    end if;
    select supplier_group_id into v_group from public.supplier where id = p_party;
    select account_id into v_account from public.supplier_group_party_account
     where parent_id = v_group and company_id = p_company and account_id is not null;
    if v_account is not null then
      return v_account;
    end if;
    select default_payable_account_id, company_name into v_account, v_company_name
      from public.companies where id = p_company;
    if v_account is null then
      raise exception using errcode = 'P0001',
        message = format('party_account_missing: Please set default Payable account in Company %s', v_company_name);
    end if;
  end if;
  return v_account;
end;
$$;

create or replace function app.get_supplier_group_details(p_supplier uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_org uuid;
  v_group uuid;
begin
  select org_id, supplier_group_id into v_org, v_group from public.supplier where id = p_supplier;
  if v_group is null then
    return;
  end if;
  update public.supplier s
     set payment_terms_id = g.payment_terms_id
    from public.supplier_group g
   where s.id = p_supplier and g.id = v_group;
  delete from public.supplier_party_account where parent_id = p_supplier;
  insert into public.supplier_party_account (org_id, parent_id, idx, company_id, account_id)
  select v_org, p_supplier, a.idx, a.company_id, a.account_id
    from public.supplier_group_party_account a
   where a.parent_id = v_group;
end;
$$;

create or replace function public.get_supplier_group_details(p_supplier uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.get_supplier_group_details(p_supplier);
$$;

revoke all on function app.supplier_validate() from public, anon, authenticated;
revoke all on function app.get_supplier_group_details(uuid) from public, anon;
grant execute on function app.get_supplier_group_details(uuid) to authenticated;
revoke all on function public.get_supplier_group_details(uuid) from public, anon;
grant execute on function public.get_supplier_group_details(uuid) to authenticated;

drop trigger if exists supplier_validate on public.supplier;
create trigger supplier_validate before insert or update on public.supplier
  for each row execute function app.supplier_validate();
drop trigger if exists touch_updated on public.supplier;
create trigger touch_updated before update on public.supplier
  for each row execute function app.touch_updated();

drop trigger if exists supplier_party_account_validate on public.supplier_party_account;
create trigger supplier_party_account_validate before insert or update on public.supplier_party_account
  for each row execute function app.party_account_validate('Payable');
drop trigger if exists supplier_group_party_account_validate on public.supplier_group_party_account;
create trigger supplier_group_party_account_validate before insert or update on public.supplier_group_party_account
  for each row execute function app.party_account_validate('Payable');

alter table public.supplier enable row level security;
alter table public.supplier force row level security;
alter table public.supplier_party_account enable row level security;
alter table public.supplier_party_account force row level security;
alter table public.supplier_group_party_account enable row level security;
alter table public.supplier_group_party_account force row level security;

drop policy if exists supplier_select on public.supplier;
create policy supplier_select on public.supplier for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier', 'read'))::uuid[]));
drop policy if exists supplier_insert on public.supplier;
create policy supplier_insert on public.supplier for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Supplier', 'create'))::uuid[]));
drop policy if exists supplier_update on public.supplier;
create policy supplier_update on public.supplier for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Supplier', 'write'))::uuid[]));
drop policy if exists supplier_delete on public.supplier;
create policy supplier_delete on public.supplier for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier', 'delete'))::uuid[]));

drop policy if exists supplier_party_account_select on public.supplier_party_account;
create policy supplier_party_account_select on public.supplier_party_account for select to authenticated
  using (exists (select 1 from public.supplier p where p.id = parent_id));
drop policy if exists supplier_party_account_insert on public.supplier_party_account;
create policy supplier_party_account_insert on public.supplier_party_account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Supplier', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Supplier', 'create'))::uuid[]));
drop policy if exists supplier_party_account_update on public.supplier_party_account;
create policy supplier_party_account_update on public.supplier_party_account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Supplier', 'write'))::uuid[]));
drop policy if exists supplier_party_account_delete on public.supplier_party_account;
create policy supplier_party_account_delete on public.supplier_party_account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier', 'write'))::uuid[]));

drop policy if exists supplier_group_party_account_select on public.supplier_group_party_account;
create policy supplier_group_party_account_select on public.supplier_group_party_account for select to authenticated
  using (exists (
    select 1 from public.supplier_group p
    where p.id = supplier_group_party_account.parent_id
  ));
drop policy if exists supplier_group_party_account_insert on public.supplier_group_party_account;
create policy supplier_group_party_account_insert on public.supplier_group_party_account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Supplier Group', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Supplier Group', 'create'))::uuid[]));
drop policy if exists supplier_group_party_account_update on public.supplier_group_party_account;
create policy supplier_group_party_account_update on public.supplier_group_party_account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier Group', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Supplier Group', 'write'))::uuid[]));
drop policy if exists supplier_group_party_account_delete on public.supplier_group_party_account;
create policy supplier_group_party_account_delete on public.supplier_group_party_account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Supplier Group', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Supplier', 'supplier', 'buying', 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values
  ('Supplier Party Account', 'supplier_party_account', 'accounts', true, 'Supplier', 'accounts'),
  ('Supplier Group Account', 'supplier_group_party_account', 'accounts', true, 'Supplier Group', 'accounts')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Supplier', true, false, false, false),
  ('Purchase User', 'Supplier', true, false, false, false),
  ('Purchase Manager', 'Supplier', true, true, true, true),
  ('Stock User', 'Supplier', true, false, false, false),
  ('Stock Manager', 'Supplier', true, false, false, false),
  ('Accounts User', 'Supplier', true, false, false, false),
  ('Accounts Manager', 'Supplier', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
