-- 0224 accounts: Currency Exchange (docs/modules/01-accounts.md §2.8).
-- ERPNext: erpnext/setup/doctype/currency_exchange/currency_exchange.json,
-- erpnext/setup/utils.py get_exchange_rate (stored-rate path only).
-- No frankfurter call. allow_stale and stale_days wait for Accounts Settings, so every row on or before the date is eligible.

create table if not exists public.currency_exchange (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations (id) on delete cascade,
  name          text not null,
  date          date not null default current_date,
  from_currency text not null references public.currency (code),
  to_currency   text not null references public.currency (code),
  exchange_rate numeric(21,9) not null,
  for_buying    boolean not null default true,
  for_selling   boolean not null default true,
  created_at    timestamptz not null default now(),
  created_by    uuid default auth.uid(),
  updated_at    timestamptz not null default now(),
  updated_by    uuid,
  unique (org_id, id),
  unique (org_id, name)
);

create index if not exists currency_exchange_from_idx on public.currency_exchange (from_currency);
create index if not exists currency_exchange_to_idx on public.currency_exchange (to_currency);
create index if not exists currency_exchange_lookup_idx
  on public.currency_exchange (org_id, from_currency, to_currency, date desc);

create or replace function app.currency_exchange_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_side text;
begin
  if new.from_currency = new.to_currency then
    raise exception using errcode = 'P0001',
      message = 'currency_exchange_same: From Currency and To Currency cannot be same';
  end if;
  if new.exchange_rate <= 0 then
    raise exception using errcode = 'P0001',
      message = 'currency_exchange_rate: Exchange Rate must be greater than zero';
  end if;
  if not new.for_buying and not new.for_selling then
    raise exception using errcode = 'P0001',
      message = 'currency_exchange_side: Currency Exchange must be applicable for Buying or for Selling';
  end if;
  v_side := case
    when new.for_buying and new.for_selling then 'Selling-Buying'
    when new.for_selling then 'Selling'
    else 'Buying'
  end;
  new.name := to_char(new.date, 'YYYY-MM-DD') || '-' || new.from_currency || '-' || new.to_currency || '-' || v_side;
  return new;
end;
$$;

create or replace function app.get_exchange_rate(
  p_org uuid, p_from text, p_to text, p_date date, p_side text default 'selling'
)
returns numeric
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_rate numeric;
begin
  if p_from = p_to then
    return 1;
  end if;
  select exchange_rate into v_rate
    from public.currency_exchange
   where org_id = p_org
     and from_currency = p_from
     and to_currency = p_to
     and date <= coalesce(p_date, current_date)
     and ((p_side = 'buying' and for_buying) or (p_side <> 'buying' and for_selling))
   order by date desc
   limit 1;
  return coalesce(v_rate, 0);
end;
$$;

create or replace function public.get_exchange_rate(
  p_org uuid, p_from text, p_to text, p_date date, p_side text default 'selling'
)
returns numeric
language sql
stable
security invoker
set search_path = ''
as $$
  select app.get_exchange_rate(p_org, p_from, p_to, p_date, p_side);
$$;

revoke execute on function app.currency_exchange_validate() from public, anon, authenticated;
revoke execute on function app.get_exchange_rate(uuid, text, text, date, text) from public, anon;
grant execute on function app.get_exchange_rate(uuid, text, text, date, text) to authenticated;
revoke execute on function public.get_exchange_rate(uuid, text, text, date, text) from public, anon;
grant execute on function public.get_exchange_rate(uuid, text, text, date, text) to authenticated;

drop trigger if exists currency_exchange_validate on public.currency_exchange;
create trigger currency_exchange_validate before insert or update on public.currency_exchange
  for each row execute function app.currency_exchange_validate();
drop trigger if exists touch_updated on public.currency_exchange;
create trigger touch_updated before update on public.currency_exchange
  for each row execute function app.touch_updated();

alter table public.currency_exchange enable row level security;
alter table public.currency_exchange force row level security;

drop policy if exists currency_exchange_select on public.currency_exchange;
create policy currency_exchange_select on public.currency_exchange for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Currency Exchange', 'read'))::uuid[]));
drop policy if exists currency_exchange_insert on public.currency_exchange;
create policy currency_exchange_insert on public.currency_exchange for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Currency Exchange', 'create'))::uuid[]));
drop policy if exists currency_exchange_update on public.currency_exchange;
create policy currency_exchange_update on public.currency_exchange for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Currency Exchange', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Currency Exchange', 'write'))::uuid[]));
drop policy if exists currency_exchange_delete on public.currency_exchange;
create policy currency_exchange_delete on public.currency_exchange for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Currency Exchange', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Currency Exchange', 'currency_exchange', 'accounts', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Currency Exchange', true, false, false, false),
  ('Accounts Manager', 'Currency Exchange', true, true, true, true),
  ('Accounts User', 'Currency Exchange', true, false, false, false),
  ('Sales User', 'Currency Exchange', true, false, false, false),
  ('Purchase User', 'Currency Exchange', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
