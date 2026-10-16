-- 0208 setup: Terms and Conditions (docs/modules/00-setup.md §2.24).
-- ERPNext: erpnext/setup/doctype/terms_and_conditions/terms_and_conditions.json.
-- Rendering uses the same handlebars subset as Email Template. At least one of selling/buying unless disabled.
-- Company default_selling_terms_id and default_buying_terms_id stay plain uuid until Payment Terms.

create table if not exists public.terms_and_conditions (
  id                              uuid primary key default gen_random_uuid(),
  org_id                          uuid not null references public.organizations (id) on delete cascade,
  title                           text not null check (length(trim(title)) > 0),
  disabled                        boolean not null default false,
  terms                           text,
  selling                         boolean not null default true,
  buying                          boolean not null default true,
  copy_attachments_to_transaction boolean not null default false,
  created_at                      timestamptz not null default now(),
  created_by                      uuid default auth.uid(),
  updated_at                      timestamptz not null default now(),
  updated_by                      uuid,
  unique (org_id, id)
);

create unique index if not exists terms_title_uniq on public.terms_and_conditions (org_id, lower(title));

create or replace function app.terms_and_conditions_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.title := trim(new.title);
  if not new.disabled and not new.selling and not new.buying then
    raise exception using errcode = 'P0001', message = 'terms_module: At least one of Selling or Buying must be selected';
  end if;
  return new;
end;
$$;

revoke execute on function app.terms_and_conditions_validate() from public, anon, authenticated;

drop trigger if exists terms_and_conditions_validate on public.terms_and_conditions;
create trigger terms_and_conditions_validate before insert or update on public.terms_and_conditions
  for each row execute function app.terms_and_conditions_validate();
drop trigger if exists touch_updated on public.terms_and_conditions;
create trigger touch_updated before update on public.terms_and_conditions
  for each row execute function app.touch_updated();

alter table public.terms_and_conditions enable row level security;
alter table public.terms_and_conditions force row level security;
drop policy if exists terms_select on public.terms_and_conditions;
create policy terms_select on public.terms_and_conditions for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Terms and Conditions', 'read'))::uuid[]));
drop policy if exists terms_insert on public.terms_and_conditions;
create policy terms_insert on public.terms_and_conditions for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Terms and Conditions', 'create'))::uuid[]));
drop policy if exists terms_update on public.terms_and_conditions;
create policy terms_update on public.terms_and_conditions for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Terms and Conditions', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Terms and Conditions', 'write'))::uuid[]));
drop policy if exists terms_delete on public.terms_and_conditions;
create policy terms_delete on public.terms_and_conditions for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Terms and Conditions', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field, html_columns)
values ('Terms and Conditions', 'terms_and_conditions', 'setup', 'title', '{terms}')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field,
      html_columns = excluded.html_columns;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Terms and Conditions', true, true, true, true),
  ('Accounts Manager', 'Terms and Conditions', true, true, true, true),
  ('Sales Manager', 'Terms and Conditions', true, true, true, true),
  ('Purchase Manager', 'Terms and Conditions', true, true, true, true),
  ('Sales User', 'Terms and Conditions', true, false, false, false),
  ('Purchase User', 'Terms and Conditions', true, false, false, false),
  ('Stock User', 'Terms and Conditions', true, false, false, false),
  ('Accounts User', 'Terms and Conditions', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
