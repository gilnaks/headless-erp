-- 0400 stock: Stock Settings, one row per organization.
-- ERPNext source: erpnext/stock/doctype/stock_settings/stock_settings.json.
-- Defaults are the C4 wizard values in docs/modules/04-stock.md §2.8.
-- Quality-inspection columns keep their JSON defaults and stay off the form.

create table if not exists public.stock_settings (
  id                                              uuid primary key default gen_random_uuid(),
  org_id                                          uuid not null unique references public.organizations (id) on delete cascade,
  item_naming_by                                  text not null default 'Item Code'
    check (item_naming_by in ('Item Code', 'Naming Series')),
  stock_uom_id                                    uuid,
  valuation_method                                text not null default 'FIFO'
    check (valuation_method in ('FIFO', 'Moving Average', 'LIFO', 'Standard Cost')),
  allow_negative_stock                            boolean not null default false,
  auto_indent                                     boolean not null default true,
  auto_insert_price_list_rate_if_missing          boolean not null default true,
  update_price_list_based_on                      text not null default 'Rate'
    check (update_price_list_based_on in ('Rate', 'Price List Rate')),
  over_delivery_receipt_allowance                 numeric(21,9) check (over_delivery_receipt_allowance is null or over_delivery_receipt_allowance >= 0),
  mr_qty_allowance                                numeric(21,9) check (mr_qty_allowance is null or mr_qty_allowance >= 0),
  over_picking_allowance                          numeric(21,9) check (over_picking_allowance is null or over_picking_allowance >= 0),
  role_allowed_to_over_deliver_receive            text,
  stock_frozen_upto                               date,
  stock_frozen_upto_days                          int check (stock_frozen_upto_days is null or stock_frozen_upto_days >= 0),
  stock_auth_role                                 text,
  enable_stock_reservation                        boolean not null default false,
  auto_create_serial_and_batch_bundle_for_outward boolean not null default true,
  pick_serial_and_batch_based_on                  text not null default 'FIFO'
    check (pick_serial_and_batch_based_on in ('FIFO', 'LIFO', 'Expiry')),
  use_serial_batch_fields                         boolean not null default true,
  allow_existing_serial_no                        boolean not null default true,
  do_not_use_batchwise_valuation                  boolean not null default false,
  allow_to_edit_stock_uom_qty_for_sales           boolean not null default false,
  allow_to_edit_stock_uom_qty_for_purchase        boolean not null default false,
  allow_to_edit_stock_uom_qty_for_stock_entry     boolean not null default false,
  validate_material_transfer_warehouses           boolean not null default false,
  show_barcode_field                              boolean not null default true,
  clean_description_html                          boolean not null default true,
  set_qty_in_transactions_based_on_serial_no_input boolean not null default true,
  action_if_quality_inspection_is_not_submitted   text not null default 'Stop'
    check (action_if_quality_inspection_is_not_submitted in ('Stop', 'Warn')),
  action_if_quality_inspection_is_rejected        text not null default 'Stop'
    check (action_if_quality_inspection_is_rejected in ('Stop', 'Warn')),
  created_at                                      timestamptz not null default now(),
  created_by                                      uuid default auth.uid(),
  updated_at                                      timestamptz not null default now(),
  updated_by                                      uuid,
  unique (org_id, id),
  foreign key (org_id, stock_uom_id) references public.uom (org_id, id) on delete set null (stock_uom_id),
  foreign key (org_id, role_allowed_to_over_deliver_receive) references public.roles (org_id, name)
    on update cascade on delete set null (role_allowed_to_over_deliver_receive),
  foreign key (org_id, stock_auth_role) references public.roles (org_id, name)
    on update cascade on delete set null (stock_auth_role)
);

create index if not exists stock_settings_uom_idx on public.stock_settings (org_id, stock_uom_id);
create index if not exists stock_settings_over_deliver_role_idx
  on public.stock_settings (org_id, role_allowed_to_over_deliver_receive);
create index if not exists stock_settings_auth_role_idx on public.stock_settings (org_id, stock_auth_role);

drop trigger if exists touch_updated on public.stock_settings;
create trigger touch_updated before update on public.stock_settings
  for each row execute function app.touch_updated();

create or replace function app.organizations_seed_stock_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_uoms(new.id);
  insert into public.stock_settings (org_id, stock_uom_id)
  select new.id, u.id
    from public.uom u
   where u.org_id = new.id and u.uom_name = 'Nos'
  on conflict (org_id) do nothing;
  if not found then
    insert into public.stock_settings (org_id) values (new.id) on conflict (org_id) do nothing;
  end if;
  return null;
end;
$$;

revoke execute on function app.organizations_seed_stock_settings() from public, anon, authenticated;

drop trigger if exists organizations_seed_stock_settings on public.organizations;
create trigger organizations_seed_stock_settings
  after insert on public.organizations
  for each row execute function app.organizations_seed_stock_settings();

------------------------------------------------------------------------------------------------------------------------
-- RLS: read and write follow role_permissions. No insert or delete: the row is seeded.
------------------------------------------------------------------------------------------------------------------------

alter table public.stock_settings enable row level security;
alter table public.stock_settings force row level security;

drop policy if exists stock_settings_select on public.stock_settings;
create policy stock_settings_select on public.stock_settings for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Settings', 'read'))::uuid[]));
drop policy if exists stock_settings_update on public.stock_settings;
create policy stock_settings_update on public.stock_settings for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Stock Settings', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Stock Settings', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry. System Manager reads. Stock Manager writes. Sales User reads.
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_single)
values ('Stock Settings', 'stock_settings', 'stock', true)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_single = excluded.is_single;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Stock Settings', true, false, false, false, false, false, false),
  ('Stock Manager', 'Stock Settings', true, true, true, false, false, false, true),
  ('Sales User', 'Stock Settings', true, false, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();

insert into public.stock_settings (org_id, stock_uom_id)
select o.id, u.id
  from public.organizations o
  left join public.uom u on u.org_id = o.id and u.uom_name = 'Nos'
on conflict (org_id) do nothing;
