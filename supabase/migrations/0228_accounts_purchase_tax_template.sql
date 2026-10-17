-- 0228 accounts: Purchase Taxes and Charges Template (docs/modules/01-accounts.md §2.11).
-- ERPNext: erpnext/accounts/doctype/purchase_taxes_and_charges_template and purchase_taxes_and_charges,
-- plus erpnext/accounts/services/taxes.py. Names come from app.tax_template_name (0227).
-- Purchase Manager can read. Only Accounts Manager can create or delete.

create table if not exists public.purchase_taxes_and_charges_template (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  name             text not null,
  title            text not null check (length(trim(title)) > 0),
  is_default       boolean not null default false,
  disabled         boolean not null default false,
  company_id       uuid not null,
  tax_category_id  uuid,
  created_at       timestamptz not null default now(),
  created_by       uuid default auth.uid(),
  updated_at       timestamptz not null default now(),
  updated_by       uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, tax_category_id) references public.tax_category (org_id, id)
    on delete set null (tax_category_id)
);

create index if not exists purchase_tax_template_company_idx
  on public.purchase_taxes_and_charges_template (org_id, company_id);
create index if not exists purchase_tax_template_category_idx
  on public.purchase_taxes_and_charges_template (org_id, tax_category_id);

create table if not exists public.purchase_taxes_and_charges (
  id                                  uuid primary key default gen_random_uuid(),
  org_id                              uuid not null,
  parent_id                           uuid not null,
  idx                                 integer not null check (idx > 0),
  category                            text not null default 'Total' check (category in ('Valuation and Total', 'Valuation', 'Total')),
  add_deduct_tax                      text not null default 'Add' check (add_deduct_tax in ('Add', 'Deduct')),
  charge_type                         text not null default 'On Net Total' check (charge_type in (
                                        'Actual', 'On Net Total', 'On Previous Row Amount', 'On Previous Row Total', 'On Item Quantity'
                                      )),
  row_id                              text,
  included_in_print_rate              boolean not null default false,
  included_in_paid_amount             boolean not null default false,
  allocate_full_amount_to_stock_items boolean not null default true,
  account_head_id                     uuid not null,
  description                         text not null check (length(trim(description)) > 0),
  rate                                numeric,
  cost_center_id                      uuid,
  account_currency                    text,
  created_at                          timestamptz not null default now(),
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.purchase_taxes_and_charges_template (org_id, id) on delete cascade,
  foreign key (org_id, account_head_id) references public.account (org_id, id) on delete cascade,
  foreign key (org_id, cost_center_id) references public.cost_center (org_id, id)
    on delete set null (cost_center_id)
);

create index if not exists purchase_taxes_parent_idx on public.purchase_taxes_and_charges (org_id, parent_id);
create index if not exists purchase_taxes_account_idx on public.purchase_taxes_and_charges (org_id, account_head_id);
create index if not exists purchase_taxes_cost_center_idx on public.purchase_taxes_and_charges (org_id, cost_center_id);

create or replace function app.purchase_taxes_and_charges_template_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.title := trim(new.title);
  new.name := app.tax_template_name(new.title, new.company_id);
  if new.disabled and new.is_default then
    raise exception using errcode = 'P0001',
      message = 'tax_template_default: Disabled template must not be default template';
  end if;
  if new.tax_category_id is not null and not new.disabled and exists (
    select 1 from public.purchase_taxes_and_charges_template t
    where t.org_id = new.org_id and t.company_id = new.company_id
      and t.tax_category_id = new.tax_category_id and not t.disabled and t.id <> new.id
  ) then
    raise exception using errcode = 'P0001',
      message = 'tax_template_category: Only one template is allowed with each tax category';
  end if;
  if new.is_default then
    update public.purchase_taxes_and_charges_template
       set is_default = false, updated_at = now()
     where org_id = new.org_id and company_id = new.company_id and is_default and id <> new.id;
  end if;
  return new;
end;
$$;

create or replace function app.purchase_taxes_and_charges_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_company uuid;
  v_account_company uuid;
  v_is_group boolean;
  v_cc_company uuid;
begin
  select company_id into v_company from public.purchase_taxes_and_charges_template where id = new.parent_id;
  select company_id, is_group into v_account_company, v_is_group
    from public.account where id = new.account_head_id and org_id = new.org_id;
  if v_account_company is distinct from v_company or v_is_group is distinct from false then
    raise exception using errcode = 'P0001', message = 'tax_account_head: Account must be a ledger of the company';
  end if;
  if new.cost_center_id is not null then
    select company_id into v_cc_company from public.cost_center where id = new.cost_center_id and org_id = new.org_id;
    if v_cc_company is distinct from v_company then
      raise exception using errcode = 'P0001',
        message = format('tax_cost_center: Row %s: Cost Center does not belong to Company', new.idx);
    end if;
  end if;
  if new.charge_type = 'Actual' then
    new.rate := null;
    if new.included_in_print_rate or new.included_in_paid_amount then
      raise exception using errcode = 'P0001',
        message = format('tax_inclusive_actual: Charge of type Actual in row %s cannot be included in Item Rate or Paid Amount', new.idx);
    end if;
  elsif new.charge_type in ('On Previous Row Amount', 'On Previous Row Total') then
    if new.idx = 1 then
      raise exception using errcode = 'P0001',
        message = 'tax_row_id: Cannot select charge type as On Previous Row Amount or On Previous Row Total for first row';
    elsif new.row_id is null or new.row_id !~ '^[0-9]+$' or new.row_id::int not between 1 and new.idx - 1 then
      raise exception using errcode = 'P0001',
        message = format('tax_row_id: Please specify a valid Row ID for row %s', new.idx);
    end if;
  end if;
  return new;
end;
$$;

revoke all on function app.purchase_taxes_and_charges_template_validate() from public, anon, authenticated;
revoke all on function app.purchase_taxes_and_charges_validate() from public, anon, authenticated;

drop trigger if exists purchase_taxes_and_charges_template_validate on public.purchase_taxes_and_charges_template;
create trigger purchase_taxes_and_charges_template_validate
  before insert or update on public.purchase_taxes_and_charges_template
  for each row execute function app.purchase_taxes_and_charges_template_validate();

drop trigger if exists purchase_taxes_and_charges_validate on public.purchase_taxes_and_charges;
create trigger purchase_taxes_and_charges_validate
  before insert or update on public.purchase_taxes_and_charges
  for each row execute function app.purchase_taxes_and_charges_validate();

alter table public.purchase_taxes_and_charges_template enable row level security;
alter table public.purchase_taxes_and_charges_template force row level security;
alter table public.purchase_taxes_and_charges enable row level security;
alter table public.purchase_taxes_and_charges force row level security;

drop policy if exists purchase_tax_template_select on public.purchase_taxes_and_charges_template;
create policy purchase_tax_template_select on public.purchase_taxes_and_charges_template
  for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'read'))::uuid[]));
drop policy if exists purchase_tax_template_insert on public.purchase_taxes_and_charges_template;
create policy purchase_tax_template_insert on public.purchase_taxes_and_charges_template
  for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'create'))::uuid[]));
drop policy if exists purchase_tax_template_update on public.purchase_taxes_and_charges_template;
create policy purchase_tax_template_update on public.purchase_taxes_and_charges_template
  for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'write'))::uuid[]));
drop policy if exists purchase_tax_template_delete on public.purchase_taxes_and_charges_template;
create policy purchase_tax_template_delete on public.purchase_taxes_and_charges_template
  for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'delete'))::uuid[]));

drop policy if exists purchase_taxes_select on public.purchase_taxes_and_charges;
create policy purchase_taxes_select on public.purchase_taxes_and_charges
  for select to authenticated
  using (exists (select 1 from public.purchase_taxes_and_charges_template p where p.id = parent_id));
drop policy if exists purchase_taxes_insert on public.purchase_taxes_and_charges;
create policy purchase_taxes_insert on public.purchase_taxes_and_charges
  for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'create'))::uuid[]));
drop policy if exists purchase_taxes_update on public.purchase_taxes_and_charges;
create policy purchase_taxes_update on public.purchase_taxes_and_charges
  for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'write'))::uuid[]));
drop policy if exists purchase_taxes_delete on public.purchase_taxes_and_charges;
create policy purchase_taxes_delete on public.purchase_taxes_and_charges
  for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Purchase Taxes and Charges Template', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Purchase Taxes and Charges Template', 'purchase_taxes_and_charges_template', 'accounts', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Purchase Taxes and Charges', 'purchase_taxes_and_charges', 'accounts', true, 'Purchase Taxes and Charges Template', 'taxes')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true, parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Purchase Taxes and Charges Template', true, false, false, false),
  ('Accounts Manager', 'Purchase Taxes and Charges Template', true, true, true, true),
  ('Purchase Manager', 'Purchase Taxes and Charges Template', true, false, false, false),
  ('Purchase User', 'Purchase Taxes and Charges Template', true, false, false, false),
  ('Accounts User', 'Purchase Taxes and Charges Template', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
