-- 0108 setup: Role Permissions manager (docs/modules/00-setup.md §2.8, §8).
-- ERPNext source: doctype JSON `permissions` arrays (seeded into role_permission_template by each doctype migration).
-- Frappe (no local clone; from memory): frappe/core/page/permission_manager/permission_manager.py (add, update,
-- remove, reset: reset deletes the Custom DocPerm rows of one doctype and falls back to the standard ones),
-- frappe/core/doctype/doctype/doctype.py validate_permissions (submit/cancel/amend only on submittable doctypes,
-- cancel needs submit, amend needs cancel, submit/cancel/amend need write).

------------------------------------------------------------------------------------------------------------------------
-- Validation of tenant edits (migrations and security definer functions are trusted)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.role_permissions_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  select * into v_meta from public.doctype_meta where doctype = new.doctype;
  if not found or v_meta.is_child then
    raise exception using errcode = 'P0001', message = format('doctype_unknown: %s is not a document type', new.doctype);
  end if;
  if not v_meta.is_submittable and (new.can_submit or new.can_cancel or new.can_amend) then
    raise exception using errcode = 'P0001',
      message = format('perm_not_submittable: Submit, Cancel and Amend only apply to submittable document types (%s is not)', new.doctype);
  end if;
  if (new.can_submit or new.can_cancel or new.can_amend) and not new.can_write then
    raise exception using errcode = 'P0001', message = 'perm_dependency: Submit, Cancel and Amend need Write';
  end if;
  if new.can_cancel and not new.can_submit then
    raise exception using errcode = 'P0001', message = 'perm_dependency: Cancel needs Submit';
  end if;
  if new.can_amend and not new.can_cancel then
    raise exception using errcode = 'P0001', message = 'perm_dependency: Amend needs Cancel';
  end if;
  return new;
end;
$$;

drop trigger if exists role_permissions_validate on public.role_permissions;
create trigger role_permissions_validate
  before insert or update on public.role_permissions
  for each row execute function app.role_permissions_validate();

------------------------------------------------------------------------------------------------------------------------
-- Reset one doctype to the defaults (frappe permission_manager.reset)
------------------------------------------------------------------------------------------------------------------------

create or replace function app.reset_role_permissions(p_org uuid, p_doctype text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (p_org = any (app.orgs_with_role('System Manager'))) then
    raise exception using errcode = '42501', message = 'permission_denied: only a System Manager can reset permissions';
  end if;
  if p_doctype = any (app.locked_permission_doctypes()) then
    raise exception using errcode = 'P0001',
      message = format('permission_locked: permissions for %s are fixed to System Manager', p_doctype);
  end if;
  if not exists (select 1 from public.doctype_meta where doctype = p_doctype and not is_child) then
    raise exception using errcode = 'P0001', message = format('doctype_unknown: %s is not a document type', p_doctype);
  end if;

  delete from public.role_permissions where org_id = p_org and doctype = p_doctype;
  insert into public.role_permissions (org_id, role, doctype, can_read, can_write, can_create, can_submit,
                                       can_cancel, can_amend, can_delete, can_report, can_export, if_owner)
  select p_org, t.role, t.doctype, t.can_read, t.can_write, t.can_create, t.can_submit,
         t.can_cancel, t.can_amend, t.can_delete, t.can_report, t.can_export, t.if_owner
  from public.role_permission_template t
  where t.doctype = p_doctype
    and exists (select 1 from public.roles r where r.org_id = p_org and r.name = t.role);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.reset_role_permissions(p_org uuid, p_doctype text)
returns integer
language sql
security invoker
set search_path = ''
as $$
  select app.reset_role_permissions(p_org, p_doctype);
$$;

-- Doctypes the matrix can show (no child tables), with what applies to each.
create or replace function public.permission_doctypes()
returns table (doctype text, module text, is_submittable boolean, locked boolean)
language sql
stable
security invoker
set search_path = ''
as $$
  select m.doctype, m.module, m.is_submittable, m.doctype = any (app.locked_permission_doctypes())
  from public.doctype_meta m
  where not m.is_child
  order by m.module, m.doctype;
$$;

revoke execute on function
  app.role_permissions_validate(), app.reset_role_permissions(uuid, text),
  public.reset_role_permissions(uuid, text), public.permission_doctypes()
from public, anon, authenticated;
grant execute on function
  app.reset_role_permissions(uuid, text), public.reset_role_permissions(uuid, text), public.permission_doctypes()
to authenticated;
