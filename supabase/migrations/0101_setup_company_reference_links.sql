-- 0101 setup: Company links to the global Country / Currency tables (0009).
-- Frappe validate_links ("Could not find Currency: X") runs after companies_validate has filled the org defaults, so the
-- trigger name sorts after it (same-timing triggers fire alphabetically). Company.on_update enables the company
-- currency (ERPNext Company.validate_currency → Currency.enabled), which here is the per-org org_currency row.
-- Security definer: the helpers they call are not executable by API roles.

create or replace function app.companies_validate_links()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.validate_country_currency(new.country, new.default_currency);
  return new;
end;
$$;

create or replace function app.companies_enable_currency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.enable_org_currency(new.org_id, new.default_currency);
  return null;
end;
$$;

revoke execute on function app.companies_validate_links(), app.companies_enable_currency() from public, anon, authenticated;

drop trigger if exists companies_validate_links on public.companies;
create trigger companies_validate_links
  before insert or update on public.companies
  for each row execute function app.companies_validate_links();

drop trigger if exists companies_enable_currency on public.companies;
create trigger companies_enable_currency
  after insert or update of default_currency on public.companies
  for each row execute function app.companies_enable_currency();

alter table public.companies drop constraint if exists companies_country_fkey;
alter table public.companies add constraint companies_country_fkey
  foreign key (country) references public.country (country_name) on update cascade;
alter table public.companies drop constraint if exists companies_default_currency_fkey;
alter table public.companies add constraint companies_default_currency_fkey
  foreign key (default_currency) references public.currency (code) on update cascade;
alter table public.companies drop constraint if exists companies_reporting_currency_fkey;
alter table public.companies add constraint companies_reporting_currency_fkey
  foreign key (reporting_currency) references public.currency (code) on update cascade;

insert into public.org_currency (org_id, code)
select org_id, default_currency from public.companies
on conflict do nothing;
