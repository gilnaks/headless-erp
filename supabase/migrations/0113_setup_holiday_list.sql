-- 0113 setup: Holiday List -> public.holiday_list + child public.holiday (docs/modules/00-setup.md §2.5).
-- ERPNext sources: erpnext/setup/doctype/holiday_list/holiday_list.json, holiday_list.py (validate_days,
-- update_total_holidays, validate_duplicate_date, sort_holidays, is_holiday, is_half_holiday),
-- erpnext/setup/doctype/holiday/holiday.json.

create table if not exists public.holiday_list (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations (id) on delete cascade,
  holiday_list_name text not null check (length(trim(holiday_list_name)) > 0),
  from_date         date not null,
  to_date           date not null,
  total_holidays    numeric(21, 9) not null default 0,
  weekly_off        text check (weekly_off in ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')),
  is_half_day       boolean not null default false,
  color             text check (color ~* '^#[0-9a-f]{6}$'),
  country           text references public.country (country_name),
  subdivision       text,
  created_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  updated_at        timestamptz not null default now(),
  updated_by        uuid,
  unique (org_id, id)
);

create unique index if not exists holiday_list_name_uniq on public.holiday_list (org_id, lower(holiday_list_name));

create table if not exists public.holiday (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null,
  parent_id    uuid not null,
  idx          int not null,
  holiday_date date not null,
  description  text not null check (length(trim(description)) > 0),
  weekly_off   boolean not null default false,
  is_half_day  boolean not null default false,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.holiday_list (org_id, id) on delete cascade
);

create index if not exists holiday_parent_date_idx on public.holiday (parent_id, holiday_date);

-- Header checks that need no rows: trimmed name, empty weekly off -> null, validate_days (from <= to).
create or replace function app.holiday_list_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.holiday_list_name := trim(new.holiday_list_name);
  new.weekly_off := nullif(new.weekly_off, '');
  new.subdivision := nullif(trim(new.subdivision), '');
  if new.from_date > new.to_date then
    raise exception using errcode = 'P0001', message = 'holiday_dates: To Date cannot be before From Date';
  end if;
  return new;
end;
$$;

-- HolidayList.validate over the whole document (header + rows), so it runs as a deferred constraint trigger at the
-- end of the transaction that saved it (app.save_doc writes the header before the rows). Holidays inside the dates,
-- no duplicate dates, rows ordered by (weekly_off, holiday_date) and re-indexed, total_holidays with half days as 0.5.
create or replace function app.holiday_list_refresh(p_list uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_list public.holiday_list;
  v_date date;
begin
  select * into v_list from public.holiday_list where id = p_list;
  if not found then
    return;
  end if;

  select h.holiday_date into v_date from public.holiday h
   where h.parent_id = p_list and h.holiday_date not between v_list.from_date and v_list.to_date
   order by h.holiday_date limit 1;
  if found then
    raise exception using errcode = 'P0001',
      message = format('holiday_out_of_range: The holiday on %s is not between From Date and To Date', v_date);
  end if;

  select h.holiday_date into v_date from public.holiday h
   where h.parent_id = p_list group by h.holiday_date having count(*) > 1
   order by h.holiday_date limit 1;
  if found then
    raise exception using errcode = 'P0001', message = format('holiday_duplicate: Holiday Date %s added multiple times', v_date);
  end if;

  update public.holiday h set idx = o.rn
    from (select id, row_number() over (order by weekly_off, holiday_date, idx)::int as rn
            from public.holiday where parent_id = p_list) o
   where h.id = o.id and h.idx <> o.rn;

  update public.holiday_list l
     set total_holidays = coalesce((select sum(case when h.is_half_day then 0.5 else 1 end)
                                      from public.holiday h where h.parent_id = p_list), 0)
   where l.id = p_list
     and l.total_holidays is distinct from coalesce((select sum(case when h.is_half_day then 0.5 else 1 end)
                                                       from public.holiday h where h.parent_id = p_list), 0);
end;
$$;

create or replace function app.holiday_list_refresh_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'holiday' then
    perform app.holiday_list_refresh(coalesce(new.parent_id, old.parent_id));
  else
    perform app.holiday_list_refresh(new.id);
  end if;
  return null;
end;
$$;

-- holiday_list.py is_holiday / is_half_holiday (used by Workstation / Job Card scheduling). RLS applies.
create or replace function app.is_holiday(p_list uuid, p_date date default current_date)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.holiday h where h.parent_id = p_list and h.holiday_date = p_date and not h.is_half_day);
$$;

create or replace function app.is_half_holiday(p_list uuid, p_date date default current_date)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.holiday h where h.parent_id = p_list and h.holiday_date = p_date and h.is_half_day);
$$;

revoke execute on function
  app.holiday_list_validate(), app.holiday_list_refresh(uuid), app.holiday_list_refresh_trigger(),
  app.is_holiday(uuid, date), app.is_half_holiday(uuid, date)
from public, anon, authenticated;
grant execute on function app.is_holiday(uuid, date), app.is_half_holiday(uuid, date) to authenticated;

drop trigger if exists holiday_list_validate on public.holiday_list;
create trigger holiday_list_validate
  before insert or update on public.holiday_list
  for each row execute function app.holiday_list_validate();

drop trigger if exists touch_updated on public.holiday_list;
create trigger touch_updated
  before update on public.holiday_list
  for each row execute function app.touch_updated();

drop trigger if exists holiday_list_refresh on public.holiday_list;
create constraint trigger holiday_list_refresh
  after insert or update of from_date, to_date on public.holiday_list
  deferrable initially deferred
  for each row execute function app.holiday_list_refresh_trigger();

drop trigger if exists holiday_refresh on public.holiday;
create constraint trigger holiday_refresh
  after insert or update or delete on public.holiday
  deferrable initially deferred
  for each row execute function app.holiday_list_refresh_trigger();

-- Company "Default Holiday List" (column created by 0100 ahead of this table). A list in use cannot be deleted.
alter table public.companies drop constraint if exists companies_default_holiday_list_fkey;
alter table public.companies add constraint companies_default_holiday_list_fkey
  foreign key (org_id, default_holiday_list_id) references public.holiday_list (org_id, id);

------------------------------------------------------------------------------------------------------------------------
-- RLS (child rows delegate to the parent's Holiday List permissions)
------------------------------------------------------------------------------------------------------------------------

alter table public.holiday_list enable row level security;
alter table public.holiday_list force row level security;
alter table public.holiday enable row level security;
alter table public.holiday force row level security;

drop policy if exists holiday_list_select on public.holiday_list;
create policy holiday_list_select on public.holiday_list for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Holiday List', 'read'))::uuid[]));
drop policy if exists holiday_list_insert on public.holiday_list;
create policy holiday_list_insert on public.holiday_list for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Holiday List', 'create'))::uuid[]));
drop policy if exists holiday_list_update on public.holiday_list;
create policy holiday_list_update on public.holiday_list for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Holiday List', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Holiday List', 'write'))::uuid[]));
drop policy if exists holiday_list_delete on public.holiday_list;
create policy holiday_list_delete on public.holiday_list for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Holiday List', 'delete'))::uuid[]));

drop policy if exists holiday_select on public.holiday;
create policy holiday_select on public.holiday for select to authenticated
  using (exists (select 1 from public.holiday_list p where p.id = parent_id));
drop policy if exists holiday_insert on public.holiday;
create policy holiday_insert on public.holiday for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Holiday List', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Holiday List', 'create'))::uuid[]));
drop policy if exists holiday_update on public.holiday;
create policy holiday_update on public.holiday for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Holiday List', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Holiday List', 'write'))::uuid[]));
drop policy if exists holiday_delete on public.holiday;
create policy holiday_delete on public.holiday for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Holiday List', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (JSON: HR Manager rwcd + HR/Accounts/Sales read are out of scope or dropped ->
-- System Manager rwcd; Manufacturing Manager/User and Projects Manager/User read)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Holiday List', 'holiday_list', 'setup', 'holiday_list_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Holiday', 'holiday', 'setup', true, 'Holiday List', 'holidays')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_child = excluded.is_child,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Holiday List', true, true, true, true),
       ('Manufacturing Manager', 'Holiday List', true, false, false, false),
       ('Manufacturing User', 'Holiday List', true, false, false, false),
       ('Projects Manager', 'Holiday List', true, false, false, false),
       ('Projects User', 'Holiday List', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
