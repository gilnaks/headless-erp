-- 0118 setup: Letter Head -> public.letter_head, Company.default_letter_head FK, private `org-files` storage bucket
-- (docs/modules/00-setup.md §2.11).
-- Frappe source (ported from memory, the frappe repo is not cloned): frappe/printing/doctype/letter_head/letter_head.json
-- (naming field:letter_head_name; source/footer_source Image|HTML; align Left|Right|Center) and letter_head.py
-- (validate_disabled_and_default, set_as_default, "first enabled letter head becomes the default").
-- ERPNext source: erpnext/setup/doctype/company/company.json (default_letter_head).

create table if not exists public.letter_head (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations (id) on delete cascade,
  letter_head_name    text not null check (length(trim(letter_head_name)) > 0),
  source              text not null default 'HTML' check (source in ('HTML', 'Image')),
  content             text,
  image               text,
  image_height        numeric(10, 2) check (image_height is null or image_height >= 0),
  image_width         numeric(10, 2) check (image_width is null or image_width >= 0),
  align               text not null default 'Left' check (align in ('Left', 'Right', 'Center')),
  footer_source       text not null default 'HTML' check (footer_source in ('HTML', 'Image')),
  footer              text,
  footer_image        text,
  footer_image_height numeric(10, 2) check (footer_image_height is null or footer_image_height >= 0),
  footer_image_width  numeric(10, 2) check (footer_image_width is null or footer_image_width >= 0),
  footer_align        text not null default 'Left' check (footer_align in ('Left', 'Right', 'Center')),
  is_default          boolean not null default false,
  disabled            boolean not null default false,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid,
  unique (org_id, id),
  -- Images live in the org's own folder of the `org-files` bucket (see storage policies below).
  constraint letter_head_image_path check (image is null or starts_with(image, org_id::text || '/letter-head/')),
  constraint letter_head_footer_image_path
    check (footer_image is null or starts_with(footer_image, org_id::text || '/letter-head/'))
);

create unique index if not exists letter_head_name_uniq on public.letter_head (org_id, lower(letter_head_name));
create unique index if not exists letter_head_default_uniq on public.letter_head (org_id) where is_default;

-- LetterHead.validate + on_update: a disabled letter head cannot be the default; the first enabled one becomes the
-- default; setting a default clears the previous one (set_as_default). Definer so clearing the old default does not
-- depend on the caller's row visibility.
create or replace function app.letter_head_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.letter_head_name := trim(new.letter_head_name);
  new.content := nullif(trim(new.content), '');
  new.footer := nullif(trim(new.footer), '');
  new.image := nullif(trim(new.image), '');
  new.footer_image := nullif(trim(new.footer_image), '');

  -- Rows touched by the default-clearing update below keep exactly what that update set.
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  if new.disabled and new.is_default then
    raise exception 'letter_head_disabled_default: Letter Head cannot be both disabled and default'
      using errcode = 'P0001';
  end if;

  if not new.is_default and not new.disabled and not exists (
    select 1 from public.letter_head l where l.org_id = new.org_id and l.is_default and l.id <> new.id
  ) then
    new.is_default := true;
  end if;

  if new.is_default then
    update public.letter_head l set is_default = false
     where l.org_id = new.org_id and l.is_default and l.id <> new.id;
  end if;
  return new;
end;
$$;

revoke execute on function app.letter_head_validate() from public, anon, authenticated;

drop trigger if exists letter_head_validate on public.letter_head;
create trigger letter_head_validate
  before insert or update on public.letter_head
  for each row execute function app.letter_head_validate();

drop trigger if exists touch_updated on public.letter_head;
create trigger touch_updated
  before update on public.letter_head
  for each row execute function app.touch_updated();

-- Company.default_letter_head (0100 added the column ahead of the table). Deleting the letter head clears the link.
alter table public.companies drop constraint if exists companies_default_letter_head_fkey;
alter table public.companies add constraint companies_default_letter_head_fkey
  foreign key (org_id, default_letter_head_id) references public.letter_head (org_id, id)
  on delete set null (default_letter_head_id);

------------------------------------------------------------------------------------------------------------------------
-- RLS
------------------------------------------------------------------------------------------------------------------------

alter table public.letter_head enable row level security;
alter table public.letter_head force row level security;

drop policy if exists letter_head_select on public.letter_head;
create policy letter_head_select on public.letter_head for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Letter Head', 'read'))::uuid[]));
drop policy if exists letter_head_insert on public.letter_head;
create policy letter_head_insert on public.letter_head for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Letter Head', 'create'))::uuid[]));
drop policy if exists letter_head_update on public.letter_head;
create policy letter_head_update on public.letter_head for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Letter Head', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Letter Head', 'write'))::uuid[]));
drop policy if exists letter_head_delete on public.letter_head;
create policy letter_head_delete on public.letter_head for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Letter Head', 'delete'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (frappe: System Manager rwcd, every role reads for printing)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Letter Head', 'letter_head', 'setup', 'letter_head_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
select r.name, 'Letter Head', true, r.name = 'System Manager', r.name = 'System Manager', r.name = 'System Manager'
  from public.role_template r
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();

------------------------------------------------------------------------------------------------------------------------
-- Storage: private `org-files` bucket. Object names are `<org_id>/<folder>/<uuid>.<ext>`; members read their org's
-- files (signed URLs), uploads need write/create on the doctype that owns the folder.
------------------------------------------------------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('org-files', 'org-files', false, 2097152, array['image/png', 'image/jpeg', 'image/gif', 'image/webp'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- First path segment as an org id (null when it is not a uuid).
create or replace function app.file_org(p_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_name, '/', 1)::uuid
  end;
$$;

-- Doctype owning a folder (second path segment); unknown folders accept no uploads.
create or replace function app.file_doctype(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case split_part(p_name, '/', 2)
    when 'letter-head' then 'Letter Head'
  end;
$$;

-- True when the caller may upload/replace/remove the object: write or create on the folder's doctype.
create or replace function app.can_write_file(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select app.file_doctype(p_name) is not null
     and (app.has_perm(app.file_org(p_name), app.file_doctype(p_name), 'write')
          or app.has_perm(app.file_org(p_name), app.file_doctype(p_name), 'create'));
$$;

revoke execute on function app.file_org(text) from public, anon;
revoke execute on function app.file_doctype(text) from public, anon;
revoke execute on function app.can_write_file(text) from public, anon;
grant execute on function app.file_org(text) to authenticated;
grant execute on function app.file_doctype(text) to authenticated;
grant execute on function app.can_write_file(text) to authenticated;

drop policy if exists org_files_select on storage.objects;
create policy org_files_select on storage.objects for select to authenticated
  using (bucket_id = 'org-files' and app.is_member(app.file_org(name)));
drop policy if exists org_files_insert on storage.objects;
create policy org_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'org-files' and app.can_write_file(name));
drop policy if exists org_files_update on storage.objects;
create policy org_files_update on storage.objects for update to authenticated
  using (bucket_id = 'org-files' and app.can_write_file(name))
  with check (bucket_id = 'org-files' and app.can_write_file(name));
drop policy if exists org_files_delete on storage.objects;
create policy org_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'org-files' and app.can_write_file(name));
