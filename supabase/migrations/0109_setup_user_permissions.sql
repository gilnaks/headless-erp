-- 0109 setup: User Permission (docs/modules/00-setup.md §2.9, docs/architecture/01-tenancy-auth-rls.md).
-- ERPNext sources: erpnext/accounts/utils.py build_qb_match_conditions (non-strict: empty links pass),
-- erpnext/setup/doctype/employee/employee.py add_user_permission / remove_user_permission.
-- Frappe (no local clone; from memory): frappe/core/doctype/user_permission/user_permission.py (validate_user_permission
-- duplicate check, validate_default_permission: one default per user and allow), frappe/permissions.py
-- get_user_permissions (tree doctypes add descendants unless hide_descendants; apply_to_all_doctypes or the
-- applicable_for doctype).

------------------------------------------------------------------------------------------------------------------------
-- Validation
------------------------------------------------------------------------------------------------------------------------

-- Security definer: a System Manager restricted by their own User Permissions may still grant other records.
create or replace function app.user_permissions_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta public.doctype_meta;
  v_exists boolean;
begin
  new.applicable_for := nullif(trim(new.applicable_for), '');

  if not exists (select 1 from public.org_members m where m.org_id = new.org_id and m.user_id = new.user_id) then
    raise exception using errcode = 'P0001', message = 'user_not_member: the user is not a member of this organization';
  end if;

  select * into v_meta from public.doctype_meta where doctype = new.doctype;
  if not found or not v_meta.user_permission_target then
    raise exception using errcode = 'P0001',
      message = format('doctype_not_allowed: User Permissions cannot restrict %s', new.doctype);
  end if;

  execute format('select exists (select 1 from public.%I where org_id = $1 and id = $2)', v_meta.table_name)
    into v_exists using new.org_id, new.record_id;
  if not v_exists then
    raise exception using errcode = 'P0001', message = format('record_unknown: %s not found', new.doctype);
  end if;

  if new.applicable_for is not null
     and not exists (select 1 from public.doctype_meta d where d.doctype = new.applicable_for and not d.is_child) then
    raise exception using errcode = 'P0001',
      message = format('applicable_for_unknown: %s is not a document type', new.applicable_for);
  end if;

  if not v_meta.is_tree then
    new.hide_descendants := false;
  end if;

  if new.is_default and exists (
    select 1 from public.user_permissions up
     where up.org_id = new.org_id and up.user_id = new.user_id and up.doctype = new.doctype
       and up.is_default and up.id <> new.id
  ) then
    raise exception using errcode = 'P0001',
      message = format('default_exists: this user already has a default %s', new.doctype);
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists user_permissions_validate on public.user_permissions;
create trigger user_permissions_validate
  before insert or update on public.user_permissions
  for each row execute function app.user_permissions_validate();

revoke execute on function app.user_permissions_validate() from public, anon, authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Allowed records: tree doctypes include descendants; a doctype's own records use rows applicable to it
------------------------------------------------------------------------------------------------------------------------

create or replace function app.allowed_records(p_org uuid, p_doctype text, p_for text default null)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact uuid[];
  v_roots uuid[];
  v_meta public.doctype_meta;
begin
  select array_agg(up.record_id) filter (where up.hide_descendants),
         array_agg(up.record_id) filter (where not up.hide_descendants)
    into v_exact, v_roots
    from public.user_permissions up
   where up.org_id = p_org
     and up.user_id = (select auth.uid())
     and up.doctype = p_doctype
     and (up.applicable_for is null or up.applicable_for = coalesce(p_for, p_doctype));

  if v_exact is null and v_roots is null then
    return null;
  end if;

  if v_roots is not null then
    select * into v_meta from public.doctype_meta where doctype = p_doctype;
    if v_meta.is_tree then
      execute format(
        'select array_agg(t.id) from public.%I t
          where t.org_id = $1
            and exists (select 1 from public.%I r
                         where r.org_id = $1 and r.id = any ($2) and t.path operator(extensions.<@) r.path)',
        v_meta.table_name, v_meta.table_name
      ) into v_roots using p_org, v_roots;
    end if;
  end if;

  return coalesce(v_exact, '{}') || coalesce(v_roots, '{}');
end;
$$;

create or replace function app.record_allowed(p_org uuid, p_doctype text, p_record uuid, p_for text default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select a.ids is null or p_record = any (a.ids)
    from (select app.allowed_records(p_org, p_doctype, p_for) as ids) a;
$$;

------------------------------------------------------------------------------------------------------------------------
-- Default permissions (frappe user_permission.json: System Manager only; locked by 0105)
------------------------------------------------------------------------------------------------------------------------

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'User Permission', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
