begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Counts printed by scripts/gen-reference-data.mjs (Frappe country_info.json, ERPNext uom_data/uom_conversion_data).
select results_eq(
  $$select (select count(*) from public.country), (select count(*) from public.currency),
           (select count(*) from public.uom_template), (select count(*) from public.uom_conversion_template)$$,
  $$values (250::bigint, 144::bigint, 239::bigint, 235::bigint)$$,
  'reference tables hold every source row'
);

select results_eq(
  $$select code, currency_name, symbol, fraction, fraction_units, number_format from public.currency where code in ('USD', 'JPY') order by code$$,
  $$values ('JPY', 'Japanese Yen', '¥', null::text, 0, '#,###'), ('USD', 'US Dollar', '$', 'Cent', 100, '#,###.##')$$,
  'currencies carry Frappe fraction, symbol and number format with an English name'
);

select results_eq(
  $$select code, date_format, time_format, time_zones from public.country where country_name = 'Philippines'$$,
  $$values ('ph', 'mm-dd-yyyy', 'HH:mm:ss', '{Asia/Manila}'::text[])$$,
  'countries carry code, formats (Frappe defaults) and time zones'
);

select results_eq(
  $$select must_be_whole_number, category from public.uom_template where uom_name = 'Nos'$$,
  $$values (true, null::text)$$,
  'UOM templates keep ERPNext flags'
);

------------------------------------------------------------------------------------------------------------------------
-- Access
------------------------------------------------------------------------------------------------------------------------
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000006a1', 'ref-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000006b1', 'ref-b@test.local', 'authenticated', 'authenticated');

set local role anon;
select is((select count(*) from public.currency), 0::bigint, 'anon reads no reference data');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000006a1","role":"authenticated"}', true);

select ok((select count(*) from public.country) = 250, 'signed-in users read reference data');
select throws_ok(
  $$insert into public.currency (code, currency_name) values ('XXX', 'Fake')$$,
  '42501', null, 'signed-in users cannot add reference rows'
);
select throws_ok(
  $$update public.country set code = 'xx' where country_name = 'Philippines'$$,
  '42501', null, 'signed-in users cannot change reference rows'
);

------------------------------------------------------------------------------------------------------------------------
-- Link validation + enabled currencies
------------------------------------------------------------------------------------------------------------------------
select throws_ok(
  $$select app.create_organization('{"name":"Bad Country","slug":"ref-bad-country","country":"Atlantis","default_currency":"USD"}')$$,
  'P0001', 'country_unknown: Could not find Country: Atlantis', 'unknown country is rejected'
);
select throws_ok(
  $$select app.create_organization('{"name":"Bad Currency","slug":"ref-bad-currency","country":"Philippines","default_currency":"XYZ"}')$$,
  'P0001', 'currency_unknown: Could not find Currency: XYZ', 'unknown currency is rejected'
);

select lives_ok(
  $$select app.create_organization('{"name":"Ref A","slug":"ref-a","country":"Philippines","default_currency":"PHP"}')$$,
  'valid country and currency are accepted'
);

select results_eq(
  $$select c.code, c.enabled from public.org_currency c join public.organizations o on o.id = c.org_id where o.slug = 'ref-a'$$,
  $$values ('PHP', true)$$,
  'the organization currency is enabled'
);

select throws_ok(
  $$insert into public.companies (org_id, company_name, abbr, default_currency)
    select id, 'Ref Co', 'RC', 'ABC' from public.organizations where slug = 'ref-a'$$,
  'P0001', 'currency_unknown: Could not find Currency: ABC', 'companies validate their currency'
);

insert into public.companies (org_id, company_name, abbr, default_currency)
  select id, 'Ref US', 'RUS', 'USD' from public.organizations where slug = 'ref-a';

select results_eq(
  $$select c.code from public.org_currency c join public.organizations o on o.id = c.org_id where o.slug = 'ref-a' order by c.code$$,
  $$values ('PHP'), ('USD')$$,
  'a company currency is enabled for the organization'
);

select is(
  (select country from public.companies where company_name = 'Ref US'),
  'Philippines',
  'company country defaults from the organization and passes validation'
);

select set_config('test.ref_a', (select id::text from public.organizations where slug = 'ref-a'), true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000006b1","role":"authenticated"}', true);
select is(
  (select count(*) from public.org_currency where org_id = current_setting('test.ref_a')::uuid),
  0::bigint,
  'enabled currencies are invisible to other organizations'
);

select * from finish();
rollback;
