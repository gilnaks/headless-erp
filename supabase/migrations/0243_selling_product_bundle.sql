-- 0243 selling: Product Bundle (docs/modules/02-selling.md §2.9).
-- ERPNext: erpnext/selling/doctype/product_bundle/product_bundle.py autoname, validate,
-- on_submit, on_cancel, make_active.
-- Packing-list rebuild and the linked-document delete check wait until those documents exist.

create table if not exists public.product_bundle (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations (id) on delete cascade,
  name          text not null,
  new_item_id   uuid not null,
  description   text,
  is_active     boolean not null default true,
  disabled      boolean not null default false,
  docstatus     smallint not null default 0 check (docstatus in (0, 1, 2)),
  amended_from  uuid,
  created_at    timestamptz not null default now(),
  created_by    uuid default auth.uid(),
  updated_at    timestamptz not null default now(),
  updated_by    uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, new_item_id) references public.item (org_id, id),
  foreign key (org_id, amended_from) references public.product_bundle (org_id, id)
    on delete set null (amended_from)
);

create table if not exists public.product_bundle_item (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  parent_id   uuid not null,
  idx         int not null,
  item_id     uuid not null,
  qty         numeric(21,9) not null,
  uom_id      uuid,
  description text,
  unique (org_id, id),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.product_bundle (org_id, id) on delete cascade,
  foreign key (org_id, item_id) references public.item (org_id, id),
  foreign key (org_id, uom_id) references public.uom (org_id, id)
);

create index if not exists product_bundle_item_idx on public.product_bundle (org_id, new_item_id);
create index if not exists product_bundle_amended_idx on public.product_bundle (org_id, amended_from);
create index if not exists product_bundle_item_parent_idx on public.product_bundle_item (org_id, parent_id);
create index if not exists product_bundle_item_item_idx on public.product_bundle_item (org_id, item_id);
create index if not exists product_bundle_item_uom_idx on public.product_bundle_item (org_id, uom_id);

create or replace function app.product_bundle_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_stock boolean;
  v_asset boolean;
  v_n int;
  v_suffix text;
  v_name text;
  v_room int;
begin
  select i.item_code, i.is_stock_item, i.is_fixed_asset
    into v_code, v_stock, v_asset
    from public.item i
   where i.id = new.new_item_id and i.org_id = new.org_id;
  if coalesce(v_stock, false) then
    raise exception using errcode = 'P0001', message = 'product_bundle_stock: Parent Item must not be a Stock Item';
  end if;
  if coalesce(v_asset, false) then
    raise exception using errcode = 'P0001', message = 'product_bundle_asset: Parent Item must not be a Fixed Asset';
  end if;

  if tg_op = 'UPDATE' then
    new.name := old.name;
    if new.docstatus = 1 and new.is_active and new.is_active is distinct from old.is_active then
      update public.product_bundle
         set is_active = false
       where org_id = new.org_id and new_item_id = new.new_item_id and id <> new.id and docstatus = 1 and is_active;
    end if;
    return new;
  end if;

  select coalesce(max((regexp_match(b.name, '-([0-9]+)$'))[1]::int), 0)
    into v_n
    from public.product_bundle b
   where b.org_id = new.org_id and b.new_item_id = new.new_item_id and b.amended_from is null;
  loop
    v_n := v_n + 1;
    v_suffix := lpad(v_n::text, greatest(3, length(v_n::text)), '0');
    v_room := 140 - (4 + length(v_suffix));
    if length(v_code) > v_room then
      v_name := 'PB-' || left(v_code, greatest(v_room, 1)) || '-' || v_suffix;
    else
      v_name := 'PB-' || v_code || '-' || v_suffix;
    end if;
    exit when not exists (
      select 1 from public.product_bundle b where b.org_id = new.org_id and b.name = v_name
    );
  end loop;
  new.name := v_name;
  return new;
end;
$$;

create or replace function app.product_bundle_item_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_whole boolean;
begin
  if new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001', message = 'product_bundle_qty: Quantity must be greater than zero';
  end if;
  if new.uom_id is null then
    select i.stock_uom_id into new.uom_id
      from public.item i
     where i.id = new.item_id and i.org_id = new.org_id;
  end if;
  select u.must_be_whole_number into v_whole
    from public.uom u
   where u.id = new.uom_id and u.org_id = new.org_id;
  if coalesce(v_whole, false) and new.qty <> trunc(new.qty) then
    raise exception using errcode = 'P0001',
      message = 'product_bundle_uom: Quantity cannot be a fraction for this UOM';
  end if;
  if exists (
    select 1 from public.product_bundle b
     where b.org_id = new.org_id and b.new_item_id = new.item_id
       and b.is_active and b.docstatus = 1 and not b.disabled
  ) then
    raise exception using errcode = 'P0001',
      message = 'product_bundle_child: Child Item should not be a Product Bundle';
  end if;
  return new;
end;
$$;

create or replace function app.on_submit__product_bundle(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_item uuid;
  v_active boolean;
begin
  select org_id, new_item_id, is_active into v_org, v_item, v_active
    from public.product_bundle where id = p_id;
  update public.product_bundle
     set is_active = false
   where org_id = v_org and new_item_id = v_item and id <> p_id and docstatus = 1 and is_active;
  if not coalesce(v_active, false) then
    update public.product_bundle set is_active = true where id = p_id;
  end if;
end;
$$;

create or replace function app.on_cancel__product_bundle(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.product_bundle set is_active = false where id = p_id;
end;
$$;

create or replace function app.organizations_clear_bundles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.product_bundle where org_id = old.id;
  return old;
end;
$$;

revoke all on function app.product_bundle_validate() from public, anon, authenticated;
revoke all on function app.product_bundle_item_validate() from public, anon, authenticated;
revoke all on function app.on_submit__product_bundle(uuid) from public, anon, authenticated;
revoke all on function app.on_cancel__product_bundle(uuid) from public, anon, authenticated;
revoke all on function app.organizations_clear_bundles() from public, anon, authenticated;

drop trigger if exists product_bundle_validate on public.product_bundle;
create trigger product_bundle_validate
  before insert or update on public.product_bundle
  for each row execute function app.product_bundle_validate();

drop trigger if exists product_bundle_item_validate on public.product_bundle_item;
create trigger product_bundle_item_validate
  before insert or update on public.product_bundle_item
  for each row execute function app.product_bundle_item_validate();

drop trigger if exists touch_updated on public.product_bundle;
create trigger touch_updated before update on public.product_bundle
  for each row execute function app.touch_updated();

drop trigger if exists organizations_clear_bundles on public.organizations;
create trigger organizations_clear_bundles before delete on public.organizations
  for each row execute function app.organizations_clear_bundles();

alter table public.product_bundle enable row level security;
alter table public.product_bundle force row level security;
alter table public.product_bundle_item enable row level security;
alter table public.product_bundle_item force row level security;

drop policy if exists product_bundle_select on public.product_bundle;
create policy product_bundle_select on public.product_bundle for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Product Bundle', 'read'))::uuid[]));
drop policy if exists product_bundle_insert on public.product_bundle;
create policy product_bundle_insert on public.product_bundle for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Product Bundle', 'create'))::uuid[]));
drop policy if exists product_bundle_update on public.product_bundle;
create policy product_bundle_update on public.product_bundle for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Product Bundle', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Product Bundle', 'write'))::uuid[]));
drop policy if exists product_bundle_delete on public.product_bundle;
create policy product_bundle_delete on public.product_bundle for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Product Bundle', 'delete'))::uuid[]));

drop policy if exists product_bundle_item_select on public.product_bundle_item;
create policy product_bundle_item_select on public.product_bundle_item for select to authenticated
  using (exists (select 1 from public.product_bundle p where p.id = parent_id));
drop policy if exists product_bundle_item_insert on public.product_bundle_item;
create policy product_bundle_item_insert on public.product_bundle_item for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Product Bundle', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Product Bundle', 'create'))::uuid[]));
drop policy if exists product_bundle_item_update on public.product_bundle_item;
create policy product_bundle_item_update on public.product_bundle_item for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Product Bundle', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Product Bundle', 'write'))::uuid[]));
drop policy if exists product_bundle_item_delete on public.product_bundle_item;
create policy product_bundle_item_delete on public.product_bundle_item for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Product Bundle', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_submittable, title_field, allow_on_submit)
values ('Product Bundle', 'product_bundle', 'selling', true, 'name', '{is_active,disabled}')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_submittable = true,
      title_field = excluded.title_field, allow_on_submit = excluded.allow_on_submit;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Product Bundle Item', 'product_bundle_item', 'selling', true, 'Product Bundle', 'items')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true,
      parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Product Bundle', true, false, false, false, false, false, false),
  ('Stock Manager', 'Product Bundle', true, true, true, true, true, true, true),
  ('Sales User', 'Product Bundle', true, true, true, true, true, true, true),
  ('Stock User', 'Product Bundle', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();
