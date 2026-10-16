-- 0210 accounts: Account Category (docs/modules/01-accounts.md §2.2).
-- ERPNext: erpnext/accounts/doctype/account_category/account_category.json.
-- Names are every account_category referenced by the vendored charts, so B3 can link them.
-- The seed stores the name only, so root_type stays null.

create table if not exists public.account_category (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations (id) on delete cascade,
  account_category_name  text not null check (length(trim(account_category_name)) > 0),
  description            text,
  root_type              text check (root_type in ('Asset', 'Liability', 'Equity', 'Income', 'Expense')),
  created_at             timestamptz not null default now(),
  created_by             uuid default auth.uid(),
  updated_at             timestamptz not null default now(),
  updated_by             uuid,
  unique (org_id, id)
);

create unique index if not exists account_category_name_uniq
  on public.account_category (org_id, lower(account_category_name));

create or replace function app.account_category_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.account_category_name := trim(new.account_category_name);
  return new;
end;
$$;

-- Walk a chart JSON object and return distinct account_category strings.
create or replace function app.coa_account_categories(p_tree jsonb)
returns setof text
language sql
stable
set search_path = ''
as $$
  with recursive walk as (
    select p_tree as node
    union all
    select v.value
    from walk w
    cross join lateral jsonb_each(case when jsonb_typeof(w.node) = 'object' then w.node else '{}'::jsonb end) as v(key, value)
    where jsonb_typeof(v.value) = 'object'
      and v.key <> all (array[
        'account_name', 'account_number', 'account_type', 'account_category', 'root_type', 'is_group', 'tax_rate'
      ])
  )
  select distinct node ->> 'account_category'
  from walk
  where jsonb_typeof(node) = 'object' and node ? 'account_category' and length(node ->> 'account_category') > 0;
$$;

create or replace function app.seed_account_categories(p_org uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.account_category (org_id, account_category_name)
  select distinct p_org, c.category
  from public.coa_template t
  cross join lateral app.coa_account_categories(t.tree::jsonb) as c(category)
  on conflict (org_id, lower(account_category_name)) do nothing;
$$;

create or replace function app.organizations_seed_account_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.seed_account_categories(new.id);
  return null;
end;
$$;

revoke execute on function app.account_category_validate(), app.coa_account_categories(jsonb),
  app.seed_account_categories(uuid), app.organizations_seed_account_categories()
from public, anon, authenticated;

drop trigger if exists account_category_validate on public.account_category;
create trigger account_category_validate before insert or update on public.account_category
  for each row execute function app.account_category_validate();
drop trigger if exists touch_updated on public.account_category;
create trigger touch_updated before update on public.account_category
  for each row execute function app.touch_updated();
drop trigger if exists organizations_seed_account_categories on public.organizations;
create trigger organizations_seed_account_categories after insert on public.organizations
  for each row execute function app.organizations_seed_account_categories();

select app.seed_account_categories(o.id) from public.organizations o;

alter table public.account_category enable row level security;
alter table public.account_category force row level security;
drop policy if exists account_category_select on public.account_category;
create policy account_category_select on public.account_category for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Account Category', 'read'))::uuid[]));
drop policy if exists account_category_insert on public.account_category;
create policy account_category_insert on public.account_category for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Account Category', 'create'))::uuid[]));
drop policy if exists account_category_update on public.account_category;
create policy account_category_update on public.account_category for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Account Category', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Account Category', 'write'))::uuid[]));
drop policy if exists account_category_delete on public.account_category;
create policy account_category_delete on public.account_category for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Account Category', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Account Category', 'account_category', 'accounts', 'account_category_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Account Category', true, false, false, false),
  ('Accounts User', 'Account Category', true, true, true, true),
  ('Accounts Manager', 'Account Category', true, true, true, true),
  ('Auditor', 'Account Category', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
