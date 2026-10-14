begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- The overlap check is deferred to commit; fire it at the end of each statement instead.
set constraints all immediate;

-- save_doc writes the header before the company rows; check the whole document once it is saved, as a commit would.
create function pg_temp.save_checked(p_doctype text, p jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  set constraints all deferred;
  r := public.save_doc(p_doctype, p);
  set constraints all immediate;
  return r;
end $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000019a1', 'fy-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000019a2', 'fy-stock-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000019a3', 'fy-mfg-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000019b1', 'fy-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000019b1","role":"authenticated"}', true);
select set_config('test.org_b', public.create_organization('{"name":"FY Org B","slug":"fy-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.fiscal_year (org_id, year, year_start_date, year_end_date)
  values (current_setting('test.org_b')::uuid, 'Ending', (current_date + 2 - interval '1 year' + interval '1 day')::date, current_date + 2);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000019a1","role":"authenticated"}', true);
select set_config('test.org', public.create_organization('{"name":"FY Org A","slug":"fy-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000019a2', '{Stock User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000019a3', '{Manufacturing User}');
insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000019c1', current_setting('test.org')::uuid, 'FY One', 'FY1'),
  ('00000000-0000-0000-0000-0000000019c2', current_setting('test.org')::uuid, 'FY Two', 'FY2');

select throws_ok(
  $$insert into public.fiscal_year (org_id, year, year_start_date, year_end_date) values (current_setting('test.org')::uuid, 'Back', '2026-12-31', '2026-01-01')$$,
  'P0001', 'fiscal_year_dates: Year End Date must be after Year Start Date', 'the end date cannot be before the start date'
);
select throws_ok(
  $$insert into public.fiscal_year (org_id, year, year_start_date, year_end_date) values (current_setting('test.org')::uuid, 'Short', '2025-07-01', '2025-12-31')$$,
  'P0001', 'fiscal_year_dates: Fiscal Year End Date should be one year after Fiscal Year Start Date', 'a fiscal year lasts one year'
);
select lives_ok(
  $$insert into public.fiscal_year (org_id, year, year_start_date, year_end_date, is_short_year) values (current_setting('test.org')::uuid, 'Short 2025', '2025-07-01', '2025-12-31', true)$$,
  'short years may end early'
);

select set_config('test.fy', (public.save_doc('Fiscal Year', jsonb_build_object(
  'org_id', current_setting('test.org'), 'year', ' ', 'year_start_date', '2026-01-01', 'year_end_date', '2026-12-31'
))) ->> 'id', true);
select is((select year from public.fiscal_year where id = current_setting('test.fy')::uuid), '2026', 'an empty year is named from the dates');
select is(app.fiscal_year_name('2026-04-01', '2027-03-31'), '2026-2027', 'a year spanning two calendar years is named "start-end"');

select throws_ok(
  $$insert into public.fiscal_year (org_id, year, year_start_date, year_end_date) values (current_setting('test.org')::uuid, 'Mid', '2026-07-01', '2027-06-30')$$,
  'P0001', 'fiscal_year_overlap: Year start date or end date is overlapping with 2026. To avoid please set company',
  'years without companies cannot overlap'
);
select lives_ok(
  $$select pg_temp.save_checked('Fiscal Year', jsonb_build_object('org_id', current_setting('test.org'), 'year', 'FY1 2026', 'year_start_date', '2026-07-01', 'year_end_date', '2027-06-30', 'companies', jsonb_build_array(jsonb_build_object('company_id', '00000000-0000-0000-0000-0000000019c1'))))$$,
  'a year for a company may overlap the general one'
);
select throws_ok(
  $$select pg_temp.save_checked('Fiscal Year', jsonb_build_object('org_id', current_setting('test.org'), 'year', 'FY1 again', 'year_start_date', '2026-10-01', 'year_end_date', '2027-09-30', 'companies', jsonb_build_array(jsonb_build_object('company_id', '00000000-0000-0000-0000-0000000019c1'))))$$,
  'P0001', 'fiscal_year_overlap: Year start date or end date is overlapping with FY1 2026. To avoid please set company',
  'years sharing a company cannot overlap'
);
select lives_ok(
  $$select pg_temp.save_checked('Fiscal Year', jsonb_build_object('org_id', current_setting('test.org'), 'year', 'FY2 2026', 'year_start_date', '2026-10-01', 'year_end_date', '2027-09-30', 'companies', jsonb_build_array(jsonb_build_object('company_id', '00000000-0000-0000-0000-0000000019c2'))))$$,
  'years of different companies may overlap'
);
select throws_ok(
  $$insert into public.fiscal_year (org_id, year, year_start_date, year_end_date) values (current_setting('test.org')::uuid, ' fy1 2026', '2030-01-01', '2030-12-31')$$,
  '23505', null, 'year names are unique per organization (case-insensitive, trimmed)'
);
select is((select count(*)::int from public.fiscal_year where year = 'Ending'), 0, 'fiscal years of another organization are invisible');
select throws_ok($$select app.auto_create_fiscal_year()$$, '42501', null, 'members cannot run the auto-create job');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000019a2","role":"authenticated"}', true);
select is((select count(*)::int from public.fiscal_year), 4, 'Stock User reads fiscal years');
select throws_ok(
  $$insert into public.fiscal_year (org_id, year, year_start_date, year_end_date) values (current_setting('test.org')::uuid, '2031', '2031-01-01', '2031-12-31')$$,
  '42501', null, 'Stock User cannot add fiscal years'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000019a3","role":"authenticated"}', true);
select is((select count(*)::int from public.fiscal_year), 0, 'roles without a rule see no fiscal years');

reset role;
do $$ begin perform app.auto_create_fiscal_year(); end $$;
select is(
  (select (year, year_start_date = current_date + 3, year_end_date = (current_date + 3 + interval '1 year' - interval '1 day')::date, auto_created)::text
     from public.fiscal_year where org_id = current_setting('test.org_b')::uuid and year <> 'Ending'),
  (select (app.fiscal_year_name(current_date + 3, (current_date + 3 + interval '1 year' - interval '1 day')::date), true, true, true)::text),
  'the next fiscal year is created when the current one ends within 3 days'
);
do $$ begin perform app.auto_create_fiscal_year(); end $$;
select is((select count(*)::int from public.fiscal_year where org_id = current_setting('test.org_b')::uuid), 2, 'it is created only once');

select * from finish();
rollback;
