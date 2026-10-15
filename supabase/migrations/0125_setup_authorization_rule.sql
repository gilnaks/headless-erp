-- 0125 setup: Authorization Rule -> public.authorization_rule (docs/modules/00-setup.md §2.10, simplified port).
-- ERPNext sources: erpnext/setup/doctype/authorization_rule/authorization_rule.{json,py} (naming HR-ARU-.#####,
-- check_duplicate_entry, validate_rule, value defaults to 0) and
-- erpnext/setup/doctype/authorization_control/authorization_control.py (validate_approving_authority,
-- bifurcate_based_on_type, validate_auth_rule, get_appr_user_role).
-- Only `Grand Total` on Sales Order / Purchase Order / Sales Invoice / Purchase Invoice is ported; discount bases,
-- Quotation / Delivery Note / Purchase Receipt and the Employee / Designation targets are dropped.
-- `app.validate_approving_authority` is called from the submit paths of those doctypes (P5/P6).
-- `system_user` is a reserved word since Postgres 16: quote it where it is not qualified.

create table if not exists public.authorization_rule (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations (id) on delete cascade,
  name           text not null,
  transaction    text not null
                 check (transaction in ('Sales Order', 'Purchase Order', 'Sales Invoice', 'Purchase Invoice')),
  based_on       text not null default 'Grand Total' check (based_on in ('Grand Total')),
  company_id     uuid,
  value          numeric(21, 9) not null default 0,
  system_role    text,
  "system_user"  uuid references auth.users (id) on delete set null,
  approving_role text,
  approving_user uuid references auth.users (id) on delete set null,
  created_at     timestamptz not null default now(),
  created_by     uuid default auth.uid(),
  updated_at     timestamptz not null default now(),
  updated_by     uuid,
  unique (org_id, id),
  unique (org_id, name),
  foreign key (org_id, company_id) references public.companies (org_id, id),
  foreign key (org_id, system_role) references public.roles (org_id, name) on delete set null (system_role),
  foreign key (org_id, approving_role) references public.roles (org_id, name) on delete set null (approving_role)
);

create index if not exists authorization_rule_lookup_idx on public.authorization_rule (org_id, transaction);
create index if not exists authorization_rule_company_idx on public.authorization_rule (company_id);
create index if not exists authorization_rule_system_user_idx on public.authorization_rule ("system_user");
create index if not exists authorization_rule_approving_user_idx on public.authorization_rule (approving_user);

-- AuthorizationRule.validate. Definer: issues the name (app.next_name) and sees every rule for the duplicate check.
-- Cascaded FK updates (a deleted role or user) skip validation so they cannot be blocked by it.
create or replace function app.authorization_rule_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dup text;
begin
  if tg_op = 'INSERT' then
    new.name := app.next_name(new.org_id, null, 'HR-ARU-.#####');
  else
    new.name := old.name;
  end if;
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  new.system_role := nullif(trim(new.system_role), '');
  new.approving_role := nullif(trim(new.approving_role), '');
  new.value := coalesce(new.value, 0);

  select r.name into v_dup
    from public.authorization_rule r
   where r.org_id = new.org_id and r.id <> new.id
     and r.transaction = new.transaction and r.based_on = new.based_on
     and r.system_user is not distinct from new.system_user
     and r.system_role is not distinct from new.system_role
     and r.approving_user is not distinct from new.approving_user
     and r.approving_role is not distinct from new.approving_role
   limit 1;
  if v_dup is not null then
    raise exception using errcode = 'P0001',
      message = format('duplicate: Duplicate Entry. Please check Authorization Rule %s', v_dup);
  end if;

  if new.approving_role is null and new.approving_user is null then
    raise exception using errcode = 'P0001', message = 'approver_required: Please enter Approving Role or Approving User';
  elsif new.system_user is not null and new.system_user = new.approving_user then
    raise exception using errcode = 'P0001',
      message = 'approving_user_same: Approving User cannot be same as user the rule is Applicable To';
  elsif new.system_role is not null and new.system_role = new.approving_role then
    raise exception using errcode = 'P0001',
      message = 'approving_role_same: Approving Role cannot be same as role the rule is Applicable To';
  end if;

  if new.system_user is not null
     and not exists (select 1 from public.org_members m where m.org_id = new.org_id and m.user_id = new.system_user) then
    raise exception using errcode = 'P0001', message = 'system_user_not_member: the user is not a member of this organization';
  end if;
  if new.approving_user is not null
     and not exists (select 1 from public.org_members m where m.org_id = new.org_id and m.user_id = new.approving_user) then
    raise exception using errcode = 'P0001', message = 'approving_user_not_member: the user is not a member of this organization';
  end if;
  return new;
end;
$$;

revoke execute on function app.authorization_rule_validate() from public, anon, authenticated;

drop trigger if exists authorization_rule_validate on public.authorization_rule;
create trigger authorization_rule_validate
  before insert or update on public.authorization_rule
  for each row execute function app.authorization_rule_validate();

drop trigger if exists touch_updated on public.authorization_rule;
create trigger touch_updated
  before update on public.authorization_rule
  for each row execute function app.touch_updated();

alter table public.authorization_rule enable row level security;
alter table public.authorization_rule force row level security;

drop policy if exists authorization_rule_select on public.authorization_rule;
create policy authorization_rule_select on public.authorization_rule for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Authorization Rule', 'read'))::uuid[]));
drop policy if exists authorization_rule_insert on public.authorization_rule;
create policy authorization_rule_insert on public.authorization_rule for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Authorization Rule', 'create'))::uuid[]));
drop policy if exists authorization_rule_update on public.authorization_rule;
create policy authorization_rule_update on public.authorization_rule for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Authorization Rule', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Authorization Rule', 'write'))::uuid[]));
drop policy if exists authorization_rule_delete on public.authorization_rule;
create policy authorization_rule_delete on public.authorization_rule for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Authorization Rule', 'delete'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Enforcement (AuthorizationControl.validate_approving_authority, Grand Total only)
------------------------------------------------------------------------------------------------------------------------

-- validate_auth_rule + get_appr_user_role for one level. p_level: 1 = rules for the user, 2 = rules for one of the
-- user's roles, 0 = global rules. Company-specific rules are looked up first, then rules without a company.
create or replace function app.authorization_check_level(
  p_org uuid, p_doctype text, p_company uuid, p_total numeric, p_level int, p_user uuid, p_roles text[]
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_max numeric;
  v_roles text[];
  v_users uuid[];
  v_names text[];
  v_rules public.authorization_rule[];
begin
  -- Rules applying at this level (the `cond` of bifurcate_based_on_type).
  select coalesce(array_agg(r), '{}') into v_rules
    from public.authorization_rule r
   where r.org_id = p_org and r.transaction = p_doctype and r.based_on = 'Grand Total'
     and case p_level
           when 1 then r.system_user = p_user
           when 2 then r.system_role = any (p_roles)
           else r.system_user is null and r.system_role is null
         end;

  select max(r.value) into v_max from unnest(v_rules) r where r.value <= p_total and r.company_id = p_company;
  if v_max is null then
    select max(r.value) into v_max from unnest(v_rules) r where r.value <= p_total and r.company_id is null;
  end if;
  if v_max is null then
    return;
  end if;

  select array_agg(distinct r.approving_role) filter (where r.approving_role is not null),
         array_agg(distinct r.approving_user) filter (where r.approving_user is not null)
    into v_roles, v_users
    from unnest(v_rules) r
   where (r.value = v_max or r.value > p_total) and r.company_id = p_company;
  if v_roles is null and v_users is null then
    select array_agg(distinct r.approving_role) filter (where r.approving_role is not null),
           array_agg(distinct r.approving_user) filter (where r.approving_user is not null)
      into v_roles, v_users
      from unnest(v_rules) r
     where (r.value = v_max or r.value > p_total) and r.company_id is null;
  end if;

  if coalesce(v_roles && p_roles, false) or p_user = any (coalesce(v_users, '{}')) then
    return;
  end if;

  select coalesce(v_roles, '{}') || coalesce(array_agg(u.email::text order by u.email), '{}')
    into v_names
    from auth.users u where u.id = any (coalesce(v_users, '{}'));
  raise exception using errcode = 'P0001',
    message = format('not_authorized: Not authorized since Grand Total exceeds limits. Can be approved by %s',
      case when cardinality(v_names) > 1
        then array_to_string(v_names[1:cardinality(v_names) - 1], ', ') || ' or ' || v_names[cardinality(v_names)]
        else v_names[1] end);
end;
$$;

-- User rules first; when the user has none for the transaction, role rules; when none of the user's roles has any,
-- global rules. Nothing to check when the organization has no rule for the transaction.
create or replace function app.validate_approving_authority(
  p_doctype text, p_company uuid, p_total numeric, p_user uuid default auth.uid()
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_roles text[];
begin
  select c.org_id into v_org from public.companies c where c.id = p_company;
  if v_org is null or not exists (
    select 1 from public.authorization_rule r where r.org_id = v_org and r.transaction = p_doctype
  ) then
    return;
  end if;

  select coalesce(array_agg(r.name), '{}') into v_roles
    from public.org_members m
    join public.roles r on r.org_id = m.org_id and r.name = any (m.roles) and not r.disabled
   where m.org_id = v_org and m.user_id = p_user and m.status = 'active';

  if exists (
    select 1 from public.authorization_rule r
     where r.org_id = v_org and r.transaction = p_doctype and r.system_user = p_user
       and (r.company_id = p_company or r.company_id is null)
  ) then
    perform app.authorization_check_level(v_org, p_doctype, p_company, p_total, 1, p_user, v_roles);
  elsif exists (
    select 1 from public.authorization_rule r
     where r.org_id = v_org and r.transaction = p_doctype and r.system_role = any (v_roles)
       and (r.company_id = p_company or r.company_id is null)
  ) then
    perform app.authorization_check_level(v_org, p_doctype, p_company, p_total, 2, p_user, v_roles);
  else
    perform app.authorization_check_level(v_org, p_doctype, p_company, p_total, 0, p_user, v_roles);
  end if;
end;
$$;

revoke execute on function app.authorization_check_level(uuid, text, uuid, numeric, int, uuid, text[])
  from public, anon, authenticated;
revoke execute on function app.validate_approving_authority(text, uuid, numeric, uuid) from public, anon, authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (authorization_rule.json: System Manager rwcd)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Authorization Rule', 'authorization_rule', 'setup', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Authorization Rule', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
