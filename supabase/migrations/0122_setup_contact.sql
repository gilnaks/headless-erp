-- 0122 setup: Contact -> public.contact + children contact_email, contact_phone, contact_link (00-setup.md §2.20).
-- ERPNext sources: erpnext/setup/install.py (create_address_and_contact_custom_fields: is_billing_contact),
-- erpnext/setup/doctype/company/company.json (default_sales_contact). Frappe Contact / Contact Email / Contact Phone /
-- Dynamic Link (frappe/contacts/doctype/contact: autoname, validate -> set_primary_email, set_primary("phone"),
-- set_primary("mobile_no"), set_user; Gender fixtures from the setup wizard) ported from memory: the frappe
-- repository is not cloned.
--
-- Deviation: the Dynamic Link child is `contact_link` (one link table per parent, as `address_link` in 0121).

create table if not exists public.contact (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations (id) on delete cascade,
  name               text,
  first_name         text not null check (length(trim(first_name)) > 0),
  middle_name        text,
  last_name          text,
  full_name          text,
  salutation         text,
  designation_id     uuid,
  gender             text check (gender in ('Male', 'Female', 'Other', 'Transgender', 'Genderqueer', 'Non-Conforming',
                                            'Prefer not to say')),
  email_id           text,
  phone              text,
  mobile_no          text,
  company_name       text,
  user_id            uuid references auth.users (id) on delete set null,
  address_id         uuid,
  image              text,
  status             text not null default 'Passive' check (status in ('Passive', 'Open', 'Replied')),
  is_primary_contact boolean not null default false,
  is_billing_contact boolean not null default false,
  department         text,
  unsubscribed       boolean not null default false,
  created_at         timestamptz not null default now(),
  created_by         uuid default auth.uid(),
  updated_at         timestamptz not null default now(),
  updated_by         uuid,
  unique (org_id, id),
  check (starts_with(image, org_id::text || '/contact/')),
  foreign key (org_id, designation_id) references public.designation (org_id, id) on delete set null (designation_id),
  foreign key (org_id, address_id) references public.address (org_id, id) on delete set null (address_id)
);

create unique index if not exists contact_name_uniq on public.contact (org_id, lower(name));
create index if not exists contact_email_idx on public.contact (org_id, lower(email_id));
create index if not exists contact_user_idx on public.contact (user_id);
create index if not exists contact_designation_idx on public.contact (designation_id);
create index if not exists contact_address_idx on public.contact (address_id);

create table if not exists public.contact_email (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null,
  parent_id  uuid not null,
  idx        int not null,
  email_id   text not null check (length(trim(email_id)) > 0),
  is_primary boolean not null default false,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.contact (org_id, id) on delete cascade
);

create table if not exists public.contact_phone (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null,
  parent_id            uuid not null,
  idx                  int not null,
  phone                text not null check (length(trim(phone)) > 0),
  is_primary_phone     boolean not null default false,
  is_primary_mobile_no boolean not null default false,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.contact (org_id, id) on delete cascade
);

create table if not exists public.contact_link (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null,
  parent_id    uuid not null,
  idx          int not null,
  link_doctype text not null constraint contact_link_doctype_check check (link_doctype in ('Company')),
  link_id      uuid not null,
  link_title   text,
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, link_doctype, link_id),
  foreign key (org_id, parent_id) references public.contact (org_id, id) on delete cascade
);

create index if not exists contact_link_target_idx on public.contact_link (link_doctype, link_id);

-- Header checks that need no rows: trims, Frappe get_full_name, write-once `name` (set by app.contact_refresh).
create or replace function app.contact_validate()
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
  new.first_name := trim(new.first_name);
  new.middle_name := nullif(trim(new.middle_name), '');
  new.last_name := nullif(trim(new.last_name), '');
  new.full_name := concat_ws(' ', new.first_name, new.middle_name, new.last_name);
  new.salutation := nullif(trim(new.salutation), '');
  new.company_name := nullif(trim(new.company_name), '');
  new.department := nullif(trim(new.department), '');
  new.image := nullif(new.image, '');
  return new;
end;
$$;

-- Frappe validate_email_address on each Contact Email row.
create or replace function app.contact_email_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.email_id := trim(new.email_id);
  if new.email_id !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception using errcode = 'P0001', message = format('invalid_email: %s is not a valid Email Address', new.email_id);
  end if;
  return new;
end;
$$;

create or replace function app.contact_phone_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.phone := trim(new.phone);
  return new;
end;
$$;

-- Frappe Contact.validate over header + rows, deferred to commit (app.save_doc writes the header before the rows):
-- at most one primary email / phone / mobile, the denormalised email_id / phone / mobile_no follow the primary rows,
-- set_user (member with the primary email), autoname (full name + "-<first link title>", -1 on clashes) and one
-- primary contact per linked party.
create or replace function app.contact_refresh(p_contact uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.contact;
  v_email text;
  v_phone text;
  v_mobile text;
  v_user uuid;
  v_base text;
  v_name text;
  v_n int := 0;
begin
  select * into v from public.contact where id = p_contact;
  if not found then
    return;
  end if;

  if (select count(*) from public.contact_email e where e.parent_id = p_contact and e.is_primary) > 1 then
    raise exception using errcode = 'P0001', message = 'contact_primary_email: Only one Email ID can be set as primary.';
  end if;
  if (select count(*) from public.contact_phone p where p.parent_id = p_contact and p.is_primary_phone) > 1 then
    raise exception using errcode = 'P0001', message = 'contact_primary_phone: Only one Phone can be set as primary.';
  end if;
  if (select count(*) from public.contact_phone p where p.parent_id = p_contact and p.is_primary_mobile_no) > 1 then
    raise exception using errcode = 'P0001', message = 'contact_primary_mobile: Only one Mobile No can be set as primary.';
  end if;

  select e.email_id into v_email from public.contact_email e where e.parent_id = p_contact and e.is_primary;
  select p.phone into v_phone from public.contact_phone p where p.parent_id = p_contact and p.is_primary_phone;
  select p.phone into v_mobile from public.contact_phone p where p.parent_id = p_contact and p.is_primary_mobile_no;

  v_user := v.user_id;
  if v_user is null and v_email is not null then
    select m.user_id into v_user
      from public.org_members m join auth.users u on u.id = m.user_id
     where m.org_id = v.org_id and lower(u.email) = lower(v_email)
     limit 1;
  end if;

  v_name := v.name;
  if v_name is null then
    v_base := v.full_name || coalesce('-' || (select l.link_title from public.contact_link l
                                                where l.parent_id = p_contact order by l.idx limit 1), '');
    v_name := v_base;
    while exists (select 1 from public.contact c where c.org_id = v.org_id and lower(c.name) = lower(v_name)) loop
      v_n := v_n + 1;
      v_name := v_base || '-' || v_n;
    end loop;
  end if;

  update public.contact c
     set email_id = v_email, phone = v_phone, mobile_no = v_mobile, user_id = v_user, name = v_name
   where c.id = p_contact
     and (c.email_id is distinct from v_email or c.phone is distinct from v_phone or c.mobile_no is distinct from v_mobile
          or c.user_id is distinct from v_user or c.name is distinct from v_name);

  if v.is_primary_contact then
    update public.contact c set is_primary_contact = false
     where c.org_id = v.org_id and c.id <> p_contact and c.is_primary_contact
       and exists (select 1 from public.contact_link l join public.contact_link m
                     on m.link_doctype = l.link_doctype and m.link_id = l.link_id
                    where l.parent_id = c.id and m.parent_id = p_contact);
  end if;
end;
$$;

create or replace function app.contact_refresh_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'contact' then
    perform app.contact_refresh(new.id);
  else
    perform app.contact_refresh(coalesce(new.parent_id, old.parent_id));
  end if;
  return null;
end;
$$;

-- Frappe set_user for members added later: a new member with the contact's email becomes its user.
create or replace function app.contact_match_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.contact c set user_id = new.user_id
   where c.org_id = new.org_id and c.user_id is null
     and lower(c.email_id) = (select lower(u.email) from auth.users u where u.id = new.user_id);
  return null;
end;
$$;

-- Dynamic link rows of Address (0121) and Contact: same-org target, link_title from its title field.
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

-- 0121's party sync, now also for Contact links.
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
    delete from public.contact_link l where l.link_doctype = v_doctype and l.link_id = old.id;
    return old;
  end if;
  select m.title_field into v_title_field from public.doctype_meta m where m.doctype = v_doctype;
  v_title := to_jsonb(new) ->> v_title_field;
  if v_title is distinct from to_jsonb(old) ->> v_title_field then
    update public.address_link l set link_title = v_title where l.link_doctype = v_doctype and l.link_id = new.id;
    update public.contact_link l set link_title = v_title where l.link_doctype = v_doctype and l.link_id = new.id;
  end if;
  return new;
end;
$$;

-- Frappe load_address_and_contact: the contacts linked to a party, primary first. RLS applies.
create or replace function app.party_contacts(p_doctype text, p_id uuid)
returns setof public.contact
language sql
stable
set search_path = ''
as $$
  select c.* from public.contact c
   where exists (select 1 from public.contact_link l where l.parent_id = c.id and l.link_doctype = p_doctype and l.link_id = p_id)
   order by c.is_primary_contact desc, c.updated_at desc;
$$;

create or replace function public.party_contacts(p_doctype text, p_id uuid)
returns setof public.contact
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app.party_contacts(p_doctype, p_id);
$$;

-- Contact images live in org-files/<org_id>/contact/ (0118 storage policies).
create or replace function app.file_doctype(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case split_part(p_name, '/', 2)
    when 'letter-head' then 'Letter Head'
    when 'contact' then 'Contact'
  end;
$$;

revoke execute on function
  app.contact_validate(), app.contact_email_validate(), app.contact_phone_validate(), app.contact_refresh(uuid),
  app.contact_refresh_trigger(), app.contact_match_member(), app.address_link_validate(), app.dynamic_link_sync(),
  app.party_contacts(text, uuid), public.party_contacts(text, uuid)
from public, anon, authenticated;
grant execute on function app.party_contacts(text, uuid), public.party_contacts(text, uuid) to authenticated;
revoke execute on function app.file_doctype(text) from public, anon;
grant execute on function app.file_doctype(text) to authenticated;

drop trigger if exists contact_validate on public.contact;
create trigger contact_validate
  before insert or update on public.contact
  for each row execute function app.contact_validate();

drop trigger if exists touch_updated on public.contact;
create trigger touch_updated
  before update on public.contact
  for each row execute function app.touch_updated();

drop trigger if exists contact_refresh on public.contact;
create constraint trigger contact_refresh
  after insert or update of first_name, middle_name, last_name, email_id, phone, mobile_no, is_primary_contact
  on public.contact
  deferrable initially deferred
  for each row execute function app.contact_refresh_trigger();

drop trigger if exists contact_email_validate on public.contact_email;
create trigger contact_email_validate
  before insert or update on public.contact_email
  for each row execute function app.contact_email_validate();

drop trigger if exists contact_phone_validate on public.contact_phone;
create trigger contact_phone_validate
  before insert or update on public.contact_phone
  for each row execute function app.contact_phone_validate();

drop trigger if exists contact_link_validate on public.contact_link;
create trigger contact_link_validate
  before insert or update of link_doctype, link_id on public.contact_link
  for each row execute function app.address_link_validate();

drop trigger if exists contact_email_refresh on public.contact_email;
create constraint trigger contact_email_refresh
  after insert or update or delete on public.contact_email
  deferrable initially deferred
  for each row execute function app.contact_refresh_trigger();

drop trigger if exists contact_phone_refresh on public.contact_phone;
create constraint trigger contact_phone_refresh
  after insert or update or delete on public.contact_phone
  deferrable initially deferred
  for each row execute function app.contact_refresh_trigger();

drop trigger if exists contact_link_refresh on public.contact_link;
create constraint trigger contact_link_refresh
  after insert or update or delete on public.contact_link
  deferrable initially deferred
  for each row execute function app.contact_refresh_trigger();

drop trigger if exists contact_match_member on public.org_members;
create trigger contact_match_member
  after insert on public.org_members
  for each row execute function app.contact_match_member();

-- Company "Default Sales Contact" (column created by 0100 ahead of this table).
alter table public.companies drop constraint if exists companies_default_sales_contact_fkey;
alter table public.companies add constraint companies_default_sales_contact_fkey
  foreign key (org_id, default_sales_contact_id) references public.contact (org_id, id) on delete set null (default_sales_contact_id);
create index if not exists companies_default_sales_contact_idx on public.companies (default_sales_contact_id);

------------------------------------------------------------------------------------------------------------------------
-- RLS (child rows delegate to the parent Contact permissions)
------------------------------------------------------------------------------------------------------------------------

alter table public.contact enable row level security;
alter table public.contact force row level security;

drop policy if exists contact_select on public.contact;
create policy contact_select on public.contact for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Contact', 'read'))::uuid[]));
drop policy if exists contact_insert on public.contact;
create policy contact_insert on public.contact for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Contact', 'create'))::uuid[]));
drop policy if exists contact_update on public.contact;
create policy contact_update on public.contact for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Contact', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Contact', 'write'))::uuid[]));
drop policy if exists contact_delete on public.contact;
create policy contact_delete on public.contact for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Contact', 'delete'))::uuid[]));

do $$
declare
  t text;
begin
  foreach t in array array['contact_email', 'contact_phone', 'contact_link'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_select', t);
    execute format('create policy %I on public.%I for select to authenticated
                      using (exists (select 1 from public.contact p where p.id = parent_id))', t || '_select', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert', t);
    execute format('create policy %I on public.%I for insert to authenticated
                      with check (org_id = any ((select app.orgs_with_perm(''Contact'', ''write''))::uuid[])
                                  or org_id = any ((select app.orgs_with_perm(''Contact'', ''create''))::uuid[]))', t || '_insert', t);
    execute format('drop policy if exists %I on public.%I', t || '_update', t);
    execute format('create policy %I on public.%I for update to authenticated
                      using (org_id = any ((select app.orgs_with_perm(''Contact'', ''write''))::uuid[]))
                      with check (org_id = any ((select app.orgs_with_perm(''Contact'', ''write''))::uuid[]))', t || '_update', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete', t);
    execute format('create policy %I on public.%I for delete to authenticated
                      using (org_id = any ((select app.orgs_with_perm(''Contact'', ''write''))::uuid[]))', t || '_delete', t);
  end loop;
end;
$$;

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (Frappe Contact JSON: Sales/Purchase/Maintenance/Accounts/Stock User and
-- Sales/Purchase Manager rwcd; System Manager rwcd)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Contact', 'contact', 'setup', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Contact Email', 'contact_email', 'setup', true, 'Contact', 'email_ids'),
       ('Contact Phone', 'contact_phone', 'setup', true, 'Contact', 'phone_nos'),
       ('Contact Link', 'contact_link', 'setup', true, 'Contact', 'links')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = excluded.is_child,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Contact', true, true, true, true),
       ('Sales User', 'Contact', true, true, true, true),
       ('Sales Manager', 'Contact', true, true, true, true),
       ('Purchase User', 'Contact', true, true, true, true),
       ('Purchase Manager', 'Contact', true, true, true, true),
       ('Maintenance User', 'Contact', true, true, true, true),
       ('Accounts User', 'Contact', true, true, true, true),
       ('Stock User', 'Contact', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
