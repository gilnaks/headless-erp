-- 0240 stock: Item Price (docs/modules/04-stock.md §2.6).
-- ERPNext: erpnext/stock/doctype/item_price/item_price.py validate, validate_item,
-- update_price_list_details, clear_party_not_applicable, update_item_details, check_duplicates.
-- Batch and get_item_details wait. A template item cannot be saved, so that check is skipped.

create table if not exists public.item_price (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations (id) on delete cascade,
  name            text not null,
  item_id         uuid not null,
  item_name       text not null,
  uom_id          uuid not null,
  packing_unit    numeric(21,9) not null default 0,
  price_list_id   uuid not null,
  customer_id     uuid,
  supplier_id     uuid,
  buying          boolean not null default false,
  selling         boolean not null default false,
  currency        text not null references public.currency (code),
  price_list_rate numeric(21,9) not null,
  valid_from      date not null default current_date,
  valid_upto      date,
  lead_time_days  int,
  created_at      timestamptz not null default now(),
  created_by      uuid default auth.uid(),
  updated_at      timestamptz not null default now(),
  updated_by      uuid,
  unique (org_id, id),
  unique (org_id, name),
  unique nulls not distinct (
    org_id, item_id, price_list_id, uom_id, customer_id, supplier_id, valid_from, packing_unit
  ),
  foreign key (org_id, item_id) references public.item (org_id, id) on delete cascade,
  foreign key (org_id, uom_id) references public.uom (org_id, id),
  foreign key (org_id, price_list_id) references public.price_list (org_id, id),
  foreign key (org_id, customer_id) references public.customer (org_id, id),
  foreign key (org_id, supplier_id) references public.supplier (org_id, id)
);

create index if not exists item_price_uom_idx on public.item_price (org_id, uom_id);
create index if not exists item_price_list_idx on public.item_price (org_id, price_list_id);
create index if not exists item_price_customer_idx on public.item_price (org_id, customer_id);
create index if not exists item_price_supplier_idx on public.item_price (org_id, supplier_id);

create or replace function app.item_price_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enabled boolean;
  v_stock uuid;
begin
  if tg_op = 'INSERT' then
    new.name := gen_random_uuid()::text;
  else
    new.name := old.name;
  end if;

  select enabled, buying, selling, currency
    into v_enabled, new.buying, new.selling, new.currency
    from public.price_list
   where id = new.price_list_id;
  if v_enabled is not true then
    raise exception using errcode = 'P0001',
      message = 'item_price_list: The price list does not exist or is disabled';
  end if;
  if new.selling and not new.buying then
    new.supplier_id := null;
  elsif new.buying and not new.selling then
    new.customer_id := null;
  end if;

  select item_name, stock_uom_id into new.item_name, v_stock
    from public.item
   where id = new.item_id;
  if new.uom_id is null then
    new.uom_id := v_stock;
  end if;
  if new.valid_from is null then
    new.valid_from := current_date;
  end if;
  if new.packing_unit is null then
    new.packing_unit := 0;
  end if;
  if new.valid_upto is not null and new.valid_upto < new.valid_from then
    raise exception using errcode = 'P0001',
      message = 'item_price_dates: Valid Upto cannot be before Valid From';
  end if;
  if not exists (
    select 1 from public.item_uom u
     where u.parent_id = new.item_id and u.uom_id = new.uom_id
  ) then
    raise exception using errcode = 'P0001',
      message = 'item_price_uom: UOM not found in Item';
  end if;
  if exists (
    select 1 from public.item_price p
     where p.org_id = new.org_id
       and p.item_id = new.item_id
       and p.price_list_id = new.price_list_id
       and p.uom_id = new.uom_id
       and p.customer_id is not distinct from new.customer_id
       and p.supplier_id is not distinct from new.supplier_id
       and p.valid_from = new.valid_from
       and p.packing_unit = new.packing_unit
       and p.id is distinct from new.id
  ) then
    raise exception using errcode = 'P0001',
      message = 'item_price_duplicate: Item Price appears multiple times based on Price List, Supplier/Customer, Currency, Item, Batch, UOM, Qty, and Dates.';
  end if;
  return new;
end;
$$;

revoke all on function app.item_price_validate() from public, anon, authenticated;

drop trigger if exists item_price_validate on public.item_price;
create trigger item_price_validate before insert or update on public.item_price
  for each row execute function app.item_price_validate();
drop trigger if exists touch_updated on public.item_price;
create trigger touch_updated before update on public.item_price
  for each row execute function app.touch_updated();

alter table public.item_price enable row level security;
alter table public.item_price force row level security;

drop policy if exists item_price_select on public.item_price;
create policy item_price_select on public.item_price for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Price', 'read'))::uuid[]));
drop policy if exists item_price_insert on public.item_price;
create policy item_price_insert on public.item_price for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item Price', 'create'))::uuid[]));
drop policy if exists item_price_update on public.item_price;
create policy item_price_update on public.item_price for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Price', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item Price', 'write'))::uuid[]));
drop policy if exists item_price_delete on public.item_price;
create policy item_price_delete on public.item_price for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Price', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Item Price', 'item_price', 'stock', 'item_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Item Price', true, false, false, false),
  ('Sales Manager', 'Item Price', true, true, true, true),
  ('Purchase Manager', 'Item Price', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
