-- 0230 accounts: Item Tax Template (docs/modules/01-accounts.md §2.12).
-- ERPNext: erpnext/accounts/doctype/item_tax_template and item_tax_template_detail,
-- plus get_item_tax_map in erpnext/stock/get_item_details.py.
-- The name reuses app.tax_template_name. The header trigger runs as the owner because that
-- helper is not granted to API roles. Item and Item Group tax rows stay with stock.

create table if not exists public.item_tax_template (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  name       text not null,
  title      text not null check (length(trim(title)) > 0),
  company_id uuid not null,
  disabled   boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade
);

create index if not exists item_tax_template_company_idx
  on public.item_tax_template (org_id, company_id);

create table if not exists public.item_tax_template_detail (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null,
  parent_id      uuid not null,
  idx            integer not null check (idx > 0),
  tax_type_id    uuid not null,
  tax_rate       numeric,
  not_applicable boolean not null default false,
  created_at     timestamptz not null default now(),
  unique (parent_id, idx) deferrable initially deferred,
  unique (parent_id, tax_type_id),
  foreign key (org_id, parent_id) references public.item_tax_template (org_id, id) on delete cascade,
  foreign key (org_id, tax_type_id) references public.account (org_id, id) on delete cascade
);

create index if not exists item_tax_detail_parent_idx on public.item_tax_template_detail (org_id, parent_id);
create index if not exists item_tax_detail_account_idx on public.item_tax_template_detail (org_id, tax_type_id);

create or replace function app.item_tax_template_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.title := trim(new.title);
  new.name := app.tax_template_name(new.title, new.company_id);
  return new;
end;
$$;

create or replace function app.item_tax_detail_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_company uuid;
  v_account_company uuid;
  v_type text;
  v_name text;
begin
  if new.not_applicable then
    new.tax_rate := 0;
  end if;
  select company_id into v_company from public.item_tax_template where id = new.parent_id;
  select company_id, account_type, name into v_account_company, v_type, v_name
    from public.account where id = new.tax_type_id and org_id = new.org_id;
  if v_account_company is distinct from v_company then
    raise exception using errcode = 'P0001',
      message = format('item_tax_company: Item Tax Row %s: Account must belong to the company', new.idx);
  end if;
  if v_type is null or v_type not in (
    'Tax', 'Chargeable', 'Income Account', 'Expense Account', 'Expenses Included In Valuation'
  ) then
    raise exception using errcode = 'P0001',
      message = format('item_tax_type: Item Tax Row %s must have account of type Tax or Income or Expense or Chargeable', new.idx);
  end if;
  if exists (
    select 1 from public.item_tax_template_detail d
    where d.parent_id = new.parent_id and d.tax_type_id = new.tax_type_id and d.id is distinct from new.id
  ) then
    raise exception using errcode = 'P0001',
      message = format('item_tax_duplicate: %s entered twice in Item Tax', v_name);
  end if;
  return new;
end;
$$;

-- A missing template means this row is being removed with its parent, including an organization delete.
create or replace function app.item_tax_require_rows(p_template uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_template is null or not exists (select 1 from public.item_tax_template where id = p_template) then
    return;
  end if;
  if not exists (select 1 from public.item_tax_template_detail where parent_id = p_template) then
    raise exception using errcode = 'P0001', message = 'item_tax_rows: Tax Rates is required';
  end if;
end;
$$;

create or replace function app.item_tax_template_rows_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.item_tax_require_rows(coalesce(new.id, old.id));
  return null;
end;
$$;

create or replace function app.item_tax_detail_rows_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.item_tax_require_rows(coalesce(new.parent_id, old.parent_id));
  return null;
end;
$$;

-- Document rows not set by a template seed the map. Template rows for this company overlay them.
-- not_applicable is the text N/A so a missing key does not fall back to the document tax rate.
create or replace function app.get_item_tax_map(p_company uuid, p_template uuid, p_taxes jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_map jsonb := '{}'::jsonb;
  r record;
begin
  for r in
    select t->>'account_head' as account_head, nullif(t->>'rate', '')::numeric as rate
      from jsonb_array_elements(coalesce(p_taxes, '[]'::jsonb)) t
     where coalesce((t->>'set_by_item_tax_template')::boolean, false) = false
       and nullif(t->>'account_head', '') is not null
  loop
    v_map := v_map || jsonb_build_object(r.account_head, r.rate);
  end loop;
  if p_template is not null then
    for r in
      select a.name, d.tax_rate, d.not_applicable
        from public.item_tax_template_detail d
        join public.account a on a.id = d.tax_type_id and a.org_id = d.org_id
       where d.parent_id = p_template and a.company_id = p_company
    loop
      if r.not_applicable then
        v_map := v_map || jsonb_build_object(r.name, 'N/A');
      else
        v_map := v_map || jsonb_build_object(r.name, r.tax_rate);
      end if;
    end loop;
  end if;
  return v_map;
end;
$$;

create or replace function public.get_item_tax_map(p_company uuid, p_template uuid, p_taxes jsonb default '[]'::jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.get_item_tax_map(p_company, p_template, p_taxes);
$$;

revoke all on function app.item_tax_template_validate() from public, anon, authenticated;
revoke all on function app.item_tax_detail_validate() from public, anon, authenticated;
revoke all on function app.item_tax_require_rows(uuid) from public, anon, authenticated;
revoke all on function app.item_tax_template_rows_trigger() from public, anon, authenticated;
revoke all on function app.item_tax_detail_rows_trigger() from public, anon, authenticated;
revoke all on function app.get_item_tax_map(uuid, uuid, jsonb) from public, anon;
grant execute on function app.get_item_tax_map(uuid, uuid, jsonb) to authenticated;
revoke all on function public.get_item_tax_map(uuid, uuid, jsonb) from public, anon;
grant execute on function public.get_item_tax_map(uuid, uuid, jsonb) to authenticated;

drop trigger if exists item_tax_template_validate on public.item_tax_template;
create trigger item_tax_template_validate
  before insert or update on public.item_tax_template
  for each row execute function app.item_tax_template_validate();
drop trigger if exists touch_updated on public.item_tax_template;
create trigger touch_updated before update on public.item_tax_template
  for each row execute function app.touch_updated();
drop trigger if exists item_tax_template_rows on public.item_tax_template;
create constraint trigger item_tax_template_rows
  after insert or update on public.item_tax_template
  deferrable initially deferred
  for each row execute function app.item_tax_template_rows_trigger();

drop trigger if exists item_tax_detail_validate on public.item_tax_template_detail;
create trigger item_tax_detail_validate
  before insert or update on public.item_tax_template_detail
  for each row execute function app.item_tax_detail_validate();
drop trigger if exists item_tax_detail_rows on public.item_tax_template_detail;
create constraint trigger item_tax_detail_rows
  after insert or update or delete on public.item_tax_template_detail
  deferrable initially deferred
  for each row execute function app.item_tax_detail_rows_trigger();

alter table public.item_tax_template enable row level security;
alter table public.item_tax_template force row level security;
alter table public.item_tax_template_detail enable row level security;
alter table public.item_tax_template_detail force row level security;

drop policy if exists item_tax_template_select on public.item_tax_template;
create policy item_tax_template_select on public.item_tax_template for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'read'))::uuid[]));
drop policy if exists item_tax_template_insert on public.item_tax_template;
create policy item_tax_template_insert on public.item_tax_template for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'create'))::uuid[]));
drop policy if exists item_tax_template_update on public.item_tax_template;
create policy item_tax_template_update on public.item_tax_template for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'write'))::uuid[]));
drop policy if exists item_tax_template_delete on public.item_tax_template;
create policy item_tax_template_delete on public.item_tax_template for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'delete'))::uuid[]));

drop policy if exists item_tax_detail_select on public.item_tax_template_detail;
create policy item_tax_detail_select on public.item_tax_template_detail for select to authenticated
  using (exists (select 1 from public.item_tax_template p where p.id = parent_id));
drop policy if exists item_tax_detail_insert on public.item_tax_template_detail;
create policy item_tax_detail_insert on public.item_tax_template_detail for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Item Tax Template', 'create'))::uuid[]));
drop policy if exists item_tax_detail_update on public.item_tax_template_detail;
create policy item_tax_detail_update on public.item_tax_template_detail for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'write'))::uuid[]));
drop policy if exists item_tax_detail_delete on public.item_tax_template_detail;
create policy item_tax_detail_delete on public.item_tax_template_detail for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Item Tax Template', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Item Tax Template', 'item_tax_template', 'accounts', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Item Tax Template Detail', 'item_tax_template_detail', 'accounts', true, 'Item Tax Template', 'taxes')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true, parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Item Tax Template', true, true, true, true),
  ('Accounts Manager', 'Item Tax Template', true, true, true, true),
  ('Accounts User', 'Item Tax Template', true, false, false, false),
  ('Sales User', 'Item Tax Template', true, false, false, false),
  ('Sales Manager', 'Item Tax Template', true, false, false, false),
  ('Purchase User', 'Item Tax Template', true, false, false, false),
  ('Purchase Manager', 'Item Tax Template', true, false, false, false),
  ('Stock User', 'Item Tax Template', true, false, false, false),
  ('Stock Manager', 'Item Tax Template', true, false, false, false),
  ('Item Manager', 'Item Tax Template', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
