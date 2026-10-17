-- 0234 stock: Price List (docs/modules/04-stock.md §2.6, 00-setup C1).
-- ERPNext: erpnext/stock/doctype/price_list/price_list.json.
-- The first company in an organization seeds Standard Selling and Standard Buying.
-- A later company does not add another pair. Item Price waits for Item.

create table if not exists public.price_list (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  name                    text not null,
  price_list_name         text not null check (length(trim(price_list_name)) > 0),
  currency                text not null references public.currency (code),
  enabled                 boolean not null default true,
  buying                  boolean not null default false,
  selling                 boolean not null default false,
  price_not_uom_dependent boolean not null default false,
  created_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  updated_at              timestamptz not null default now(),
  updated_by              uuid,
  unique (org_id, id),
  check (buying or selling)
);

create unique index if not exists price_list_name_uniq on public.price_list (org_id, lower(price_list_name));

create or replace function app.price_list_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.price_list_name := trim(new.price_list_name);
  new.name := new.price_list_name;
  if not new.buying and not new.selling then
    raise exception using errcode = 'P0001',
      message = 'price_list_side: At least one of Buying or Selling must be selected';
  end if;
  return new;
end;
$$;

create or replace function app.seed_price_lists(p_org uuid, p_currency text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_currency is null or exists (select 1 from public.price_list where org_id = p_org) then
    return;
  end if;
  insert into public.price_list (org_id, price_list_name, currency, enabled, buying, selling)
  values
    (p_org, 'Standard Selling', p_currency, true, false, true),
    (p_org, 'Standard Buying', p_currency, true, true, false);
end;
$$;

create or replace function app.companies_seed_price_lists()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_price_lists(new.org_id, coalesce(
    (select default_currency from public.organizations where id = new.org_id),
    new.default_currency
  ));
  return null;
end;
$$;

revoke all on function app.price_list_validate() from public, anon, authenticated;
revoke all on function app.seed_price_lists(uuid, text) from public, anon, authenticated;
revoke all on function app.companies_seed_price_lists() from public, anon, authenticated;

drop trigger if exists price_list_validate on public.price_list;
create trigger price_list_validate before insert or update on public.price_list
  for each row execute function app.price_list_validate();
drop trigger if exists touch_updated on public.price_list;
create trigger touch_updated before update on public.price_list
  for each row execute function app.touch_updated();
drop trigger if exists companies_seed_price_lists on public.companies;
create trigger companies_seed_price_lists after insert on public.companies
  for each row execute function app.companies_seed_price_lists();

select app.seed_price_lists(o.id, coalesce(o.default_currency, (
  select c.default_currency from public.companies c where c.org_id = o.id order by c.created_at limit 1
))) from public.organizations o;

alter table public.price_list enable row level security;
alter table public.price_list force row level security;

drop policy if exists price_list_select on public.price_list;
create policy price_list_select on public.price_list for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Price List', 'read'))::uuid[]));
drop policy if exists price_list_insert on public.price_list;
create policy price_list_insert on public.price_list for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Price List', 'create'))::uuid[]));
drop policy if exists price_list_update on public.price_list;
create policy price_list_update on public.price_list for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Price List', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Price List', 'write'))::uuid[]));
drop policy if exists price_list_delete on public.price_list;
create policy price_list_delete on public.price_list for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Price List', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Price List', 'price_list', 'stock', 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Price List', true, false, false, false),
  ('Sales Manager', 'Price List', true, true, true, true),
  ('Purchase Manager', 'Price List', true, true, true, true),
  ('Sales User', 'Price List', true, false, false, false),
  ('Purchase User', 'Price List', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
