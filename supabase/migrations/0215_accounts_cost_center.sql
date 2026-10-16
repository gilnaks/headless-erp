-- 0215 accounts: Cost Center tree (docs/modules/01-accounts.md §2.3, 00-setup B6).
-- ERPNext: erpnext/accounts/doctype/cost_center. Root is the company name; Main is the default ledger.

create table if not exists public.cost_center (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations (id) on delete cascade,
  name               text not null,
  cost_center_name   text not null check (length(trim(cost_center_name)) > 0),
  cost_center_number text,
  parent_id          uuid,
  company_id         uuid not null,
  is_group           boolean not null default false,
  disabled           boolean not null default false,
  path               extensions.ltree not null,
  created_at         timestamptz not null default now(),
  created_by         uuid default auth.uid(),
  updated_at         timestamptz not null default now(),
  updated_by         uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete cascade,
  foreign key (org_id, parent_id) references public.cost_center (org_id, id)
);

create index if not exists cost_center_parent_idx on public.cost_center (org_id, parent_id);
create index if not exists cost_center_company_idx on public.cost_center (org_id, company_id);
create index if not exists cost_center_path_idx on public.cost_center using gist (path);

create or replace function app.cost_center_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_abbr text;
  v_parent_company uuid;
begin
  new.cost_center_name := trim(new.cost_center_name);
  if tg_op = 'UPDATE' and new.company_id is distinct from old.company_id then
    raise exception using errcode = 'P0001', message = 'cost_center_company: Company cannot be changed for an existing Cost Center';
  end if;
  if new.parent_id is null then
    if exists (
      select 1 from public.cost_center c
      where c.company_id = new.company_id and c.parent_id is null and c.id is distinct from new.id
    ) then
      raise exception using errcode = 'P0001', message = 'cost_center_parent: Please enter parent cost center';
    end if;
  else
    select company_id into v_parent_company from public.cost_center where id = new.parent_id and org_id = new.org_id;
    if v_parent_company is distinct from new.company_id then
      raise exception using errcode = 'P0001', message = 'cost_center_parent: Parent cost center must belong to the same company';
    end if;
  end if;
  select abbr into v_abbr from public.companies where id = new.company_id;
  new.name := case
    when nullif(trim(new.cost_center_number), '') is not null
      then trim(new.cost_center_number) || ' - ' || new.cost_center_name || ' - ' || v_abbr
    else new.cost_center_name || ' - ' || v_abbr
  end;
  return new;
end;
$$;

create or replace function app.seed_cost_centers(p_company uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_name text;
  v_root uuid;
  v_main uuid;
begin
  if exists (select 1 from public.cost_center where company_id = p_company) then
    return;
  end if;
  select org_id, company_name into v_org, v_name from public.companies where id = p_company;
  insert into public.cost_center (org_id, cost_center_name, company_id, is_group)
  values (v_org, v_name, p_company, true)
  returning id into v_root;
  insert into public.cost_center (org_id, cost_center_name, company_id, is_group, parent_id)
  values (v_org, 'Main', p_company, false, v_root)
  returning id into v_main;
  update public.companies set
    cost_center_id = v_main,
    round_off_cost_center_id = v_main,
    depreciation_cost_center_id = v_main
  where id = p_company;
end;
$$;

create or replace function app.companies_seed_cost_centers()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_cost_centers(new.id);
  return null;
end;
$$;

revoke execute on function app.cost_center_validate(), app.seed_cost_centers(uuid), app.companies_seed_cost_centers()
from public, anon, authenticated;

drop trigger if exists cost_center_validate on public.cost_center;
create trigger cost_center_validate before insert or update on public.cost_center
  for each row execute function app.cost_center_validate();
drop trigger if exists tree_path on public.cost_center;
create trigger tree_path before insert or update on public.cost_center
  for each row execute function app.tree_maintain_path('Cost Center');
drop trigger if exists tree_path_descendants on public.cost_center;
create trigger tree_path_descendants after update on public.cost_center
  for each row execute function app.tree_update_descendants();
drop trigger if exists touch_updated on public.cost_center;
create trigger touch_updated before update on public.cost_center
  for each row execute function app.touch_updated();
drop trigger if exists companies_seed_cost_centers on public.companies;
create trigger companies_seed_cost_centers after insert on public.companies
  for each row execute function app.companies_seed_cost_centers();

select app.seed_cost_centers(c.id) from public.companies c;

alter table public.cost_center enable row level security;
alter table public.cost_center force row level security;
drop policy if exists cost_center_select on public.cost_center;
create policy cost_center_select on public.cost_center for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Cost Center', 'read'))::uuid[]));
drop policy if exists cost_center_insert on public.cost_center;
create policy cost_center_insert on public.cost_center for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Cost Center', 'create'))::uuid[]));
drop policy if exists cost_center_update on public.cost_center;
create policy cost_center_update on public.cost_center for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Cost Center', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Cost Center', 'write'))::uuid[]));
drop policy if exists cost_center_delete on public.cost_center;
create policy cost_center_delete on public.cost_center for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Cost Center', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, is_tree, title_field)
values ('Cost Center', 'cost_center', 'accounts', true, 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_tree = excluded.is_tree,
      title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Cost Center', true, false, false, false),
  ('Accounts Manager', 'Cost Center', true, true, true, true),
  ('Auditor', 'Cost Center', true, false, false, false),
  ('Accounts User', 'Cost Center', true, false, false, false),
  ('Sales User', 'Cost Center', true, false, false, false),
  ('Purchase User', 'Cost Center', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

create index if not exists companies_cost_center_idx on public.companies (org_id, cost_center_id);
create index if not exists companies_round_off_cost_center_idx on public.companies (org_id, round_off_cost_center_id);
create index if not exists companies_depreciation_cost_center_idx on public.companies (org_id, depreciation_cost_center_id);

alter table public.companies
  add constraint companies_cost_center_fk foreign key (org_id, cost_center_id) references public.cost_center (org_id, id),
  add constraint companies_round_off_cost_center_fk foreign key (org_id, round_off_cost_center_id) references public.cost_center (org_id, id),
  add constraint companies_depreciation_cost_center_fk foreign key (org_id, depreciation_cost_center_id) references public.cost_center (org_id, id);
