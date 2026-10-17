-- 0241 accounts: Tax Rule (docs/modules/01-accounts.md §2.14).
-- ERPNext: erpnext/accounts/doctype/tax_rule/tax_rule.py validate, validate_tax_template,
-- validate_filters, get_tax_template.
-- Party-detail fill and set_taxes wait until a document calls them. A missing customer or
-- supplier group matches only a rule whose group is empty; the tree root is not substituted.

create table if not exists public.tax_rule (
  id                       uuid primary key default gen_random_uuid(),
  org_id                   uuid not null references public.organizations (id) on delete cascade,
  name                     text not null,
  tax_type                 text not null default 'Sales' check (tax_type in ('Sales', 'Purchase')),
  use_for_shopping_cart    boolean not null default true,
  company_id               uuid not null,
  sales_tax_template_id    uuid,
  purchase_tax_template_id uuid,
  customer_id              uuid,
  customer_group_id        uuid,
  supplier_id              uuid,
  supplier_group_id        uuid,
  item_id                  uuid,
  item_group_id            uuid,
  tax_category_id          uuid,
  billing_city             text,
  billing_county           text,
  billing_state            text,
  billing_zipcode          text,
  billing_country          text,
  shipping_city            text,
  shipping_county          text,
  shipping_state           text,
  shipping_zipcode         text,
  shipping_country         text,
  from_date                date,
  to_date                  date,
  priority                 int not null default 1,
  created_at               timestamptz not null default now(),
  created_by               uuid default auth.uid(),
  updated_at               timestamptz not null default now(),
  updated_by               uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, sales_tax_template_id) references public.sales_taxes_and_charges_template (org_id, id)
    on delete set null (sales_tax_template_id),
  foreign key (org_id, purchase_tax_template_id) references public.purchase_taxes_and_charges_template (org_id, id)
    on delete set null (purchase_tax_template_id),
  foreign key (org_id, customer_id) references public.customer (org_id, id)
    on delete set null (customer_id),
  foreign key (org_id, customer_group_id) references public.customer_group (org_id, id)
    on delete set null (customer_group_id),
  foreign key (org_id, supplier_id) references public.supplier (org_id, id)
    on delete set null (supplier_id),
  foreign key (org_id, supplier_group_id) references public.supplier_group (org_id, id)
    on delete set null (supplier_group_id),
  foreign key (org_id, item_id) references public.item (org_id, id)
    on delete set null (item_id),
  foreign key (org_id, item_group_id) references public.item_group (org_id, id)
    on delete set null (item_group_id),
  foreign key (org_id, tax_category_id) references public.tax_category (org_id, id)
    on delete set null (tax_category_id)
);

create index if not exists tax_rule_company_idx on public.tax_rule (org_id, company_id);
create index if not exists tax_rule_sales_template_idx on public.tax_rule (org_id, sales_tax_template_id);
create index if not exists tax_rule_purchase_template_idx on public.tax_rule (org_id, purchase_tax_template_id);
create index if not exists tax_rule_customer_idx on public.tax_rule (org_id, customer_id);
create index if not exists tax_rule_customer_group_idx on public.tax_rule (org_id, customer_group_id);
create index if not exists tax_rule_supplier_idx on public.tax_rule (org_id, supplier_id);
create index if not exists tax_rule_supplier_group_idx on public.tax_rule (org_id, supplier_group_id);
create index if not exists tax_rule_item_idx on public.tax_rule (org_id, item_id);
create index if not exists tax_rule_item_group_idx on public.tax_rule (org_id, item_group_id);
create index if not exists tax_rule_tax_category_idx on public.tax_rule (org_id, tax_category_id);

create or replace function app.tax_rule_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company uuid;
  v_conflict text;
begin
  new.tax_type := coalesce(nullif(btrim(new.tax_type), ''), 'Sales');
  new.priority := coalesce(new.priority, 1);
  new.use_for_shopping_cart := coalesce(new.use_for_shopping_cart, true);
  new.billing_city := nullif(btrim(new.billing_city), '');
  new.billing_county := nullif(btrim(new.billing_county), '');
  new.billing_state := nullif(btrim(new.billing_state), '');
  new.billing_zipcode := nullif(btrim(new.billing_zipcode), '');
  new.billing_country := nullif(btrim(new.billing_country), '');
  new.shipping_city := nullif(btrim(new.shipping_city), '');
  new.shipping_county := nullif(btrim(new.shipping_county), '');
  new.shipping_state := nullif(btrim(new.shipping_state), '');
  new.shipping_zipcode := nullif(btrim(new.shipping_zipcode), '');
  new.shipping_country := nullif(btrim(new.shipping_country), '');

  if new.tax_type = 'Sales' then
    new.purchase_tax_template_id := null;
    new.supplier_id := null;
    new.supplier_group_id := null;
  else
    new.sales_tax_template_id := null;
    new.customer_id := null;
    new.customer_group_id := null;
  end if;
  if new.customer_id is not null then
    new.customer_group_id := null;
  end if;
  if new.supplier_id is not null then
    new.supplier_group_id := null;
  end if;

  if new.tax_type = 'Sales' then
    if new.sales_tax_template_id is null then
      raise exception using errcode = 'P0001', message = 'tax_rule_template: Tax Template is mandatory';
    end if;
    select t.company_id into v_company
      from public.sales_taxes_and_charges_template t
     where t.id = new.sales_tax_template_id and t.org_id = new.org_id;
  else
    if new.purchase_tax_template_id is null then
      raise exception using errcode = 'P0001', message = 'tax_rule_template: Tax Template is mandatory';
    end if;
    select t.company_id into v_company
      from public.purchase_taxes_and_charges_template t
     where t.id = new.purchase_tax_template_id and t.org_id = new.org_id;
  end if;
  if v_company is distinct from new.company_id then
    raise exception using errcode = 'P0001', message = 'tax_rule_company: Tax Template does not belong to the company';
  end if;

  if new.from_date is not null and new.to_date is not null and new.from_date > new.to_date then
    raise exception using errcode = 'P0001', message = 'tax_rule_dates: To Date cannot be before From Date';
  end if;

  select r.name into v_conflict
    from public.tax_rule r
   where r.org_id = new.org_id
     and r.id is distinct from new.id
     and r.tax_type = new.tax_type
     and r.company_id = new.company_id
     and r.priority = new.priority
     and r.customer_id is not distinct from new.customer_id
     and r.customer_group_id is not distinct from new.customer_group_id
     and r.supplier_id is not distinct from new.supplier_id
     and r.supplier_group_id is not distinct from new.supplier_group_id
     and r.item_id is not distinct from new.item_id
     and r.item_group_id is not distinct from new.item_group_id
     and r.tax_category_id is not distinct from new.tax_category_id
     and r.billing_city is not distinct from new.billing_city
     and r.billing_county is not distinct from new.billing_county
     and r.billing_state is not distinct from new.billing_state
     and r.billing_zipcode is not distinct from new.billing_zipcode
     and r.billing_country is not distinct from new.billing_country
     and r.shipping_city is not distinct from new.shipping_city
     and r.shipping_county is not distinct from new.shipping_county
     and r.shipping_state is not distinct from new.shipping_state
     and r.shipping_zipcode is not distinct from new.shipping_zipcode
     and r.shipping_country is not distinct from new.shipping_country
     and daterange(coalesce(r.from_date, '-infinity'::date), coalesce(r.to_date, 'infinity'::date), '[]')
         && daterange(coalesce(new.from_date, '-infinity'::date), coalesce(new.to_date, 'infinity'::date), '[]')
   limit 1;
  if v_conflict is not null then
    raise exception using errcode = 'P0001',
      message = format('tax_rule_conflict: Tax Rule Conflicts with %s', v_conflict);
  end if;

  if tg_op = 'INSERT' then
    if nullif(btrim(new.name), '') is null then
      new.name := app.next_name(new.org_id, new.company_id, 'ACC-TAX-RULE-.YYYY.-.#####', current_date);
    end if;
  else
    new.name := old.name;
  end if;
  return new;
end;
$$;

create or replace function app.get_tax_template(p_date date, p_args jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_company uuid;
  v_type text;
  v_rule public.tax_rule;
  v_template uuid;
  v_disabled boolean;
begin
  if p_args is null or nullif(p_args ->> 'company_id', '') is null then
    return null;
  end if;
  v_company := (p_args ->> 'company_id')::uuid;
  select c.org_id into v_org
    from public.companies c
   where c.id = v_company
     and c.org_id = any ((select app.user_org_ids())::uuid[]);
  if v_org is null then
    return null;
  end if;
  v_type := coalesce(nullif(p_args ->> 'tax_type', ''), 'Sales');

  select r.* into v_rule
    from public.tax_rule r
   where r.org_id = v_org
     and r.company_id = v_company
     and r.tax_type = v_type
     and (
       (p_date is null and r.from_date is null and r.to_date is null)
       or (
         p_date is not null
         and (r.from_date is null or r.from_date <= p_date)
         and (r.to_date is null or r.to_date >= p_date)
       )
     )
     and (
       r.customer_id is null
       or r.customer_id = nullif(p_args ->> 'customer_id', '')::uuid
     )
     and (
       r.supplier_id is null
       or r.supplier_id = nullif(p_args ->> 'supplier_id', '')::uuid
     )
     and (
       r.item_id is null
       or r.item_id = nullif(p_args ->> 'item_id', '')::uuid
     )
     and (
       r.item_group_id is null
       or r.item_group_id = nullif(p_args ->> 'item_group_id', '')::uuid
     )
     and (
       r.tax_category_id is null
       or r.tax_category_id = nullif(p_args ->> 'tax_category_id', '')::uuid
     )
     and (
       r.customer_group_id is null
       or exists (
         select 1
           from public.customer_group rule_g
           join public.customer_group arg_g
             on arg_g.org_id = r.org_id
            and arg_g.id = nullif(p_args ->> 'customer_group_id', '')::uuid
          where rule_g.org_id = r.org_id
            and rule_g.id = r.customer_group_id
            and arg_g.path operator(extensions.<@) rule_g.path
       )
     )
     and (
       r.supplier_group_id is null
       or exists (
         select 1
           from public.supplier_group rule_g
           join public.supplier_group arg_g
             on arg_g.org_id = r.org_id
            and arg_g.id = nullif(p_args ->> 'supplier_group_id', '')::uuid
          where rule_g.org_id = r.org_id
            and rule_g.id = r.supplier_group_id
            and arg_g.path operator(extensions.<@) rule_g.path
       )
     )
     and (nullif(btrim(r.billing_city), '') is null or btrim(r.billing_city) = nullif(btrim(p_args ->> 'billing_city'), ''))
     and (nullif(btrim(r.billing_county), '') is null or btrim(r.billing_county) = nullif(btrim(p_args ->> 'billing_county'), ''))
     and (nullif(btrim(r.billing_state), '') is null or btrim(r.billing_state) = nullif(btrim(p_args ->> 'billing_state'), ''))
     and (nullif(btrim(r.billing_zipcode), '') is null or btrim(r.billing_zipcode) = nullif(btrim(p_args ->> 'billing_zipcode'), ''))
     and (nullif(btrim(r.billing_country), '') is null or btrim(r.billing_country) = nullif(btrim(p_args ->> 'billing_country'), ''))
     and (nullif(btrim(r.shipping_city), '') is null or btrim(r.shipping_city) = nullif(btrim(p_args ->> 'shipping_city'), ''))
     and (nullif(btrim(r.shipping_county), '') is null or btrim(r.shipping_county) = nullif(btrim(p_args ->> 'shipping_county'), ''))
     and (nullif(btrim(r.shipping_state), '') is null or btrim(r.shipping_state) = nullif(btrim(p_args ->> 'shipping_state'), ''))
     and (nullif(btrim(r.shipping_zipcode), '') is null or btrim(r.shipping_zipcode) = nullif(btrim(p_args ->> 'shipping_zipcode'), ''))
     and (nullif(btrim(r.shipping_country), '') is null or btrim(r.shipping_country) = nullif(btrim(p_args ->> 'shipping_country'), ''))
   order by (
       (r.customer_id is not null)::int
       + (r.customer_group_id is not null)::int
       + (r.supplier_id is not null)::int
       + (r.supplier_group_id is not null)::int
       + (r.item_id is not null)::int
       + (r.item_group_id is not null)::int
       + (r.tax_category_id is not null)::int
       + (nullif(btrim(r.billing_city), '') is not null)::int
       + (nullif(btrim(r.billing_county), '') is not null)::int
       + (nullif(btrim(r.billing_state), '') is not null)::int
       + (nullif(btrim(r.billing_zipcode), '') is not null)::int
       + (nullif(btrim(r.billing_country), '') is not null)::int
       + (nullif(btrim(r.shipping_city), '') is not null)::int
       + (nullif(btrim(r.shipping_county), '') is not null)::int
       + (nullif(btrim(r.shipping_state), '') is not null)::int
       + (nullif(btrim(r.shipping_zipcode), '') is not null)::int
       + (nullif(btrim(r.shipping_country), '') is not null)::int
     ) desc,
     r.priority desc
   limit 1;
  if v_rule.id is null then
    return null;
  end if;

  v_template := case
    when v_rule.tax_type = 'Purchase' then v_rule.purchase_tax_template_id
    else v_rule.sales_tax_template_id
  end;
  if v_template is null then
    return null;
  end if;
  if v_rule.tax_type = 'Purchase' then
    select t.disabled into v_disabled
      from public.purchase_taxes_and_charges_template t
     where t.id = v_template;
  else
    select t.disabled into v_disabled
      from public.sales_taxes_and_charges_template t
     where t.id = v_template;
  end if;
  if coalesce(v_disabled, true) then
    return null;
  end if;
  return v_template;
end;
$$;

create or replace function public.get_tax_template(p_date date, p_args jsonb)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select app.get_tax_template(p_date, p_args);
$$;

revoke all on function app.tax_rule_validate() from public, anon, authenticated;
revoke all on function app.get_tax_template(date, jsonb) from public, anon, authenticated;
revoke all on function public.get_tax_template(date, jsonb) from public, anon, authenticated;
grant execute on function app.get_tax_template(date, jsonb) to authenticated;
grant execute on function public.get_tax_template(date, jsonb) to authenticated;

drop trigger if exists tax_rule_validate on public.tax_rule;
create trigger tax_rule_validate
  before insert or update on public.tax_rule
  for each row execute function app.tax_rule_validate();

drop trigger if exists touch_updated on public.tax_rule;
create trigger touch_updated before update on public.tax_rule
  for each row execute function app.touch_updated();

alter table public.tax_rule enable row level security;
alter table public.tax_rule force row level security;

drop policy if exists tax_rule_select on public.tax_rule;
create policy tax_rule_select on public.tax_rule for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Tax Rule', 'read'))::uuid[]));
drop policy if exists tax_rule_insert on public.tax_rule;
create policy tax_rule_insert on public.tax_rule for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Tax Rule', 'create'))::uuid[]));
drop policy if exists tax_rule_update on public.tax_rule;
create policy tax_rule_update on public.tax_rule for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Tax Rule', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Tax Rule', 'write'))::uuid[]));
drop policy if exists tax_rule_delete on public.tax_rule;
create policy tax_rule_delete on public.tax_rule for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Tax Rule', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Tax Rule', 'tax_rule', 'accounts', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Tax Rule', true, false, false, false),
  ('Accounts Manager', 'Tax Rule', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
