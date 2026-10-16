-- 0206 selling: Industry Type (docs/modules/02-selling.md §2.7). Not seeded; 00-setup skipped the fixture.
-- ERPNext: erpnext/selling/doctype/industry_type/industry_type.json.
-- System Manager read is added because every tenant doctype grants it. The JSON omits that role.
-- Sales Manager is rwc. Neither Sales Manager nor Sales Master Manager has delete in the JSON.

create table if not exists public.industry_type (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  industry   text not null check (length(trim(industry)) > 0),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (org_id, id)
);

create unique index if not exists industry_type_name_uniq on public.industry_type (org_id, lower(industry));

create or replace function app.industry_type_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.industry := trim(new.industry);
  return new;
end;
$$;

revoke execute on function app.industry_type_validate() from public, anon, authenticated;

drop trigger if exists industry_type_validate on public.industry_type;
create trigger industry_type_validate before insert or update on public.industry_type
  for each row execute function app.industry_type_validate();
drop trigger if exists touch_updated on public.industry_type;
create trigger touch_updated before update on public.industry_type
  for each row execute function app.touch_updated();

alter table public.industry_type enable row level security;
alter table public.industry_type force row level security;
drop policy if exists industry_type_select on public.industry_type;
create policy industry_type_select on public.industry_type for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Industry Type', 'read'))::uuid[]));
drop policy if exists industry_type_insert on public.industry_type;
create policy industry_type_insert on public.industry_type for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Industry Type', 'create'))::uuid[]));
drop policy if exists industry_type_update on public.industry_type;
create policy industry_type_update on public.industry_type for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Industry Type', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Industry Type', 'write'))::uuid[]));
drop policy if exists industry_type_delete on public.industry_type;
create policy industry_type_delete on public.industry_type for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Industry Type', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Industry Type', 'industry_type', 'selling', 'industry')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Sales Manager', 'Industry Type', true, true, true, false),
  ('Sales User', 'Industry Type', true, false, false, false),
  ('System Manager', 'Industry Type', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
