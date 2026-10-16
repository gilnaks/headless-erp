-- 0226 accounts: Tax Category (docs/modules/01-accounts.md §2.13).
-- ERPNext: erpnext/accounts/doctype/tax_category/tax_category.json (autoname field:title).
-- Address may point here. Deleting the category clears that link. get_address_tax_category waits for Accounts Settings.

create table if not exists public.tax_category (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  name       text not null,
  title      text not null check (length(trim(title)) > 0),
  disabled   boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (org_id, id)
);

create unique index if not exists tax_category_title_uniq on public.tax_category (org_id, lower(title));

create or replace function app.tax_category_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.title := trim(new.title);
  new.name := new.title;
  return new;
end;
$$;

revoke execute on function app.tax_category_validate() from public, anon, authenticated;

drop trigger if exists tax_category_validate on public.tax_category;
create trigger tax_category_validate before insert or update on public.tax_category
  for each row execute function app.tax_category_validate();
drop trigger if exists touch_updated on public.tax_category;
create trigger touch_updated before update on public.tax_category
  for each row execute function app.touch_updated();

alter table public.address add column if not exists tax_category_id uuid;
alter table public.address drop constraint if exists address_tax_category_fk;
alter table public.address
  add constraint address_tax_category_fk
  foreign key (org_id, tax_category_id) references public.tax_category (org_id, id)
  on delete set null (tax_category_id);

create index if not exists address_tax_category_idx on public.address (org_id, tax_category_id);

alter table public.tax_category enable row level security;
alter table public.tax_category force row level security;

drop policy if exists tax_category_select on public.tax_category;
create policy tax_category_select on public.tax_category for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Tax Category', 'read'))::uuid[]));
drop policy if exists tax_category_insert on public.tax_category;
create policy tax_category_insert on public.tax_category for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Tax Category', 'create'))::uuid[]));
drop policy if exists tax_category_update on public.tax_category;
create policy tax_category_update on public.tax_category for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Tax Category', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Tax Category', 'write'))::uuid[]));
drop policy if exists tax_category_delete on public.tax_category;
create policy tax_category_delete on public.tax_category for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Tax Category', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Tax Category', 'tax_category', 'accounts', 'name')
on conflict (doctype) do update set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Tax Category', true, true, true, true),
  ('Accounts Manager', 'Tax Category', true, true, true, true),
  ('Accounts User', 'Tax Category', true, false, false, false),
  ('Sales User', 'Tax Category', true, false, false, false),
  ('Sales Manager', 'Tax Category', true, false, false, false),
  ('Purchase User', 'Tax Category', true, false, false, false),
  ('Purchase Manager', 'Tax Category', true, false, false, false),
  ('Stock User', 'Tax Category', true, false, false, false),
  ('Stock Manager', 'Tax Category', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
