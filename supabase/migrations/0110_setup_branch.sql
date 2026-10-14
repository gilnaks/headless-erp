-- 0110 setup: Branch -> public.branch (docs/modules/00-setup.md §2.2).
-- ERPNext source: erpnext/setup/doctype/branch/branch.json (naming field:branch; no controller logic).

create table if not exists public.branch (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  branch     text not null check (length(trim(branch)) > 0),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (org_id, id)
);

create unique index if not exists branch_name_uniq on public.branch (org_id, lower(branch));

create or replace function app.branch_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.branch := trim(new.branch);
  return new;
end;
$$;

revoke execute on function app.branch_validate() from public, anon, authenticated;

drop trigger if exists branch_validate on public.branch;
create trigger branch_validate
  before insert or update on public.branch
  for each row execute function app.branch_validate();

drop trigger if exists touch_updated on public.branch;
create trigger touch_updated
  before update on public.branch
  for each row execute function app.touch_updated();

------------------------------------------------------------------------------------------------------------------------
-- RLS
------------------------------------------------------------------------------------------------------------------------

alter table public.branch enable row level security;
alter table public.branch force row level security;

drop policy if exists branch_select on public.branch;
create policy branch_select on public.branch for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Branch', 'read'))::uuid[]));
drop policy if exists branch_insert on public.branch;
create policy branch_insert on public.branch for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Branch', 'create'))::uuid[]));
drop policy if exists branch_update on public.branch;
create policy branch_update on public.branch for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Branch', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Branch', 'write'))::uuid[]));
drop policy if exists branch_delete on public.branch;
create policy branch_delete on public.branch for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Branch', 'delete'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (HR User / HR Manager are not seeded: System Manager rwcd, read for every role)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Branch', 'branch', 'setup', 'branch')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
select r.name, 'Branch', true, r.name = 'System Manager', r.name = 'System Manager', r.name = 'System Manager'
  from public.role_template r
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
