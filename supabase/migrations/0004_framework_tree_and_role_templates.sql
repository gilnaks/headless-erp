-- 0004 framework: generic tree maintenance (Frappe NestedSet equivalent) and global role/permission templates.
-- Sources: frappe/utils/nestedset.py (NestedSet.validate_parent, validate_if_child_exists, validate_ledger),
-- erpnext/setup/install.py, doctype JSON `permissions` arrays.

------------------------------------------------------------------------------------------------------------------------
-- Tree doctypes: `parent_id uuid`, `is_group boolean`, `path extensions.ltree` (one label per ancestor id).
-- `path` is always derived from the parent (direct writes are overwritten). Attach with:
--   create trigger tree_path before insert or update on <t>
--     for each row execute function app.tree_maintain_path('<DocType label>');
--   create trigger tree_path_descendants after update on <t>
--     for each row execute function app.tree_update_descendants();
-- (not `after update of path`: column triggers only fire when the column is in the UPDATE's SET list, and `path`
-- is changed by the before-trigger.)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.tree_label(p_id uuid)
returns extensions.ltree
language sql
immutable
set search_path = extensions, pg_catalog
as $$
  select text2ltree('n' || replace(p_id::text, '-', ''));
$$;

create or replace function app.tree_maintain_path()
returns trigger
language plpgsql
set search_path = extensions, pg_catalog
as $$
declare
  v_label text := coalesce(tg_argv[0], tg_table_name);
  v_parent_path ltree;
  v_parent_is_group boolean;
  v_has_children boolean;
begin
  -- Rows rewritten by app.tree_update_descendants() already carry the correct path.
  if tg_op = 'UPDATE' and new.parent_id is not distinct from old.parent_id and pg_trigger_depth() > 1 then
    return new;
  end if;

  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception using errcode = 'P0001', message = format('invalid_parent: %s cannot be its own parent', v_label);
    end if;

    execute format('select path, is_group from %I.%I where id = $1 and org_id = $2', tg_table_schema, tg_table_name)
      into v_parent_path, v_parent_is_group
      using new.parent_id, new.org_id;

    if v_parent_path is null then
      raise exception using errcode = 'P0001', message = format('invalid_parent: parent %s not found', v_label);
    end if;
    if not v_parent_is_group then
      raise exception using errcode = 'P0001', message = format('invalid_parent: Parent %s must be a group %s', v_label, lower(v_label));
    end if;
    if tg_op = 'UPDATE' and v_parent_path <@ old.path then
      raise exception using errcode = 'P0001', message = format('invalid_parent: a %s cannot be moved under its own descendant', lower(v_label));
    end if;
    new.path := v_parent_path || app.tree_label(new.id);
  else
    new.path := app.tree_label(new.id);
  end if;

  if tg_op = 'UPDATE' and old.is_group and not new.is_group then
    execute format('select exists (select 1 from %I.%I where parent_id = $1)', tg_table_schema, tg_table_name)
      into v_has_children using new.id;
    if v_has_children then
      raise exception using errcode = 'P0001', message = format('has_children: %s has child nodes and cannot be converted to a non-group', v_label);
    end if;
  end if;

  return new;
end;
$$;

-- Security definer: descendants hidden from the caller by RLS/user permissions must still be re-pathed.
create or replace function app.tree_update_descendants()
returns trigger
language plpgsql
security definer
set search_path = extensions, pg_catalog
as $$
begin
  if new.path is distinct from old.path then
    execute format(
      'update %I.%I set path = $1 || subpath(path, nlevel($2)) where path <@ $2 and id <> $3',
      tg_table_schema, tg_table_name)
    using new.path, old.path, new.id;
  end if;
  return null;
end;
$$;

revoke execute on function app.tree_label(uuid), app.tree_maintain_path(), app.tree_update_descendants()
  from public, anon, authenticated;
-- tree_maintain_path runs as the caller and calls tree_label (pure formatting).
grant execute on function app.tree_label(uuid) to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Global role & permission templates. Each doctype migration upserts its default rows (from the ERPNext doctype JSON
-- `permissions` array, permlevel 0) and calls app.sync_role_permissions() so existing orgs receive them.
------------------------------------------------------------------------------------------------------------------------

create table if not exists public.role_template (
  name text primary key
);

create table if not exists public.role_permission_template (
  role       text not null references public.role_template (name) on update cascade on delete cascade,
  doctype    text not null,
  can_read   boolean not null default false,
  can_write  boolean not null default false,
  can_create boolean not null default false,
  can_submit boolean not null default false,
  can_cancel boolean not null default false,
  can_amend  boolean not null default false,
  can_delete boolean not null default false,
  can_report boolean not null default true,
  can_export boolean not null default true,
  if_owner   boolean not null default false,
  primary key (role, doctype)
);

alter table public.role_template            enable row level security; alter table public.role_template            force row level security;
alter table public.role_permission_template enable row level security; alter table public.role_permission_template force row level security;

drop policy if exists role_template_select on public.role_template;
create policy role_template_select on public.role_template for select to authenticated using (true);
drop policy if exists role_permission_template_select on public.role_permission_template;
create policy role_permission_template_select on public.role_permission_template for select to authenticated using (true);

-- Standard roles (docs/architecture/01-tenancy-auth-rls.md, docs/modules/00-setup.md §2.7).
insert into public.role_template (name) values
  ('System Manager'), ('Accounts Manager'), ('Accounts User'), ('Auditor'),
  ('Sales Manager'), ('Sales User'), ('Purchase Manager'), ('Purchase User'),
  ('Stock Manager'), ('Stock User'), ('Item Manager'),
  ('Manufacturing Manager'), ('Manufacturing User'), ('Projects Manager'), ('Projects User'),
  ('Maintenance Manager'), ('Maintenance User'), ('Quality Manager'), ('Employee')
on conflict (name) do nothing;

-- Copies missing standard roles and default permissions into one org (or all orgs when p_org is null).
-- Never overwrites rows a tenant has edited.
create or replace function app.sync_role_permissions(p_org uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.roles (org_id, name, is_standard)
  select o.id, rt.name, true
  from public.organizations o cross join public.role_template rt
  where p_org is null or o.id = p_org
  on conflict (org_id, name) do nothing;

  insert into public.role_permissions (org_id, role, doctype, can_read, can_write, can_create, can_submit,
                                       can_cancel, can_amend, can_delete, can_report, can_export, if_owner)
  select o.id, t.role, t.doctype, t.can_read, t.can_write, t.can_create, t.can_submit,
         t.can_cancel, t.can_amend, t.can_delete, t.can_report, t.can_export, t.if_owner
  from public.organizations o cross join public.role_permission_template t
  where p_org is null or o.id = p_org
  on conflict (org_id, role, doctype) do nothing;
$$;

revoke execute on function app.sync_role_permissions(uuid) from public, anon, authenticated;
