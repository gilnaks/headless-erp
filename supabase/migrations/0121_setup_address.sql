-- 0121 setup: Address -> public.address + child public.address_link (docs/modules/00-setup.md §2.19).
-- ERPNext sources: erpnext/accounts/custom/address.py (ERPNextAddress.validate_reference, update_company_address,
-- get_shipping_address), erpnext/setup/install.py (create_address_and_contact_custom_fields,
-- grant_address_read_to_accounts_manager). Frappe Address / Dynamic Link (frappe/contacts/doctype/address: autoname,
-- validate_preferred_address, get_default_address; frappe/core/doctype/dynamic_link) ported from memory: the frappe
-- repository is not cloned.
--
-- Deviation: Frappe's shared `Dynamic Link` child becomes one link table per parent (`address_link`, later
-- `contact_link`), because the doc engine maps a child doctype to exactly one parent (doctype_meta.parent_doctype).

create table if not exists public.address (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  name                    text,
  address_title           text,
  address_type            text not null default 'Billing'
                          check (address_type in ('Billing', 'Shipping', 'Office', 'Personal', 'Plant', 'Postal', 'Shop',
                                                  'Subsidiary', 'Warehouse', 'Current', 'Permanent', 'Other')),
  address_line1           text not null check (length(trim(address_line1)) > 0),
  address_line2           text,
  city                    text not null check (length(trim(city)) > 0),
  county                  text,
  state                   text,
  country                 text not null references public.country (country_name),
  pincode                 text,
  email_id                text,
  phone                   text,
  fax                     text,
  is_primary_address      boolean not null default false,
  is_shipping_address     boolean not null default false,
  disabled                boolean not null default false,
  is_your_company_address boolean not null default false,
  created_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  updated_at              timestamptz not null default now(),
  updated_by              uuid,
  unique (org_id, id)
);

create unique index if not exists address_name_uniq on public.address (org_id, lower(name));
create index if not exists address_country_idx on public.address (country);

create table if not exists public.address_link (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null,
  parent_id    uuid not null,
  idx          int not null,
  link_doctype text not null constraint address_link_doctype_check check (link_doctype in ('Company')),
  link_id      uuid not null,
  link_title   text,
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, link_doctype, link_id),
  foreign key (org_id, parent_id) references public.address (org_id, id) on delete cascade
);

create index if not exists address_link_target_idx on public.address_link (link_doctype, link_id);

-- Header checks that need no rows. `name` is set once by app.address_refresh (Frappe autoname) and never changes.
create or replace function app.address_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.name := null;
  elsif old.name is not null then
    new.name := old.name;
  end if;
  new.address_title := nullif(trim(new.address_title), '');
  new.address_line1 := trim(new.address_line1);
  new.address_line2 := nullif(trim(new.address_line2), '');
  new.city := trim(new.city);
  new.county := nullif(trim(new.county), '');
  new.state := nullif(trim(new.state), '');
  new.pincode := nullif(trim(new.pincode), '');
  new.email_id := nullif(trim(new.email_id), '');
  new.phone := nullif(trim(new.phone), '');
  new.fax := nullif(trim(new.fax), '');
  if new.country is null or new.country = '' then
    select o.country into new.country from public.organizations o where o.id = new.org_id;
  end if;
  return new;
end;
$$;

-- Dynamic Link row: the target must exist in the same org (Frappe validates the Link); link_title is its title.
create or replace function app.address_link_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_title text;
begin
  select * into v_meta from public.doctype_meta where doctype = new.link_doctype and not is_child;
  if not found then
    raise exception using errcode = 'P0001', message = format('link_invalid: %s is not a document type', new.link_doctype);
  end if;
  execute format('select %I::text from public.%I where id = $1 and org_id = $2', v_meta.title_field, v_meta.table_name)
    into v_title using new.link_id, new.org_id;
  if v_title is null then
    raise exception using errcode = 'P0001', message = format('link_invalid: %s not found', new.link_doctype);
  end if;
  new.link_title := v_title;
  return new;
end;
$$;

-- Address.validate over header + links, deferred to the end of the transaction that saved it (app.save_doc writes
-- the header before the rows):
--  * ERPNextAddress.update_company_address: a Company link sets is_your_company_address;
--  * ERPNextAddress.validate_reference: is_your_company_address needs a Company link;
--  * Frappe autoname: address_title defaults to the first link's title, name = "<title>-<type>" (-1, -2 on clashes);
--  * Frappe validate_preferred_address: a primary / shipping address unsets that flag on the other addresses of
--    every party it is linked to.
create or replace function app.address_refresh(p_address uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.address;
  v_has_company boolean;
  v_title text;
  v_base text;
  v_name text;
  v_n int := 0;
begin
  select * into v from public.address where id = p_address;
  if not found then
    return;
  end if;

  v_has_company := exists (select 1 from public.address_link l where l.parent_id = p_address and l.link_doctype = 'Company');
  if v.is_your_company_address and not v_has_company then
    raise exception using errcode = 'P0001',
      message = 'address_company_link: Address needs to be linked to a Company. Please add a row for Company in the Links table.';
  end if;

  v_title := coalesce(v.address_title,
                      (select l.link_title from public.address_link l where l.parent_id = p_address order by l.idx limit 1));
  if v_title is null then
    raise exception using errcode = 'P0001', message = 'address_title_required: Address Title is mandatory.';
  end if;

  v_name := v.name;
  if v_name is null then
    v_base := v_title || '-' || v.address_type;
    v_name := v_base;
    while exists (select 1 from public.address a where a.org_id = v.org_id and lower(a.name) = lower(v_name)) loop
      v_n := v_n + 1;
      v_name := v_base || '-' || v_n;
    end loop;
  end if;

  update public.address a
     set address_title = v_title, name = v_name, is_your_company_address = v.is_your_company_address or v_has_company
   where a.id = p_address
     and (a.address_title is distinct from v_title or a.name is distinct from v_name
          or a.is_your_company_address is distinct from (v.is_your_company_address or v_has_company));

  if v.is_primary_address then
    update public.address a set is_primary_address = false
     where a.org_id = v.org_id and a.id <> p_address and a.is_primary_address
       and exists (select 1 from public.address_link l join public.address_link m
                     on m.link_doctype = l.link_doctype and m.link_id = l.link_id
                    where l.parent_id = a.id and m.parent_id = p_address);
  end if;
  if v.is_shipping_address then
    update public.address a set is_shipping_address = false
     where a.org_id = v.org_id and a.id <> p_address and a.is_shipping_address
       and exists (select 1 from public.address_link l join public.address_link m
                     on m.link_doctype = l.link_doctype and m.link_id = l.link_id
                    where l.parent_id = a.id and m.parent_id = p_address);
  end if;
end;
$$;

create or replace function app.address_refresh_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'address_link' then
    perform app.address_refresh(coalesce(new.parent_id, old.parent_id));
  else
    perform app.address_refresh(new.id);
  end if;
  return null;
end;
$$;

-- Frappe delete_dynamic_links / title refresh for a linked party (Company now; Customer, Supplier, Sales Partner
-- attach the same trigger later). Arguments: the party doctype.
create or replace function app.dynamic_link_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doctype text := tg_argv[0];
  v_title_field text;
  v_title text;
begin
  if tg_op = 'DELETE' then
    update public.address a set is_your_company_address = false
     where v_doctype = 'Company' and a.is_your_company_address
       and exists (select 1 from public.address_link l where l.parent_id = a.id and l.link_doctype = v_doctype and l.link_id = old.id)
       and not exists (select 1 from public.address_link l where l.parent_id = a.id and l.link_doctype = 'Company' and l.link_id <> old.id);
    delete from public.address_link l where l.link_doctype = v_doctype and l.link_id = old.id;
    return old;
  end if;
  select m.title_field into v_title_field from public.doctype_meta m where m.doctype = v_doctype;
  v_title := to_jsonb(new) ->> v_title_field;
  if v_title is distinct from to_jsonb(old) ->> v_title_field then
    update public.address_link l set link_title = v_title where l.link_doctype = v_doctype and l.link_id = new.id;
  end if;
  return new;
end;
$$;

-- ERPNext get_default_company_address (kind 'primary': primary first, else any) and get_shipping_address (kind
-- 'shipping': flagged shipping only). Enabled company addresses only. RLS applies.
create or replace function app.company_address(p_company uuid, p_kind text default 'primary')
returns setof public.address
language sql
stable
set search_path = ''
as $$
  select a.* from public.address a
   where not a.disabled and a.is_your_company_address
     and exists (select 1 from public.address_link l where l.parent_id = a.id and l.link_doctype = 'Company' and l.link_id = p_company)
     and (p_kind is distinct from 'shipping' or a.is_shipping_address)
   order by a.is_primary_address desc, a.is_shipping_address desc, a.updated_at desc
   limit 1;
$$;

-- Frappe load_address_and_contact: the addresses linked to a party, primary first. RLS applies.
create or replace function app.party_addresses(p_doctype text, p_id uuid)
returns setof public.address
language sql
stable
set search_path = ''
as $$
  select a.* from public.address a
   where exists (select 1 from public.address_link l where l.parent_id = a.id and l.link_doctype = p_doctype and l.link_id = p_id)
   order by a.is_primary_address desc, a.is_shipping_address desc, a.updated_at desc;
$$;

create or replace function public.company_address(p_company uuid, p_kind text default 'primary')
returns setof public.address
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app.company_address(p_company, p_kind);
$$;

create or replace function public.party_addresses(p_doctype text, p_id uuid)
returns setof public.address
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app.party_addresses(p_doctype, p_id);
$$;

revoke execute on function
  app.address_validate(), app.address_link_validate(), app.address_refresh(uuid), app.address_refresh_trigger(),
  app.dynamic_link_sync(), app.company_address(uuid, text), app.party_addresses(text, uuid),
  public.company_address(uuid, text), public.party_addresses(text, uuid)
from public, anon, authenticated;
grant execute on function
  app.company_address(uuid, text), app.party_addresses(text, uuid),
  public.company_address(uuid, text), public.party_addresses(text, uuid)
to authenticated;

drop trigger if exists address_validate on public.address;
create trigger address_validate
  before insert or update on public.address
  for each row execute function app.address_validate();

drop trigger if exists touch_updated on public.address;
create trigger touch_updated
  before update on public.address
  for each row execute function app.touch_updated();

drop trigger if exists address_refresh on public.address;
create constraint trigger address_refresh
  after insert or update of address_title, address_type, is_primary_address, is_shipping_address, is_your_company_address
  on public.address
  deferrable initially deferred
  for each row execute function app.address_refresh_trigger();

drop trigger if exists address_link_validate on public.address_link;
create trigger address_link_validate
  before insert or update of link_doctype, link_id on public.address_link
  for each row execute function app.address_link_validate();

drop trigger if exists address_link_refresh on public.address_link;
create constraint trigger address_link_refresh
  after insert or update or delete on public.address_link
  deferrable initially deferred
  for each row execute function app.address_refresh_trigger();

drop trigger if exists dynamic_link_sync on public.companies;
create trigger dynamic_link_sync
  after update of company_name or delete on public.companies
  for each row execute function app.dynamic_link_sync('Company');

------------------------------------------------------------------------------------------------------------------------
-- RLS (link rows delegate to the parent Address permissions)
------------------------------------------------------------------------------------------------------------------------

alter table public.address enable row level security;
alter table public.address force row level security;
alter table public.address_link enable row level security;
alter table public.address_link force row level security;

drop policy if exists address_select on public.address;
create policy address_select on public.address for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Address', 'read'))::uuid[]));
drop policy if exists address_insert on public.address;
create policy address_insert on public.address for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Address', 'create'))::uuid[]));
drop policy if exists address_update on public.address;
create policy address_update on public.address for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Address', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Address', 'write'))::uuid[]));
drop policy if exists address_delete on public.address;
create policy address_delete on public.address for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Address', 'delete'))::uuid[]));

drop policy if exists address_link_select on public.address_link;
create policy address_link_select on public.address_link for select to authenticated
  using (exists (select 1 from public.address p where p.id = parent_id));
drop policy if exists address_link_insert on public.address_link;
create policy address_link_insert on public.address_link for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Address', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Address', 'create'))::uuid[]));
drop policy if exists address_link_update on public.address_link;
create policy address_link_update on public.address_link for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Address', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Address', 'write'))::uuid[]));
drop policy if exists address_link_delete on public.address_link;
create policy address_link_delete on public.address_link for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Address', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (Frappe Address JSON: Sales/Purchase/Maintenance/Accounts/Stock User and
-- Sales/Purchase Manager rwcd; install.py grant_address_read_to_accounts_manager: Accounts Manager read;
-- System Manager rwcd)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Address', 'address', 'setup', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Address Link', 'address_link', 'setup', true, 'Address', 'links')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = excluded.is_child,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Address', true, true, true, true),
       ('Sales User', 'Address', true, true, true, true),
       ('Sales Manager', 'Address', true, true, true, true),
       ('Purchase User', 'Address', true, true, true, true),
       ('Purchase Manager', 'Address', true, true, true, true),
       ('Maintenance User', 'Address', true, true, true, true),
       ('Accounts User', 'Address', true, true, true, true),
       ('Stock User', 'Address', true, true, true, true),
       ('Accounts Manager', 'Address', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
