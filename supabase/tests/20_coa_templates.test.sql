begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000020a1', 'coa-owner@test.local', 'authenticated', 'authenticated');

select is(
  (select ((select count(*) from public.coa_template), (select count(*) from public.coa_template_file))::text),
  '(41,73)', 'every vendored chart is loaded: 39 file charts + Standard and Standard with Numbers, 73 files'
);
select is(
  (select count(*)::int from public.coa_template_file where template = 'Syscohada - Plan Comptable'),
  18, 'per-country copies of one chart share its template'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000020a1","role":"authenticated"}', true);

select is(
  (select array_agg(name || case when is_default then '*' else '' end) from public.coa_templates_for_country('Germany')),
  array['SKR03 mit Kontonummern', 'SKR04 mit Kontonummern', 'Standard*', 'Standard with Numbers'],
  'several country charts: the charts, then the standard ones with Standard preselected'
);
select is(
  (select array_agg(name || case when is_default then '*' else '' end) from public.coa_templates_for_country('Philippines')),
  array['Philippines*', 'Standard', 'Standard with Numbers'],
  'a single country chart (file name starting with the code "ph") is preselected'
);
select is(
  (select array_agg(name || case when is_default then '*' else '' end) from public.coa_templates_for_country('Kenya')),
  array['Standard*', 'Standard with Numbers'], 'countries without a chart get the standard ones'
);
select is(
  (select array_agg(name order by name) from public.coa_templates_for_country('Senegal') where name like 'Syscohada%'),
  array['Syscohada - Plan Comptable', 'Syscohada - Plan Comptable avec code'], 'Syscohada countries get both Syscohada charts'
);

select is(
  (select (account, parent_account, is_group, root_type, depth)::text from public.coa_template_preview('Standard') where idx = 1),
  '("Application of Funds (Assets)",,t,Asset,0)', 'the preview starts with the first root account in chart order'
);
select is(
  (select (account, parent_account, is_group, account_type, root_type)::text from public.coa_template_preview('Standard') where account = 'Debtors'),
  '(Debtors,"Accounts Receivable",f,Receivable,Asset)', 'leaf accounts carry their parent, type and root type'
);
select ok(
  (select is_group from public.coa_template_preview('Standard') where account = 'Bank Accounts'),
  'an explicit is_group makes a childless account a group'
);
select is(
  (select (account, parent_account)::text from public.coa_template_preview('Standard with Numbers') where account like '% - Debtors'),
  '("1310 - Debtors","1300 - Accounts Receivable")', 'numbered charts show "<number> - <name>"'
);
select is(
  (select count(*)::int from public.coa_template_preview('SKR04 mit Kontonummern') where root_type is null), 0,
  'every account of a country chart has a root type'
);

select set_config('test.org', public.create_organization('{"name":"CoA Org","slug":"coa-org","country":"Germany","default_currency":"EUR"}') ->> 'id', true);
select throws_ok(
  $$insert into public.companies (org_id, company_name, abbr, chart_of_accounts) values (current_setting('test.org')::uuid, 'Bad Chart', 'BC', 'Nope')$$,
  'P0001', 'coa_unknown: Could not find Chart Of Accounts Template: Nope', 'a company needs a known chart template'
);
select lives_ok(
  $$insert into public.companies (org_id, company_name, abbr, chart_of_accounts) values (current_setting('test.org')::uuid, 'German Co', 'GC', 'SKR04 mit Kontonummern')$$,
  'a country chart can be chosen'
);
select throws_ok(
  $$insert into public.coa_template (name, tree) values ('Mine', '{}')$$,
  '42501', null, 'signed-in users cannot add chart templates'
);

select * from finish();
rollback;
