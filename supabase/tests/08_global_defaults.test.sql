begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a2', 'sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'owner-b@test.local', 'authenticated', 'authenticated');

insert into public.organizations (id, slug, name, country, default_currency) values
  ('10000000-0000-0000-0000-00000000000a', 'org-a', 'Org A', 'United States', 'USD'),
  ('10000000-0000-0000-0000-00000000000b', 'org-b', 'Org B', 'Netherlands', 'EUR');

do $$ begin perform app.sync_role_permissions(); end $$;

insert into public.org_members (org_id, user_id, roles, is_owner) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', '{}', true),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', '{Sales User}', false),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', '{}', true);

select results_eq(
  $$select country, default_currency, default_company_id, use_posting_datetime_for_naming_documents
      from public.global_defaults where org_id = '10000000-0000-0000-0000-00000000000a'$$,
  $$values ('United States'::text, 'USD'::text, null::uuid, true)$$,
  'a new organization gets its Global Defaults row from the org country and currency'
);

select ok(
  (select is_single from public.doctype_meta where doctype = 'Global Defaults'),
  'Global Defaults is registered as a single doctype'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

insert into public.companies (id, org_id, company_name) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', 'Acme');
insert into public.companies (id, org_id, company_name) values
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-00000000000a', 'Beta');

select is(
  (select default_company_id from public.global_defaults where org_id = '10000000-0000-0000-0000-00000000000a'),
  '20000000-0000-0000-0000-000000000001'::uuid,
  'the first company becomes the default company'
);

update public.global_defaults set default_currency = 'GBP', hide_currency_symbol = true
where org_id = '10000000-0000-0000-0000-00000000000a';

select ok(
  exists (select 1 from public.org_currency
          where org_id = '10000000-0000-0000-0000-00000000000a' and code = 'GBP' and enabled),
  'changing the default currency enables it for the org'
);

select throws_ok(
  $$update public.global_defaults set country = 'Atlantis' where org_id = '10000000-0000-0000-0000-00000000000a'$$,
  'P0001', 'country_unknown: Could not find Country: Atlantis',
  'unknown countries are rejected with a link error'
);

select is(
  (select count(*)::int from public.global_defaults),
  1,
  'members only see their own org row'
);

select throws_ok(
  $$insert into public.global_defaults (org_id) values ('10000000-0000-0000-0000-00000000000a')$$,
  '42501', null,
  'rows cannot be inserted through the API'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);

update public.global_defaults set disable_in_words = true where org_id = '10000000-0000-0000-0000-00000000000a';

select is(
  (select disable_in_words from public.global_defaults where org_id = '10000000-0000-0000-0000-00000000000a'),
  false,
  'non System Managers can read but not edit Global Defaults'
);

reset role;
select throws_ok(
  $$update public.global_defaults set default_company_id = '20000000-0000-0000-0000-000000000001'
      where org_id = '10000000-0000-0000-0000-00000000000b'$$,
  'P0001', 'company_unknown: Could not find Company',
  'the default company must belong to the same org'
);

select * from finish();
rollback;
