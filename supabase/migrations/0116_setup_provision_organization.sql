-- 0116 setup: onboarding provisioning (docs/modules/00-setup.md §3.1, §3.3).
-- ERPNext: setup/setup_wizard/setup_wizard.py (stages), operations/install_fixtures.py (install_company,
-- install_defaults, set_global_defaults, get_fy_details), operations/company_setup.py.
--
-- app.provision_organization(p) runs the wizard's three stages in one transaction:
--   A "Setting up the basics": organization, owner, roles + permissions, single-doctype settings, designations and the
--     department root (A1-A4, A18; the last three via the organizations insert triggers).
--   B "Creating your company": fiscal year (B1), company through app.create_company (B2; departments B8 and the
--     org currency B11 via the companies insert triggers).
--   C "Applying recommended settings": global defaults (C3), invitations (C5), provisioned_at (C6).
-- Staged provisioning: steps whose tables arrive later (accounts, cost centers, warehouses, tax templates, modes of
-- payment, price lists, UOMs, module settings) are added by those migrations.

------------------------------------------------------------------------------------------------------------------------
-- Stage A: app.create_organization also stores the organization language (A1).
------------------------------------------------------------------------------------------------------------------------

create or replace function app.create_organization(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_slug text := lower(trim(p ->> 'slug'));
  v_name text := trim(p ->> 'name');
  v_org public.organizations;
begin
  if v_uid is null then
    raise exception using errcode = 'P0001', message = 'not_authenticated: sign in to create an organization';
  end if;
  if v_name is null or v_name = '' then
    raise exception using errcode = 'P0001', message = 'name_required: Organization name is required';
  end if;
  if v_slug is null or v_slug !~ '^[a-z0-9-]{3,40}$' then
    raise exception using errcode = 'P0001', message = 'invalid_slug: use 3-40 lowercase letters, digits or dashes';
  end if;
  if v_slug = any (app.reserved_slugs()) then
    raise exception using errcode = 'P0001', message = 'slug_reserved: this URL is reserved; choose another';
  end if;
  if exists (select 1 from public.organizations where slug = v_slug) then
    raise exception using errcode = 'P0001', message = 'slug_taken: this URL is already in use';
  end if;

  insert into public.organizations (slug, name, country, default_currency, time_zone, language, created_by)
  values (
    v_slug,
    v_name,
    nullif(trim(p ->> 'country'), ''),
    nullif(upper(trim(p ->> 'default_currency')), ''),
    coalesce(nullif(trim(p ->> 'time_zone'), ''), 'UTC'),
    coalesce(nullif(trim(p ->> 'language'), ''), 'en'),
    v_uid
  )
  returning * into v_org;

  perform app.sync_role_permissions(v_org.id);

  insert into public.org_members (org_id, user_id, roles, is_owner, status)
  values (v_org.id, v_uid, '{System Manager}', true, 'active');

  return jsonb_build_object('id', v_org.id, 'slug', v_org.slug);
end;
$$;

revoke execute on function app.create_organization(jsonb) from public, anon, authenticated;
grant execute on function app.create_organization(jsonb) to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Company abbreviation default: setup_wizard.js / company.js take the first letter of each word, upper-cased, max 10.
------------------------------------------------------------------------------------------------------------------------

create or replace function app.company_abbr(p_company_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select left(upper(string_agg(left(w, 1), '' order by n)), 10)
  from regexp_split_to_table(trim(coalesce(p_company_name, '')), '\s+') with ordinality as t(w, n)
  where w <> '';
$$;

revoke execute on function app.company_abbr(text) from public, anon;
grant execute on function app.company_abbr(text) to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- Stage B: app.create_company (also the create path of the Company form, §3.3).
------------------------------------------------------------------------------------------------------------------------

-- Inserts a new company through the generic save path (RLS authorizes the caller). Company.on_update side effects
-- that need P2 tables (chart of accounts B3, default accounts B4/B9, warehouses B5, cost centers B6, tax templates
-- B7, mode of payment accounts B10, bank account B13) are added here by the migrations that create those tables.
create or replace function app.create_company(p jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception using errcode = 'P0001', message = 'invalid_payload: expected an object';
  end if;
  return app.save_doc('Company', p - 'id');
end;
$$;

revoke execute on function app.create_company(jsonb) from public, anon;
grant execute on function app.create_company(jsonb) to authenticated;

create or replace function public.create_company(p jsonb)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.create_company(p);
$$;

revoke execute on function public.create_company(jsonb) from public, anon;
grant execute on function public.create_company(jsonb) to authenticated;

------------------------------------------------------------------------------------------------------------------------
-- app.provision_organization
------------------------------------------------------------------------------------------------------------------------

-- p = { org: {name, slug, country, default_currency, time_zone, language},
--       company: {company_name, abbr, chart_of_accounts, fy_start_date, fy_end_date, domain},
--       invites: [{email, roles[], role_profile}] }
-- Re-running for an organization the caller owns that is already provisioned returns it unchanged.
create or replace function app.provision_organization(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org_in jsonb := coalesce(p -> 'org', '{}');
  v_co_in jsonb := coalesce(p -> 'company', '{}');
  v_org public.organizations;
  v_org_id uuid;
  v_company_name text := trim(v_co_in ->> 'company_name');
  v_fy_start date := nullif(v_co_in ->> 'fy_start_date', '')::date;
  v_fy_end date := nullif(v_co_in ->> 'fy_end_date', '')::date;
  v_company jsonb;
  v_invite jsonb;
begin
  if v_uid is null then
    raise exception using errcode = 'P0001', message = 'not_authenticated: sign in to create an organization';
  end if;

  select * into v_org from public.organizations where slug = lower(trim(v_org_in ->> 'slug'));
  if found and v_org.provisioned_at is not null and exists (
    select 1 from public.org_members m where m.org_id = v_org.id and m.user_id = v_uid and m.is_owner
  ) then
    return jsonb_build_object(
      'id', v_org.id, 'slug', v_org.slug,
      'company_id', (select g.default_company_id from public.global_defaults g where g.org_id = v_org.id)
    );
  end if;

  if v_company_name is null or v_company_name = '' then
    raise exception using errcode = 'P0001', message = 'company_name_required: Company Name is required';
  end if;
  if jsonb_typeof(coalesce(p -> 'invites', '[]')) <> 'array' then
    raise exception using errcode = 'P0001', message = 'invalid_invites: invites must be a list';
  end if;

  -- Stage A: Setting up the basics
  v_org_id := (app.create_organization(v_org_in) ->> 'id')::uuid;
  select * into v_org from public.organizations where id = v_org_id;

  -- Stage B: Creating your company (install_company: the Fiscal Year first, then the Company)
  if v_fy_start is not null then
    v_fy_end := coalesce(v_fy_end, (v_fy_start + interval '1 year' - interval '1 day')::date);
    insert into public.fiscal_year (org_id, year, year_start_date, year_end_date)
    values (v_org.id, app.fiscal_year_name(v_fy_start, v_fy_end), v_fy_start, v_fy_end);
  end if;

  v_company := app.create_company(jsonb_build_object(
    'org_id', v_org.id,
    'company_name', v_company_name,
    'abbr', coalesce(nullif(trim(v_co_in ->> 'abbr'), ''), app.company_abbr(v_company_name)),
    'default_currency', coalesce(nullif(upper(trim(v_co_in ->> 'default_currency')), ''), v_org.default_currency),
    'country', coalesce(nullif(trim(v_co_in ->> 'country'), ''), v_org.country),
    'enable_perpetual_inventory', true,
    'create_chart_of_accounts_based_on', 'Standard Template',
    'chart_of_accounts', coalesce(nullif(trim(v_co_in ->> 'chart_of_accounts'), ''), 'Standard'),
    'domain', nullif(trim(v_co_in ->> 'domain'), '')
  ));

  -- Stage C: Applying recommended settings (set_global_defaults)
  update public.global_defaults
     set default_company_id = (v_company ->> 'id')::uuid,
         default_currency = coalesce(v_org.default_currency, default_currency),
         country = coalesce(v_org.country, country)
   where org_id = v_org.id;

  for v_invite in select e from jsonb_array_elements(coalesce(p -> 'invites', '[]')) e loop
    perform app.create_invitation(
      v_org.id,
      v_invite ->> 'email',
      array(select jsonb_array_elements_text(coalesce(v_invite -> 'roles', '[]'))),
      coalesce(v_invite ->> 'role_profile', '')
    );
  end loop;

  update public.organizations set provisioned_at = now() where id = v_org.id;

  return jsonb_build_object('id', v_org.id, 'slug', v_org.slug, 'company_id', v_company ->> 'id');
end;
$$;

revoke execute on function app.provision_organization(jsonb) from public, anon;
grant execute on function app.provision_organization(jsonb) to authenticated;

create or replace function public.provision_organization(p jsonb)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.provision_organization(p);
$$;

revoke execute on function public.provision_organization(jsonb) from public, anon;
grant execute on function public.provision_organization(jsonb) to authenticated;

-- Organizations created through the P0 form were set up by hand; count them as provisioned.
update public.organizations set provisioned_at = created_at where provisioned_at is null;
