-- 0104 setup: System Settings (Frappe), a single doctype (one row per org) holding the subset of fields that affects
-- our behaviour. docs/modules/00-setup.md §2.18.
-- Sources: frappe/core/doctype/system_settings/system_settings.json (options and defaults),
-- frappe/desk/page/setup_wizard/setup_wizard.py (update_system_settings: date/time format from the country,
-- number format from the currency), erpnext/setup/setup_wizard/operations/defaults_setup.py (email_footer_address).
-- Selects stay text with Frappe's option lists as check constraints. Also gives every standard role read access to
-- the Global Defaults and System Settings pages (members already read both rows through RLS).

create table if not exists public.system_settings (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null unique references public.organizations (id) on delete cascade,
  float_precision        text not null default '3' check (float_precision in ('2', '3', '4', '5', '6', '7', '8', '9')),
  currency_precision     text check (currency_precision in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')),
  date_format            text not null default 'dd-mm-yyyy'
    check (date_format in ('dd-mm-yyyy', 'dd.mm.yyyy', 'dd/mm/yyyy', 'mm/dd/yyyy', 'mm-dd-yyyy', 'yyyy-mm-dd')),
  time_format            text not null default 'HH:mm:ss' check (time_format in ('HH:mm:ss', 'HH:mm')),
  number_format          text not null default '#,###.##'
    check (number_format in ('#,###.##', '#.###,##', '# ###.##', '# ###,##', '#''###.##', '#, ###.##', '#,##,###.##',
                             '#,###.###', '#.###', '#,###')),
  first_day_of_the_week  text not null default 'Sunday'
    check (first_day_of_the_week in ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')),
  language               text not null default 'en',
  time_zone              text not null default 'UTC',
  email_footer_address   text,
  app_name               text not null default 'headless-erp',
  created_at             timestamptz not null default now(),
  created_by             uuid default auth.uid(),
  updated_at             timestamptz not null default now(),
  updated_by             uuid
);

drop trigger if exists touch_updated on public.system_settings;
create trigger touch_updated before update on public.system_settings
  for each row execute function app.touch_updated();

create or replace function app.system_settings_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.time_zone := coalesce(nullif(trim(new.time_zone), ''), 'UTC');
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.time_zone) then
    raise exception using errcode = 'P0001', message = format('time_zone_unknown: Unknown time zone: %s', new.time_zone);
  end if;
  return new;
end;
$$;

-- setup_wizard.update_system_settings: formats follow the country and currency picked for the organization.
create or replace function app.organizations_seed_system_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.system_settings (org_id, date_format, time_format, number_format, time_zone)
  select new.id,
         coalesce((select c.date_format from public.country c where c.country_name = new.country
                    and c.date_format in ('dd-mm-yyyy', 'dd.mm.yyyy', 'dd/mm/yyyy', 'mm/dd/yyyy', 'mm-dd-yyyy', 'yyyy-mm-dd')),
                  'dd-mm-yyyy'),
         coalesce((select c.time_format from public.country c where c.country_name = new.country
                    and c.time_format in ('HH:mm:ss', 'HH:mm')),
                  'HH:mm:ss'),
         coalesce((select cu.number_format from public.currency cu where cu.code = new.default_currency
                    and cu.number_format in ('#,###.##', '#.###,##', '# ###.##', '# ###,##', '#''###.##', '#, ###.##',
                                             '#,##,###.##', '#,###.###', '#.###', '#,###')),
                  '#,###.##'),
         coalesce((select z.name from pg_catalog.pg_timezone_names z where z.name = new.time_zone), 'UTC')
  on conflict (org_id) do nothing;
  return null;
end;
$$;

revoke execute on function app.system_settings_validate(), app.organizations_seed_system_settings()
from public, anon, authenticated;

drop trigger if exists system_settings_validate on public.system_settings;
create trigger system_settings_validate
  before insert or update on public.system_settings
  for each row execute function app.system_settings_validate();

drop trigger if exists organizations_seed_system_settings on public.organizations;
create trigger organizations_seed_system_settings
  after insert on public.organizations
  for each row execute function app.organizations_seed_system_settings();

------------------------------------------------------------------------------------------------------------------------
-- RLS: every member reads (formats apply to everyone); writes follow role_permissions. Rows are seeded, never inserted.
------------------------------------------------------------------------------------------------------------------------

alter table public.system_settings enable row level security;
alter table public.system_settings force row level security;

drop policy if exists system_settings_select on public.system_settings;
create policy system_settings_select on public.system_settings for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));
drop policy if exists system_settings_update on public.system_settings;
create policy system_settings_update on public.system_settings for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('System Settings', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('System Settings', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry, permissions (system_settings.json: System Manager rw), backfill
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_single)
values ('System Settings', 'system_settings', 'setup', true)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_single = excluded.is_single;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'System Settings', true, true, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

-- Deviation from Frappe (System Manager only): other roles can open both settings pages read-only.
insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
select r.name, d.doctype, true, false, false, false
from public.role_template r
cross join (values ('Global Defaults'), ('System Settings')) as d (doctype)
where r.name <> 'System Manager'
on conflict (role, doctype) do nothing;

select app.sync_role_permissions();

insert into public.system_settings (org_id, date_format, time_format, number_format, time_zone)
select o.id,
       coalesce(c.date_format, 'dd-mm-yyyy'),
       coalesce(c.time_format, 'HH:mm:ss'),
       coalesce(cu.number_format, '#,###.##'),
       coalesce((select z.name from pg_catalog.pg_timezone_names z where z.name = o.time_zone), 'UTC')
from public.organizations o
left join public.country c on c.country_name = o.country
  and c.date_format in ('dd-mm-yyyy', 'dd.mm.yyyy', 'dd/mm/yyyy', 'mm/dd/yyyy', 'mm-dd-yyyy', 'yyyy-mm-dd')
  and c.time_format in ('HH:mm:ss', 'HH:mm')
left join public.currency cu on cu.code = o.default_currency
  and cu.number_format in ('#,###.##', '#.###,##', '# ###.##', '# ###,##', '#''###.##', '#, ###.##', '#,##,###.##',
                           '#,###.###', '#.###', '#,###')
on conflict (org_id) do nothing;
