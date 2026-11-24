-- 0507 selling: Selling Settings, one row per organization.
-- ERPNext: erpnext/selling/doctype/selling_settings/selling_settings.json.
-- Defaults are the A20 wizard values in docs/modules/02-selling.md §2.14.
-- Proforma links and the legacy reactivity flag are omitted.
-- Quotation, sales order, and delivery note submit do not read this row yet.

create table if not exists public.selling_settings (
  id                                              uuid primary key default gen_random_uuid(),
  org_id                                          uuid not null unique references public.organizations (id) on delete cascade,
  cust_master_name                                text not null default 'Customer Name'
    check (cust_master_name in ('Customer Name', 'Naming Series', 'Auto Name')),
  customer_group_id                               uuid,
  territory_id                                    uuid,
  selling_price_list_id                           uuid,
  so_required                                     text not null default 'No' check (so_required in ('No', 'Yes')),
  dn_required                                     text not null default 'No' check (dn_required in ('No', 'Yes')),
  skip_delivery_note_for_service_items            boolean not null default false,
  sales_update_frequency                          text not null default 'Each Transaction'
    check (sales_update_frequency in ('Monthly', 'Each Transaction', 'Daily')),
  maintain_same_sales_rate                        boolean not null default false,
  maintain_same_rate_action                       text not null default 'Stop'
    check (maintain_same_rate_action in ('Stop', 'Warn')),
  role_to_override_stop_action                    text,
  editable_price_list_rate                        boolean not null default false,
  allow_multiple_items                            boolean not null default true,
  allow_against_multiple_purchase_orders          boolean not null default false,
  validate_selling_price                          boolean not null default false,
  hide_tax_id                                     boolean not null default false,
  editable_bundle_item_rates                      boolean not null default false,
  enable_discount_accounting                      boolean not null default false,
  allow_sales_order_creation_for_expired_quotation boolean not null default false,
  allow_zero_qty_in_quotation                     boolean not null default false,
  allow_zero_qty_in_sales_order                   boolean not null default false,
  allow_negative_rates_for_items                  boolean not null default false,
  fallback_to_default_price_list                  boolean not null default false,
  set_zero_rate_for_expired_batch                 boolean not null default false,
  dont_reserve_sales_order_qty_on_sales_return    boolean not null default false,
  blanket_order_allowance                         numeric(21,9)
    check (blanket_order_allowance is null or blanket_order_allowance >= 0),
  enable_tracking_sales_commissions               boolean not null default false,
  enable_cutoff_date_on_bulk_delivery_note_creation boolean not null default false,
  allow_delivery_of_overproduced_qty              boolean not null default false,
  enable_proforma_invoice                         boolean not null default false,
  enable_utm                                      boolean not null default false,
  deliver_secondary_items                         boolean not null default false,
  created_at                                      timestamptz not null default now(),
  created_by                                      uuid default auth.uid(),
  updated_at                                      timestamptz not null default now(),
  updated_by                                      uuid,
  unique (org_id, id),
  foreign key (org_id, customer_group_id) references public.customer_group (org_id, id)
    on delete set null (customer_group_id),
  foreign key (org_id, territory_id) references public.territory (org_id, id)
    on delete set null (territory_id),
  foreign key (org_id, selling_price_list_id) references public.price_list (org_id, id)
    on delete set null (selling_price_list_id),
  foreign key (org_id, role_to_override_stop_action) references public.roles (org_id, name)
    on update cascade on delete set null (role_to_override_stop_action)
);

create index if not exists selling_settings_customer_group_idx
  on public.selling_settings (org_id, customer_group_id);
create index if not exists selling_settings_territory_idx
  on public.selling_settings (org_id, territory_id);
create index if not exists selling_settings_price_list_idx
  on public.selling_settings (org_id, selling_price_list_id);
create index if not exists selling_settings_override_role_idx
  on public.selling_settings (org_id, role_to_override_stop_action);

drop trigger if exists touch_updated on public.selling_settings;
create trigger touch_updated before update on public.selling_settings
  for each row execute function app.touch_updated();

create or replace function app.selling_settings_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.selling_price_list_id is not null and not exists (
    select 1 from public.price_list p
     where p.id = new.selling_price_list_id
       and p.org_id = new.org_id
       and p.selling
  ) then
    raise exception using errcode = 'P0001',
      message = 'selling_price_list: Default Price List must be a selling price list';
  end if;
  return new;
end;
$$;

revoke all on function app.selling_settings_validate() from public, anon, authenticated;

drop trigger if exists selling_settings_validate on public.selling_settings;
create trigger selling_settings_validate
  before insert or update on public.selling_settings
  for each row execute function app.selling_settings_validate();

create or replace function app.organizations_seed_selling_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.selling_settings (org_id) values (new.id) on conflict (org_id) do nothing;
  return null;
end;
$$;

revoke all on function app.organizations_seed_selling_settings() from public, anon, authenticated;

drop trigger if exists organizations_seed_selling_settings on public.organizations;
create trigger organizations_seed_selling_settings
  after insert on public.organizations
  for each row execute function app.organizations_seed_selling_settings();

------------------------------------------------------------------------------------------------------------------------
-- RLS: read and write follow role_permissions. No insert or delete: the row is seeded.
------------------------------------------------------------------------------------------------------------------------

alter table public.selling_settings enable row level security;
alter table public.selling_settings force row level security;

drop policy if exists selling_settings_select on public.selling_settings;
create policy selling_settings_select on public.selling_settings for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Selling Settings', 'read'))::uuid[]));
drop policy if exists selling_settings_update on public.selling_settings;
create policy selling_settings_update on public.selling_settings for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Selling Settings', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Selling Settings', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry. System Manager and Sales Manager read and write.
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_single)
values ('Selling Settings', 'selling_settings', 'selling', true)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_single = excluded.is_single;

insert into public.role_permission_template (
  role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete
) values
  ('System Manager', 'Selling Settings', true, true, false, false, false, false, false),
  ('Sales Manager', 'Selling Settings', true, true, false, false, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write, can_create = excluded.can_create,
      can_submit = excluded.can_submit, can_cancel = excluded.can_cancel, can_amend = excluded.can_amend,
      can_delete = excluded.can_delete;

select app.sync_role_permissions();

insert into public.selling_settings (org_id)
select o.id from public.organizations o
on conflict (org_id) do nothing;
