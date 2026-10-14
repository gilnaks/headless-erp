-- 0103 setup: Global Defaults, a single doctype (one row per org). docs/modules/00-setup.md §2.17.
-- ERPNext sources: erpnext/setup/doctype/global_defaults/global_defaults.{json,py},
-- erpnext/setup/setup_wizard/operations/install_fixtures.py (set_global_defaults).
-- Deviations: `enable_item_search_index` and the hidden `demo_company` are dropped; ERPNext's `on_update` pushes the
-- values into user defaults, ours are read directly by Server Components. Currency enabling maps to `org_currency`.

alter table public.doctype_meta add column if not exists is_single boolean not null default false;
comment on column public.doctype_meta.is_single is 'Frappe issingle: one row per org, seeded with the organization.';

create table if not exists public.global_defaults (
  id                                         uuid primary key default gen_random_uuid(),
  org_id                                     uuid not null unique references public.organizations (id) on delete cascade,
  default_company_id                         uuid references public.companies (id) on delete set null,
  country                                    text references public.country (country_name) on update cascade,
  default_currency                           text references public.currency (code) on update cascade,
  default_distance_unit                      text references public.uom_template (uom_name) on update cascade,
  hide_currency_symbol                       boolean not null default false,
  disable_rounded_total                      boolean not null default false,
  disable_in_words                           boolean not null default false,
  use_posting_datetime_for_naming_documents  boolean not null default true,
  created_at                                 timestamptz not null default now(),
  created_by                                 uuid default auth.uid(),
  updated_at                                 timestamptz not null default now(),
  updated_by                                 uuid
);

create index if not exists global_defaults_default_company_idx on public.global_defaults (default_company_id);

drop trigger if exists touch_updated on public.global_defaults;
create trigger touch_updated before update on public.global_defaults
  for each row execute function app.touch_updated();

------------------------------------------------------------------------------------------------------------------------
-- Validation and side effects (security definer: the helpers are not executable by API roles)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.global_defaults_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.validate_country_currency(new.country, new.default_currency);
  if new.default_company_id is not null
     and not exists (select 1 from public.companies c where c.id = new.default_company_id and c.org_id = new.org_id) then
    raise exception using errcode = 'P0001', message = 'company_unknown: Could not find Company';
  end if;
  return new;
end;
$$;

-- GlobalDefaults.on_update: "enable default currency".
create or replace function app.global_defaults_enable_currency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.default_currency is not null then
    perform app.enable_org_currency(new.org_id, new.default_currency);
  end if;
  return null;
end;
$$;

-- Seeded with every organization (install_fixtures.set_global_defaults: country + currency from the wizard).
create or replace function app.organizations_seed_global_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.global_defaults (org_id, country, default_currency)
  values (new.id, new.country, new.default_currency)
  on conflict (org_id) do nothing;
  return null;
end;
$$;

-- The first company becomes the default company (set_global_defaults uses the wizard's company).
create or replace function app.companies_set_default_company()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.global_defaults set default_company_id = new.id
  where org_id = new.org_id and default_company_id is null;
  return null;
end;
$$;

revoke execute on function
  app.global_defaults_validate(), app.global_defaults_enable_currency(),
  app.organizations_seed_global_defaults(), app.companies_set_default_company()
from public, anon, authenticated;

drop trigger if exists global_defaults_validate on public.global_defaults;
create trigger global_defaults_validate
  before insert or update on public.global_defaults
  for each row execute function app.global_defaults_validate();

drop trigger if exists global_defaults_enable_currency on public.global_defaults;
create trigger global_defaults_enable_currency
  after insert or update of default_currency on public.global_defaults
  for each row execute function app.global_defaults_enable_currency();

drop trigger if exists organizations_seed_global_defaults on public.organizations;
create trigger organizations_seed_global_defaults
  after insert on public.organizations
  for each row execute function app.organizations_seed_global_defaults();

drop trigger if exists companies_set_default_company on public.companies;
create trigger companies_set_default_company
  after insert on public.companies
  for each row execute function app.companies_set_default_company();

------------------------------------------------------------------------------------------------------------------------
-- RLS: every member reads (defaults drive forms); writes follow role_permissions. No insert/delete: rows are seeded.
------------------------------------------------------------------------------------------------------------------------

alter table public.global_defaults enable row level security;
alter table public.global_defaults force row level security;

drop policy if exists global_defaults_select on public.global_defaults;
create policy global_defaults_select on public.global_defaults for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));
drop policy if exists global_defaults_update on public.global_defaults;
create policy global_defaults_update on public.global_defaults for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Global Defaults', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Global Defaults', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry, permissions (global_defaults.json: System Manager rwc), backfill
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_single)
values ('Global Defaults', 'global_defaults', 'setup', true)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_single = excluded.is_single;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Global Defaults', true, true, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

insert into public.global_defaults (org_id, country, default_currency, default_company_id)
select o.id, o.country, o.default_currency,
       (select c.id from public.companies c where c.org_id = o.id order by c.created_at, c.id limit 1)
from public.organizations o
on conflict (org_id) do nothing;
