-- 0124 setup: Email Template -> public.email_template (docs/modules/00-setup.md §2.15).
-- Frappe Email Template (frappe/email/doctype/email_template: prompt name, subject, use_html, response_html,
-- response) ported from memory: the frappe repository is not cloned. Placeholders are a handlebars subset rendered
-- by src/lib/email/render.ts (validated on save there), not Jinja.

create table if not exists public.email_template (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations (id) on delete cascade,
  name          text not null check (length(trim(name)) > 0),
  subject       text not null check (length(trim(subject)) > 0),
  use_html      boolean not null default true,
  response_html text,
  response      text,
  created_at    timestamptz not null default now(),
  created_by    uuid default auth.uid(),
  updated_at    timestamptz not null default now(),
  updated_by    uuid,
  unique (org_id, id)
);

create unique index if not exists email_template_name_uniq on public.email_template (org_id, lower(name));

create or replace function app.email_template_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := trim(new.name);
  new.subject := trim(new.subject);
  new.response_html := nullif(trim(new.response_html), '');
  new.response := nullif(trim(new.response), '');
  return new;
end;
$$;

revoke execute on function app.email_template_validate() from public, anon, authenticated;

drop trigger if exists email_template_validate on public.email_template;
create trigger email_template_validate
  before insert or update on public.email_template
  for each row execute function app.email_template_validate();

drop trigger if exists touch_updated on public.email_template;
create trigger touch_updated
  before update on public.email_template
  for each row execute function app.touch_updated();

alter table public.email_template enable row level security;
alter table public.email_template force row level security;

drop policy if exists email_template_select on public.email_template;
create policy email_template_select on public.email_template for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Email Template', 'read'))::uuid[]));
drop policy if exists email_template_insert on public.email_template;
create policy email_template_insert on public.email_template for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Email Template', 'create'))::uuid[]));
drop policy if exists email_template_update on public.email_template;
create policy email_template_update on public.email_template for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Email Template', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Email Template', 'write'))::uuid[]));
drop policy if exists email_template_delete on public.email_template;
create policy email_template_delete on public.email_template for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Email Template', 'delete'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions: System Manager rwcd; Sales / Purchase / Accounts Manager rw; every other role reads
-- (templates are picked when emailing any document).
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Email Template', 'email_template', 'setup', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
select r.role, 'Email Template', true,
       r.role in ('System Manager', 'Sales Manager', 'Purchase Manager', 'Accounts Manager'),
       r.role = 'System Manager',
       r.role = 'System Manager'
  from unnest(array[
    'Accounts Manager', 'Accounts User', 'Auditor', 'Employee', 'Item Manager', 'Maintenance Manager',
    'Maintenance User', 'Manufacturing Manager', 'Manufacturing User', 'Projects Manager', 'Projects User',
    'Purchase Manager', 'Purchase User', 'Quality Manager', 'Sales Manager', 'Sales User', 'Stock Manager',
    'Stock User', 'System Manager'
  ]) as r(role)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
