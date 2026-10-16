-- 0217 stock: Warehouse (docs/modules/04-stock.md §2.5, 00-setup B5).
-- ERPNext: erpnext/stock/doctype/warehouse/warehouse.py, erpnext/setup/doctype/company/company.py create_default_warehouses.

create table if not exists public.warehouse (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null references public.organizations (id) on delete cascade,
  name                  text not null,
  warehouse_name        text not null check (length(trim(warehouse_name)) > 0),
  is_group              boolean not null default false,
  company_id            uuid not null,
  parent_id             uuid,
  account_id            uuid,
  warehouse_type_id     uuid,
  is_rejected_warehouse boolean not null default false,
  disabled              boolean not null default false,
  email_id              text,
  phone_no              text,
  mobile_no             text,
  address_line_1        text,
  address_line_2        text,
  city                  text,
  state                 text,
  pin                   text,
  path                  extensions.ltree not null,
  created_at            timestamptz not null default now(),
  created_by            uuid default auth.uid(),
  updated_at            timestamptz not null default now(),
  updated_by            uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, parent_id) references public.warehouse (org_id, id),
  foreign key (org_id, account_id) references public.account (org_id, id),
  foreign key (org_id, warehouse_type_id) references public.warehouse_type (org_id, id)
);

create unique index if not exists warehouse_root_uniq on public.warehouse (org_id, company_id) where parent_id is null;
create index if not exists warehouse_parent_idx on public.warehouse (org_id, parent_id);
create index if not exists warehouse_company_idx on public.warehouse (org_id, company_id);
create index if not exists warehouse_account_idx on public.warehouse (org_id, account_id);
create index if not exists warehouse_warehouse_type_idx on public.warehouse (org_id, warehouse_type_id);
create index if not exists warehouse_path_idx on public.warehouse using gist (path);

create or replace function app.warehouse_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_abbr text;
  v_parent_company uuid;
  v_account_company uuid;
  v_account_type text;
  v_account_group boolean;
begin
  new.warehouse_name := trim(new.warehouse_name);
  if new.parent_id is null and new.warehouse_name <> 'All Warehouses' then
    select id into new.parent_id from public.warehouse
     where org_id = new.org_id and company_id = new.company_id and parent_id is null;
  end if;
  if new.parent_id is not null then
    select company_id into v_parent_company from public.warehouse where id = new.parent_id and org_id = new.org_id;
    if v_parent_company is distinct from new.company_id then
      raise exception using errcode = 'P0001', message = 'warehouse_parent: Parent warehouse must belong to the same company';
    end if;
  end if;
  if new.account_id is not null then
    select company_id, account_type, is_group into v_account_company, v_account_type, v_account_group
      from public.account where id = new.account_id and org_id = new.org_id;
    if v_account_company is distinct from new.company_id or v_account_type is distinct from 'Stock' or v_account_group then
      raise exception using errcode = 'P0001', message = 'warehouse_account: Warehouse account must be a Stock ledger of the same company';
    end if;
  end if;
  select abbr into v_abbr from public.companies where id = new.company_id;
  new.name := new.warehouse_name || ' - ' || v_abbr;
  return new;
end;
$$;

create or replace function app.seed_warehouses(p_company uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_root uuid;
  v_stores uuid;
  v_transit uuid;
begin
  if exists (select 1 from public.warehouse where company_id = p_company) then
    return;
  end if;
  select org_id into v_org from public.companies where id = p_company;
  select id into v_transit from public.warehouse_type where org_id = v_org and name = 'Transit';
  insert into public.warehouse (org_id, warehouse_name, company_id, is_group)
  values (v_org, 'All Warehouses', p_company, true)
  returning id into v_root;
  insert into public.warehouse (org_id, warehouse_name, company_id, is_group, parent_id)
  values (v_org, 'Stores', p_company, false, v_root)
  returning id into v_stores;
  insert into public.warehouse (org_id, warehouse_name, company_id, is_group, parent_id)
  values
    (v_org, 'Work In Progress', p_company, false, v_root),
    (v_org, 'Finished Goods', p_company, false, v_root),
    (v_org, 'Goods In Transit', p_company, false, v_root);
  update public.warehouse set warehouse_type_id = v_transit
   where company_id = p_company and warehouse_name = 'Goods In Transit';
  update public.companies set default_warehouse_id = v_stores where id = p_company;
end;
$$;

create or replace function app.companies_seed_warehouses()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_warehouses(new.id);
  return null;
end;
$$;

revoke execute on function
  app.warehouse_validate(), app.seed_warehouses(uuid), app.companies_seed_warehouses()
from public, anon, authenticated;

drop trigger if exists warehouse_validate on public.warehouse;
create trigger warehouse_validate before insert or update on public.warehouse
  for each row execute function app.warehouse_validate();
drop trigger if exists tree_path on public.warehouse;
create trigger tree_path before insert or update on public.warehouse
  for each row execute function app.tree_maintain_path('Warehouse');
drop trigger if exists tree_path_descendants on public.warehouse;
create trigger tree_path_descendants after update on public.warehouse
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.warehouse;
create trigger touch_updated before update on public.warehouse
  for each row execute function app.touch_updated();
drop trigger if exists companies_seed_warehouses on public.companies;
create trigger companies_seed_warehouses after insert on public.companies
  for each row execute function app.companies_seed_warehouses();

select app.seed_warehouses(c.id) from public.companies c;

create index if not exists companies_sales_return_warehouse_idx on public.companies (org_id, default_warehouse_for_sales_return_id);
create index if not exists companies_default_warehouse_idx on public.companies (org_id, default_warehouse_id);
create index if not exists companies_in_transit_warehouse_idx on public.companies (org_id, default_in_transit_warehouse_id);
create index if not exists companies_wip_warehouse_idx on public.companies (org_id, default_wip_warehouse_id);
create index if not exists companies_fg_warehouse_idx on public.companies (org_id, default_fg_warehouse_id);
create index if not exists companies_scrap_warehouse_idx on public.companies (org_id, default_scrap_warehouse_id);
create index if not exists companies_sample_retention_warehouse_idx on public.companies (org_id, sample_retention_warehouse_id);

alter table public.companies drop constraint if exists companies_sales_return_warehouse_fk;
alter table public.companies drop constraint if exists companies_default_warehouse_fk;
alter table public.companies drop constraint if exists companies_in_transit_warehouse_fk;
alter table public.companies drop constraint if exists companies_wip_warehouse_fk;
alter table public.companies drop constraint if exists companies_fg_warehouse_fk;
alter table public.companies drop constraint if exists companies_scrap_warehouse_fk;
alter table public.companies drop constraint if exists companies_sample_retention_warehouse_fk;
alter table public.companies
  add constraint companies_sales_return_warehouse_fk
    foreign key (org_id, default_warehouse_for_sales_return_id) references public.warehouse (org_id, id),
  add constraint companies_default_warehouse_fk
    foreign key (org_id, default_warehouse_id) references public.warehouse (org_id, id),
  add constraint companies_in_transit_warehouse_fk
    foreign key (org_id, default_in_transit_warehouse_id) references public.warehouse (org_id, id),
  add constraint companies_wip_warehouse_fk
    foreign key (org_id, default_wip_warehouse_id) references public.warehouse (org_id, id),
  add constraint companies_fg_warehouse_fk
    foreign key (org_id, default_fg_warehouse_id) references public.warehouse (org_id, id),
  add constraint companies_scrap_warehouse_fk
    foreign key (org_id, default_scrap_warehouse_id) references public.warehouse (org_id, id),
  add constraint companies_sample_retention_warehouse_fk
    foreign key (org_id, sample_retention_warehouse_id) references public.warehouse (org_id, id);

alter table public.warehouse enable row level security;
alter table public.warehouse force row level security;

drop policy if exists warehouse_select on public.warehouse;
create policy warehouse_select on public.warehouse for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Warehouse', 'read'))::uuid[]));
drop policy if exists warehouse_insert on public.warehouse;
create policy warehouse_insert on public.warehouse for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Warehouse', 'create'))::uuid[]));
drop policy if exists warehouse_update on public.warehouse;
create policy warehouse_update on public.warehouse for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Warehouse', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Warehouse', 'write'))::uuid[]));
drop policy if exists warehouse_delete on public.warehouse;
create policy warehouse_delete on public.warehouse for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Warehouse', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Warehouse', 'warehouse', 'stock', true, 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, is_tree = true, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Warehouse', true, false, false, false),
  ('Item Manager', 'Warehouse', true, true, true, true),
  ('Stock User', 'Warehouse', true, false, false, false),
  ('Stock Manager', 'Warehouse', true, false, false, false),
  ('Sales User', 'Warehouse', true, false, false, false),
  ('Purchase User', 'Warehouse', true, false, false, false),
  ('Accounts User', 'Warehouse', true, false, false, false),
  ('Manufacturing User', 'Warehouse', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
