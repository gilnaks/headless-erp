-- 0114 accounts: Fiscal Year -> public.fiscal_year + child public.fiscal_year_company (docs/modules/00-setup.md §2.23).
-- ERPNext sources: erpnext/accounts/doctype/fiscal_year/fiscal_year.json, fiscal_year.py (validate_dates,
-- validate_overlap, auto_create_fiscal_year), fiscal_year.js, erpnext/accounts/doctype/fiscal_year_company/
-- fiscal_year_company.json, erpnext/setup/setup_wizard/operations/install_fixtures.py (get_fy_details).

create extension if not exists pg_cron;

create table if not exists public.fiscal_year (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations (id) on delete cascade,
  year            text not null check (length(trim(year)) > 0),
  year_start_date date not null,
  year_end_date   date not null,
  disabled        boolean not null default false,
  is_short_year   boolean not null default false,
  auto_created    boolean not null default false,
  created_at      timestamptz not null default now(),
  created_by      uuid default auth.uid(),
  updated_at      timestamptz not null default now(),
  updated_by      uuid,
  unique (org_id, id)
);

create unique index if not exists fiscal_year_year_uniq on public.fiscal_year (org_id, lower(year));
create index if not exists fiscal_year_dates_idx on public.fiscal_year (org_id, year_start_date, year_end_date);

create table if not exists public.fiscal_year_company (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null,
  parent_id  uuid not null,
  idx        int not null,
  company_id uuid not null,
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, company_id),
  foreign key (org_id, parent_id) references public.fiscal_year (org_id, id) on delete cascade,
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade
);

create index if not exists fiscal_year_company_company_idx on public.fiscal_year_company (company_id);

-- install_fixtures.get_fy_details: "2026" when the year starts and ends in the same calendar year, else "2026-2027".
create or replace function app.fiscal_year_name(p_start date, p_end date)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when extract(year from p_start) = extract(year from p_end)
              then extract(year from p_start)::int::text
              else extract(year from p_start)::int::text || '-' || extract(year from p_end)::int::text end;
$$;

-- validate_dates (Frappe validate_from_to_dates + one-year rule unless is_short_year); an empty year is named from
-- the dates.
create or replace function app.fiscal_year_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.year := nullif(trim(new.year), '');
  if new.year_start_date > new.year_end_date then
    raise exception using errcode = 'P0001', message = 'fiscal_year_dates: Year End Date must be after Year Start Date';
  end if;
  if not new.is_short_year and new.year_end_date <> (new.year_start_date + interval '1 year' - interval '1 day')::date then
    raise exception using errcode = 'P0001',
      message = 'fiscal_year_dates: Fiscal Year End Date should be one year after Fiscal Year Start Date';
  end if;
  new.year := coalesce(new.year, app.fiscal_year_name(new.year_start_date, new.year_end_date));
  return new;
end;
$$;

-- validate_overlap over the whole document (dates + company rows), deferred to commit like Holiday List: another
-- fiscal year with overlapping dates conflicts when neither has companies or they share one.
create or replace function app.fiscal_year_check_overlap(p_fy uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fy public.fiscal_year;
  v_other text;
begin
  select * into v_fy from public.fiscal_year where id = p_fy;
  if not found then
    return;
  end if;

  select o.year into v_other
    from public.fiscal_year o
   where o.org_id = v_fy.org_id and o.id <> v_fy.id
     and o.year_start_date <= v_fy.year_end_date and o.year_end_date >= v_fy.year_start_date
     and (
       (not exists (select 1 from public.fiscal_year_company c where c.parent_id = v_fy.id)
        and not exists (select 1 from public.fiscal_year_company c where c.parent_id = o.id))
       or exists (select 1 from public.fiscal_year_company c
                    join public.fiscal_year_company oc on oc.company_id = c.company_id
                   where c.parent_id = v_fy.id and oc.parent_id = o.id)
     )
   order by o.year_start_date
   limit 1;
  if found then
    raise exception using errcode = 'P0001',
      message = format('fiscal_year_overlap: Year start date or end date is overlapping with %s. To avoid please set company', v_other);
  end if;
end;
$$;

create or replace function app.fiscal_year_check_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'fiscal_year_company' then
    perform app.fiscal_year_check_overlap(coalesce(new.parent_id, old.parent_id));
  else
    perform app.fiscal_year_check_overlap(new.id);
  end if;
  return null;
end;
$$;

-- fiscal_year.auto_create_fiscal_year (ERPNext daily scheduler): for every non-short year ending within 3 days, create
-- the next one (same companies, disabled copied, auto_created) unless its name exists. A conflicting year is skipped.
create or replace function app.auto_create_fiscal_year()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fy public.fiscal_year;
  v_start date;
  v_end date;
  v_year text;
  v_new uuid;
  v_created int := 0;
begin
  for v_fy in
    select * from public.fiscal_year
     where year_end_date <= current_date + 3 and not is_short_year
     order by org_id, year_end_date
  loop
    v_start := v_fy.year_end_date + 1;
    v_end := (v_start + interval '1 year' - interval '1 day')::date;
    v_year := app.fiscal_year_name(v_start, v_end);
    continue when exists (select 1 from public.fiscal_year where org_id = v_fy.org_id and lower(year) = lower(v_year));
    begin
      insert into public.fiscal_year (org_id, year, year_start_date, year_end_date, disabled, auto_created, created_by)
      values (v_fy.org_id, v_year, v_start, v_end, v_fy.disabled, true, null)
      returning id into v_new;
      insert into public.fiscal_year_company (org_id, parent_id, idx, company_id)
      select v_fy.org_id, v_new, c.idx, c.company_id from public.fiscal_year_company c where c.parent_id = v_fy.id;
      perform app.fiscal_year_check_overlap(v_new);
      v_created := v_created + 1;
    exception when others then
      null;
    end;
  end loop;
  return v_created;
end;
$$;

revoke execute on function
  app.fiscal_year_name(date, date), app.fiscal_year_validate(), app.fiscal_year_check_overlap(uuid),
  app.fiscal_year_check_trigger(), app.auto_create_fiscal_year()
from public, anon, authenticated;
grant execute on function app.fiscal_year_name(date, date) to authenticated;

drop trigger if exists fiscal_year_validate on public.fiscal_year;
create trigger fiscal_year_validate
  before insert or update on public.fiscal_year
  for each row execute function app.fiscal_year_validate();

drop trigger if exists touch_updated on public.fiscal_year;
create trigger touch_updated
  before update on public.fiscal_year
  for each row execute function app.touch_updated();

drop trigger if exists fiscal_year_check on public.fiscal_year;
create constraint trigger fiscal_year_check
  after insert or update of year_start_date, year_end_date on public.fiscal_year
  deferrable initially deferred
  for each row execute function app.fiscal_year_check_trigger();

drop trigger if exists fiscal_year_company_check on public.fiscal_year_company;
create constraint trigger fiscal_year_company_check
  after insert or update on public.fiscal_year_company
  deferrable initially deferred
  for each row execute function app.fiscal_year_check_trigger();

-- Daily, like ERPNext's scheduler (`daily_long`). Re-running the migration replaces the job.
select cron.schedule('auto-create-fiscal-year', '15 0 * * *', 'select app.auto_create_fiscal_year()');

------------------------------------------------------------------------------------------------------------------------
-- RLS (child rows delegate to the parent's Fiscal Year permissions)
------------------------------------------------------------------------------------------------------------------------

alter table public.fiscal_year enable row level security;
alter table public.fiscal_year force row level security;
alter table public.fiscal_year_company enable row level security;
alter table public.fiscal_year_company force row level security;

drop policy if exists fiscal_year_select on public.fiscal_year;
create policy fiscal_year_select on public.fiscal_year for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'read'))::uuid[]));
drop policy if exists fiscal_year_insert on public.fiscal_year;
create policy fiscal_year_insert on public.fiscal_year for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'create'))::uuid[]));
drop policy if exists fiscal_year_update on public.fiscal_year;
create policy fiscal_year_update on public.fiscal_year for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'write'))::uuid[]));
drop policy if exists fiscal_year_delete on public.fiscal_year;
create policy fiscal_year_delete on public.fiscal_year for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'delete'))::uuid[]));

drop policy if exists fiscal_year_company_select on public.fiscal_year_company;
create policy fiscal_year_company_select on public.fiscal_year_company for select to authenticated
  using (exists (select 1 from public.fiscal_year p where p.id = parent_id));
drop policy if exists fiscal_year_company_insert on public.fiscal_year_company;
create policy fiscal_year_company_insert on public.fiscal_year_company for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Fiscal Year', 'create'))::uuid[]));
drop policy if exists fiscal_year_company_update on public.fiscal_year_company;
create policy fiscal_year_company_update on public.fiscal_year_company for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'write'))::uuid[]));
drop policy if exists fiscal_year_company_delete on public.fiscal_year_company;
create policy fiscal_year_company_delete on public.fiscal_year_company for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Fiscal Year', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (JSON: System Manager rwcd; read for Sales/Purchase/Accounts/Stock User, Employee,
-- Accounts Manager, Stock Manager, Auditor)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Fiscal Year', 'fiscal_year', 'accounts', 'year')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Fiscal Year Company', 'fiscal_year_company', 'accounts', true, 'Fiscal Year', 'companies')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = excluded.is_child,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Fiscal Year', true, true, true, true),
       ('Sales User', 'Fiscal Year', true, false, false, false),
       ('Purchase User', 'Fiscal Year', true, false, false, false),
       ('Accounts User', 'Fiscal Year', true, false, false, false),
       ('Stock User', 'Fiscal Year', true, false, false, false),
       ('Employee', 'Fiscal Year', true, false, false, false),
       ('Accounts Manager', 'Fiscal Year', true, false, false, false),
       ('Stock Manager', 'Fiscal Year', true, false, false, false),
       ('Auditor', 'Fiscal Year', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
