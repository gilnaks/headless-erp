-- 0007 framework: naming series counters + app.next_name().
-- Port of frappe/model/naming.py (parse_naming_series, getseries, make_autoname): a series template such as
-- 'ACC-SINV-.YYYY.-' is split on '.', date tokens are resolved, and the counter is keyed by the resolved prefix
-- (e.g. 'ACC-SINV-2026-'), exactly like Frappe's `tabSeries`. A new year therefore starts a new counter.
-- Templates without a '#' part get '.#####' appended, as in make_autoname.
-- Supported tokens: YYYY, YY, MM, DD, WW (ISO week), ABBR (company abbreviation), #… (counter, width = number of
-- '#'). Anything else is copied literally. FY and {field} tokens are added when a doctype needs them.

create table if not exists public.naming_series (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  prefix     text not null check (length(prefix) > 0),
  current    bigint not null default 0 check (current >= 0),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (org_id, id),
  unique (org_id, prefix)
);

drop trigger if exists touch_updated on public.naming_series;
create trigger touch_updated before update on public.naming_series
  for each row execute function app.touch_updated();

alter table public.naming_series enable row level security;
alter table public.naming_series force row level security;

-- Members read counters; System Manager may adjust them ("Update Series Counter"). Names are issued only by
-- app.next_name(), which runs as definer.
drop policy if exists naming_series_select on public.naming_series;
create policy naming_series_select on public.naming_series for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));
drop policy if exists naming_series_update on public.naming_series;
create policy naming_series_update on public.naming_series for update to authenticated
  using (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_role('System Manager'))::uuid[]));

create or replace function app.next_name(p_org uuid, p_company uuid, p_series text, p_posting_date date default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_date date := coalesce(p_posting_date, current_date);
  v_template text := trim(p_series);
  v_part text;
  v_name text := '';
  v_abbr text;
  v_digits int;
  v_current bigint;
begin
  if p_org is null then
    raise exception using errcode = 'P0001', message = 'naming_org_required: organization is required for naming';
  end if;
  if v_template is null or v_template = '' then
    raise exception using errcode = 'P0001', message = 'naming_series_required: Naming Series is mandatory';
  end if;
  if position('#' in v_template) = 0 then
    v_template := v_template || '.#####';
  end if;

  foreach v_part in array string_to_array(v_template, '.') loop
    if v_part = '' then
      continue;
    elsif v_part ~ '^#+$' then
      v_digits := length(v_part);
      perform pg_advisory_xact_lock(hashtextextended(p_org::text || ':' || v_name, 0));
      insert into public.naming_series as s (org_id, prefix, current)
      values (p_org, v_name, 1)
      on conflict (org_id, prefix) do update set current = s.current + 1
      returning s.current into v_current;
      v_part := lpad(v_current::text, greatest(v_digits, length(v_current::text)), '0');
    elsif v_part = 'YYYY' then
      v_part := to_char(v_date, 'YYYY');
    elsif v_part = 'YY' then
      v_part := to_char(v_date, 'YY');
    elsif v_part = 'MM' then
      v_part := to_char(v_date, 'MM');
    elsif v_part = 'DD' then
      v_part := to_char(v_date, 'DD');
    elsif v_part = 'WW' then
      v_part := to_char(v_date, 'IW');
    elsif v_part = 'ABBR' then
      select c.abbr into v_abbr from public.companies c where c.id = p_company and c.org_id = p_org;
      if v_abbr is null then
        raise exception using errcode = 'P0001', message = 'naming_company_required: Company is required for series with .ABBR.';
      end if;
      v_part := v_abbr;
    end if;
    v_name := v_name || v_part;
  end loop;

  return v_name;
end;
$$;

revoke execute on function app.next_name(uuid, uuid, text, date) from public, anon, authenticated;

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Naming Series', 'naming_series', 'setup', 'prefix')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;
