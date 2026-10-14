-- 0005 framework: minimal organization creation (first slice of provisioning Stage A, docs/modules/00-setup.md §3.1:
-- A1 organization, A2 owner membership, A3 standard roles + default permissions). P1 extends this into
-- app.provision_organization() (company, chart of accounts, fixtures).

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
  if exists (select 1 from public.organizations where slug = v_slug) then
    raise exception using errcode = 'P0001', message = 'slug_taken: this URL is already in use';
  end if;

  insert into public.organizations (slug, name, country, default_currency, time_zone, created_by)
  values (
    v_slug,
    v_name,
    nullif(trim(p ->> 'country'), ''),
    nullif(upper(trim(p ->> 'default_currency')), ''),
    coalesce(nullif(trim(p ->> 'time_zone'), ''), 'UTC'),
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

create or replace function public.create_organization(p jsonb)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.create_organization(p);
$$;

revoke execute on function public.create_organization(jsonb) from public, anon;
grant execute on function public.create_organization(jsonb) to authenticated;
