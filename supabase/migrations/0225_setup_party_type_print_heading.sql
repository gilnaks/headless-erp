-- 0225 setup: Party Type (A13) and Print Heading (A15).
-- ERPNext: erpnext/setup/doctype/party_type/party_type.json,
-- setup/setup_wizard/operations/install_fixtures.py (Customer, Supplier, Credit Note, Debit Note).
-- Frappe: printing/doctype/print_heading/print_heading.json (autoname field:print_heading, description).
-- Employee and Shareholder stay out. Party Type is read-only. Desk User read maps to the four module roles.

create table if not exists public.party_type (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  name         text not null check (length(trim(name)) > 0),
  account_type text not null check (account_type in ('Receivable', 'Payable')),
  created_at   timestamptz not null default now(),
  created_by   uuid default auth.uid(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid,
  unique (org_id, id)
);

create unique index if not exists party_type_name_uniq on public.party_type (org_id, lower(name));

create table if not exists public.print_heading (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations (id) on delete cascade,
  name           text not null,
  print_heading  text not null check (length(trim(print_heading)) > 0),
  description    text,
  created_at     timestamptz not null default now(),
  created_by     uuid default auth.uid(),
  updated_at     timestamptz not null default now(),
  updated_by     uuid,
  unique (org_id, id)
);

create unique index if not exists print_heading_name_uniq on public.print_heading (org_id, lower(print_heading));

create or replace function app.party_type_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := trim(new.name);
  return new;
end;
$$;

create or replace function app.print_heading_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.print_heading := trim(new.print_heading);
  new.name := new.print_heading;
  return new;
end;
$$;

create or replace function app.seed_party_types(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.party_type (org_id, name, account_type)
  values (p_org, 'Customer', 'Receivable'), (p_org, 'Supplier', 'Payable')
  on conflict (org_id, lower(name)) do nothing;
end;
$$;

create or replace function app.seed_print_headings(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.print_heading (org_id, print_heading)
  values (p_org, 'Credit Note'), (p_org, 'Debit Note')
  on conflict (org_id, lower(print_heading)) do nothing;
end;
$$;

create or replace function app.organizations_seed_party_and_print()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_party_types(new.id);
  perform app.seed_print_headings(new.id);
  return null;
end;
$$;

revoke execute on function
  app.party_type_validate(), app.print_heading_validate(),
  app.seed_party_types(uuid), app.seed_print_headings(uuid), app.organizations_seed_party_and_print()
from public, anon, authenticated;

drop trigger if exists party_type_validate on public.party_type;
create trigger party_type_validate before insert or update on public.party_type
  for each row execute function app.party_type_validate();
drop trigger if exists touch_updated on public.party_type;
create trigger touch_updated before update on public.party_type
  for each row execute function app.touch_updated();

drop trigger if exists print_heading_validate on public.print_heading;
create trigger print_heading_validate before insert or update on public.print_heading
  for each row execute function app.print_heading_validate();
drop trigger if exists touch_updated on public.print_heading;
create trigger touch_updated before update on public.print_heading
  for each row execute function app.touch_updated();

drop trigger if exists organizations_seed_party_and_print on public.organizations;
create trigger organizations_seed_party_and_print after insert on public.organizations
  for each row execute function app.organizations_seed_party_and_print();

select app.seed_party_types(o.id) from public.organizations o;
select app.seed_print_headings(o.id) from public.organizations o;

alter table public.party_type enable row level security;
alter table public.party_type force row level security;
alter table public.print_heading enable row level security;
alter table public.print_heading force row level security;

drop policy if exists party_type_select on public.party_type;
create policy party_type_select on public.party_type for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Party Type', 'read'))::uuid[]));
drop policy if exists party_type_insert on public.party_type;
create policy party_type_insert on public.party_type for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Party Type', 'create'))::uuid[]));
drop policy if exists party_type_update on public.party_type;
create policy party_type_update on public.party_type for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Party Type', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Party Type', 'write'))::uuid[]));
drop policy if exists party_type_delete on public.party_type;
create policy party_type_delete on public.party_type for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Party Type', 'delete'))::uuid[]));

drop policy if exists print_heading_select on public.print_heading;
create policy print_heading_select on public.print_heading for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Print Heading', 'read'))::uuid[]));
drop policy if exists print_heading_insert on public.print_heading;
create policy print_heading_insert on public.print_heading for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Print Heading', 'create'))::uuid[]));
drop policy if exists print_heading_update on public.print_heading;
create policy print_heading_update on public.print_heading for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Print Heading', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Print Heading', 'write'))::uuid[]));
drop policy if exists print_heading_delete on public.print_heading;
create policy print_heading_delete on public.print_heading for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Print Heading', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values
  ('Party Type', 'party_type', 'accounts', 'name'),
  ('Print Heading', 'print_heading', 'setup', 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Party Type', true, false, false, false),
  ('Accounts Manager', 'Party Type', true, false, false, false),
  ('Accounts User', 'Party Type', true, false, false, false),
  ('System Manager', 'Print Heading', true, true, true, true),
  ('Accounts Manager', 'Print Heading', true, false, false, false),
  ('Accounts User', 'Print Heading', true, false, false, false),
  ('Sales User', 'Print Heading', true, false, false, false),
  ('Purchase User', 'Print Heading', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
