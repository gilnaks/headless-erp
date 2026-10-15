-- 0119 setup: Print Settings, a single doctype (one row per org). docs/modules/00-setup.md §2.13.
-- ERPNext source: erpnext/setup/install.py (create_print_setting_custom_fields: compact_item_print = 1,
-- print_uom_after_quantity = 0, print_taxes_with_zero_amount = 0).
-- Frappe source (ported from memory, the frappe repo is not cloned): frappe/printing/doctype/print_settings.
-- Deviations: `print_style` is Modern only; print server / raw printing / `enable_print_server` dropped; Frappe's
-- global default letter head becomes `letter_head_id` (the print route falls back to it, then the org default).

create table if not exists public.print_settings (
  id                             uuid primary key default gen_random_uuid(),
  org_id                         uuid not null unique references public.organizations (id) on delete cascade,
  print_style                    text not null default 'Modern' check (print_style = 'Modern'),
  font                           text not null default 'Default' check (length(trim(font)) > 0),
  font_size                      numeric(4, 1) not null default 9 check (font_size between 6 and 24),
  pdf_page_size                  text not null default 'A4' check (pdf_page_size in ('A4', 'Letter', 'Legal', 'Custom')),
  pdf_page_height                numeric(8, 2) check (pdf_page_height is null or pdf_page_height > 0),
  pdf_page_width                 numeric(8, 2) check (pdf_page_width is null or pdf_page_width > 0),
  with_letterhead                boolean not null default true,
  letter_head_id                 uuid,
  allow_print_for_draft          boolean not null default true,
  allow_print_for_cancelled      boolean not null default false,
  add_draft_heading              boolean not null default true,
  allow_page_break_inside_tables boolean not null default false,
  repeat_header_footer           boolean not null default true,
  send_print_as_pdf              boolean not null default false,
  attach_view_link               boolean not null default true,
  compact_item_print             boolean not null default true,
  print_uom_after_quantity       boolean not null default false,
  print_taxes_with_zero_amount   boolean not null default false,
  created_at                     timestamptz not null default now(),
  created_by                     uuid default auth.uid(),
  updated_at                     timestamptz not null default now(),
  updated_by                     uuid,
  constraint print_settings_letter_head_fkey foreign key (org_id, letter_head_id)
    references public.letter_head (org_id, id) on delete set null (letter_head_id),
  -- Frappe: page height/width are mandatory for a Custom page size (mm).
  constraint print_settings_custom_size
    check (pdf_page_size <> 'Custom' or (pdf_page_height is not null and pdf_page_width is not null))
);

create index if not exists print_settings_letter_head_idx on public.print_settings (letter_head_id);

drop trigger if exists touch_updated on public.print_settings;
create trigger touch_updated before update on public.print_settings
  for each row execute function app.touch_updated();

-- Seeded with every organization (Frappe ships the single with its defaults).
create or replace function app.organizations_seed_print_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.print_settings (org_id) values (new.id) on conflict (org_id) do nothing;
  return null;
end;
$$;

revoke execute on function app.organizations_seed_print_settings() from public, anon, authenticated;

drop trigger if exists organizations_seed_print_settings on public.organizations;
create trigger organizations_seed_print_settings
  after insert on public.organizations
  for each row execute function app.organizations_seed_print_settings();

------------------------------------------------------------------------------------------------------------------------
-- RLS: every member reads (printing applies the settings); writes follow role_permissions. No insert/delete: seeded.
------------------------------------------------------------------------------------------------------------------------

alter table public.print_settings enable row level security;
alter table public.print_settings force row level security;

drop policy if exists print_settings_select on public.print_settings;
create policy print_settings_select on public.print_settings for select to authenticated
  using (org_id = any ((select app.user_org_ids())::uuid[]));
drop policy if exists print_settings_update on public.print_settings;
create policy print_settings_update on public.print_settings for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Print Settings', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Print Settings', 'write'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry, permissions (Frappe print_settings.json: System Manager rwc), backfill
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, is_single)
values ('Print Settings', 'print_settings', 'setup', true)
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, is_single = excluded.is_single;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Print Settings', true, true, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

insert into public.print_settings (org_id)
select o.id from public.organizations o
on conflict (org_id) do nothing;
