-- 0500 selling: Quotation Lost Reason (docs/modules/02-selling.md §2.8). Not seeded.
-- ERPNext: erpnext/setup/doctype/quotation_lost_reason/quotation_lost_reason.json.
-- Sales Master Manager rwcd is granted to Sales Manager (that role is not seeded).
-- System Manager read is added because every tenant doctype grants it.
-- Maintenance User and Maintenance Manager are omitted.

create table if not exists public.quotation_lost_reason (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations (id) on delete cascade,
  order_lost_reason  text not null check (length(trim(order_lost_reason)) > 0),
  created_at         timestamptz not null default now(),
  created_by         uuid default auth.uid(),
  updated_at         timestamptz not null default now(),
  updated_by         uuid,
  unique (org_id, id)
);

create unique index if not exists quotation_lost_reason_name_uniq
  on public.quotation_lost_reason (org_id, lower(order_lost_reason));

create or replace function app.quotation_lost_reason_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.order_lost_reason := trim(new.order_lost_reason);
  return new;
end;
$$;

revoke execute on function app.quotation_lost_reason_validate() from public, anon, authenticated;

drop trigger if exists quotation_lost_reason_validate on public.quotation_lost_reason;
create trigger quotation_lost_reason_validate before insert or update on public.quotation_lost_reason
  for each row execute function app.quotation_lost_reason_validate();
drop trigger if exists touch_updated on public.quotation_lost_reason;
create trigger touch_updated before update on public.quotation_lost_reason
  for each row execute function app.touch_updated();

alter table public.quotation_lost_reason enable row level security;
alter table public.quotation_lost_reason force row level security;
drop policy if exists quotation_lost_reason_select on public.quotation_lost_reason;
create policy quotation_lost_reason_select on public.quotation_lost_reason for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation Lost Reason', 'read'))::uuid[]));
drop policy if exists quotation_lost_reason_insert on public.quotation_lost_reason;
create policy quotation_lost_reason_insert on public.quotation_lost_reason for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Quotation Lost Reason', 'create'))::uuid[]));
drop policy if exists quotation_lost_reason_update on public.quotation_lost_reason;
create policy quotation_lost_reason_update on public.quotation_lost_reason for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation Lost Reason', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Quotation Lost Reason', 'write'))::uuid[]));
drop policy if exists quotation_lost_reason_delete on public.quotation_lost_reason;
create policy quotation_lost_reason_delete on public.quotation_lost_reason for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Quotation Lost Reason', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Quotation Lost Reason', 'quotation_lost_reason', 'selling', 'order_lost_reason')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('Sales Manager', 'Quotation Lost Reason', true, true, true, true),
  ('Sales User', 'Quotation Lost Reason', true, false, false, false),
  ('System Manager', 'Quotation Lost Reason', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
