begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000021f1', 'founder21@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000021f2', 'other21@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000021f1","role":"authenticated"}', true);

select is(
  public.provision_organization('{
    "org": {"name": " Acme Holdings ", "slug": "Acme-21", "country": "Netherlands", "default_currency": "eur",
            "time_zone": "Europe/Amsterdam", "language": "nl"},
    "company": {"company_name": "Acme Trading Europe", "fy_start_date": "2026-04-01", "fy_end_date": "2027-03-31"},
    "invites": [{"email": "Clerk21@Test.local", "roles": [], "role_profile": "Accounts"}]
  }') ->> 'slug',
  'acme-21',
  'provisions the organization and returns its slug'
);

select results_eq(
  $$select name, country, default_currency, time_zone, language, provisioned_at is not null
    from public.organizations where slug = 'acme-21'$$,
  $$values ('Acme Holdings', 'Netherlands', 'EUR', 'Europe/Amsterdam', 'nl', true)$$,
  'A1: organization fields are stored and provisioned_at is set'
);

select results_eq(
  $$select roles, is_owner from public.org_members m join public.organizations o on o.id = m.org_id where o.slug = 'acme-21'$$,
  $$values ('{System Manager}'::text[], true)$$,
  'A2: caller becomes the owner with System Manager'
);

select ok(
  (select count(*) from public.roles r join public.organizations o on o.id = r.org_id where o.slug = 'acme-21')
    = (select count(*) from public.role_template)
  and (select count(*) from public.role_profile r join public.organizations o on o.id = r.org_id where o.slug = 'acme-21') = 5,
  'A3: standard roles and role profiles are seeded'
);

select ok(
  exists (select 1 from public.system_settings s join public.organizations o on o.id = s.org_id where o.slug = 'acme-21')
  and (select count(*) from public.designation d join public.organizations o on o.id = d.org_id where o.slug = 'acme-21') = 31,
  'A4/A18: system settings and the 31 designations are seeded'
);

select ok(
  exists (
    select 1 from public.print_settings p join public.organizations o on o.id = p.org_id
     where o.slug = 'acme-21' and p.print_style = 'Modern' and p.font_size = 9 and p.pdf_page_size = 'A4'
       and p.with_letterhead and p.compact_item_print and not p.allow_print_for_cancelled
  ),
  'A4: print settings are seeded with the Frappe/ERPNext defaults'
);

select is(
  (select count(*)::int from public.print_format p join public.organizations o on o.id = p.org_id
    where o.slug = 'acme-21' and p.is_standard and p.is_default and p.template_key = 'record'),
  (select count(*)::int from public.doctype_meta m where app.is_printable(m.doctype)),
  'A4: a default "<Doctype> Standard" print format is seeded per printable doctype'
);

select results_eq(
  $$select year, year_start_date, year_end_date, disabled
    from public.fiscal_year f join public.organizations o on o.id = f.org_id where o.slug = 'acme-21'$$,
  $$values ('2026-2027', '2026-04-01'::date, '2027-03-31'::date, false)$$,
  'B1: fiscal year from the wizard dates, named like get_fy_details'
);

select is(
  (select count(*) from public.fiscal_year_company c join public.fiscal_year f on f.id = c.parent_id
   join public.organizations o on o.id = f.org_id where o.slug = 'acme-21'),
  0::bigint,
  'B1: the fiscal year applies to all companies'
);

select results_eq(
  $$select c.company_name, c.abbr, c.default_currency, c.country, c.enable_perpetual_inventory,
           c.create_chart_of_accounts_based_on, c.chart_of_accounts
    from public.companies c join public.organizations o on o.id = c.org_id where o.slug = 'acme-21'$$,
  $$values ('Acme Trading Europe', 'ATE', 'EUR', 'Netherlands', true, 'Standard Template', 'Standard')$$,
  'B2: company with initials abbreviation, org currency and country, Standard chart'
);

select is(
  (select count(*) from public.department d join public.companies c on c.id = d.company_id
   join public.organizations o on o.id = c.org_id where o.slug = 'acme-21'),
  13::bigint,
  'B8: 13 departments for the company'
);

select ok(
  exists (select 1 from public.org_currency oc join public.organizations o on o.id = oc.org_id
          where o.slug = 'acme-21' and oc.code = 'EUR' and oc.enabled),
  'B11: the company currency is enabled'
);

select results_eq(
  $$select g.default_company_id = c.id, g.default_currency, g.country
    from public.global_defaults g join public.organizations o on o.id = g.org_id
    join public.companies c on c.org_id = o.id where o.slug = 'acme-21'$$,
  $$values (true, 'EUR', 'Netherlands')$$,
  'C3: global defaults point at the new company'
);

select results_eq(
  $$select i.email, i.roles from public.invitations i join public.organizations o on o.id = i.org_id where o.slug = 'acme-21'$$,
  $$values ('clerk21@test.local', '{Accounts Manager,Accounts User}'::text[])$$,
  'C5: invitations are created with the role profile''s roles'
);

select is(
  public.provision_organization('{"org": {"name": "Acme Again", "slug": "acme-21"}, "company": {"company_name": "Other"}}') ->> 'id',
  (select id::text from public.organizations where slug = 'acme-21'),
  'a re-run by the owner returns the provisioned organization'
);

select ok(
  (select count(*) from public.companies c join public.organizations o on o.id = c.org_id where o.slug = 'acme-21') = 1
  and (select name from public.organizations where slug = 'acme-21') = 'Acme Holdings',
  'a re-run changes nothing'
);

select is(
  app.company_abbr('  wayne   enterprises inc '),
  'WEI',
  'abbreviation default takes the first letter of each word'
);

select ok(
  app.has_perm((select id from public.organizations where slug = 'acme-21'), 'Company', 'create'),
  'A3: default permissions are seeded (the owner can create companies)'
);

select throws_ok(
  $$select public.provision_organization('{"org": {"name": "Bad", "slug": "a b"}, "company": {"company_name": "Bad"}}')$$,
  'P0001', 'invalid_slug: use 3-40 lowercase letters, digits or dashes', 'the slug format is validated'
);

select throws_ok(
  $$select public.provision_organization('{"org": {"name": "Sneaky", "slug": "login"}, "company": {"company_name": "Sneaky"}}')$$,
  'P0001', 'slug_reserved: this URL is reserved; choose another', 'top-level route names are reserved'
);

select throws_ok(
  $$select public.provision_organization('{"org": {"name": "No Company", "slug": "no-company-21"}, "company": {}}')$$,
  'P0001', 'company_name_required: Company Name is required', 'company name is required'
);

select throws_ok(
  $$select public.provision_organization('{"org": {"name": "Bad Chart", "slug": "bad-chart-21", "country": "Netherlands", "default_currency": "EUR"},
    "company": {"company_name": "Bad Chart", "chart_of_accounts": "Nope"}}')$$,
  'P0001', 'coa_unknown: Could not find Chart Of Accounts Template: Nope', 'unknown charts are rejected'
);

select throws_ok(
  $$select public.provision_organization('{"org": {"name": "Rollback", "slug": "rollback-21", "country": "Netherlands", "default_currency": "EUR"},
    "company": {"company_name": "Rollback"}, "invites": [{"email": "x@test.local", "roles": []}]}')$$,
  'P0001', null, 'an invalid invite fails provisioning'
);

select is(
  (select count(*) from public.organizations where slug in ('rollback-21', 'bad-chart-21', 'no-company-21')),
  0::bigint,
  'a failed provisioning leaves nothing behind'
);

select results_eq(
  $$select public.create_company(jsonb_build_object(
      'org_id', (select id from public.organizations where slug = 'acme-21'),
      'company_name', 'Acme Retail', 'abbr', 'AR', 'default_currency', 'EUR', 'country', 'Netherlands')) ->> 'name',
    (select g.default_company_id = c.id from public.global_defaults g join public.companies c on c.id = g.default_company_id
     join public.organizations o on o.id = g.org_id where o.slug = 'acme-21')::text$$,
  $$values ('Acme Retail', 'true')$$,
  'create_company returns the name and keeps the default company'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000021f2","role":"authenticated"}', true);
select throws_ok(
  $$select public.provision_organization('{"org": {"name": "Hijack", "slug": "acme-21"}, "company": {"company_name": "Hijack"}}')$$,
  'P0001', 'slug_taken: this URL is already in use', 'another user cannot reuse a provisioned slug'
);

reset role;
select ok(
  not has_function_privilege('anon', 'public.provision_organization(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.create_company(jsonb)', 'execute'),
  'anon cannot provision organizations or create companies'
);

select hasnt_function('public', 'create_organization', array['jsonb'], 'the P0 create_organization RPC is gone');

select * from finish();
rollback;
