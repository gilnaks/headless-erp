begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000004a1', 'naming-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000004a2', 'naming-sales@test.local', 'authenticated', 'authenticated');

insert into public.organizations (id, slug, name, country, default_currency) values
  ('10000000-0000-0000-0000-0000000004aa', 'naming-a', 'Naming A', 'United States', 'USD'),
  ('10000000-0000-0000-0000-0000000004bb', 'naming-b', 'Naming B', 'United States', 'USD');

do $$ begin perform app.sync_role_permissions(); end $$;

insert into public.org_members (org_id, user_id, roles, is_owner) values
  ('10000000-0000-0000-0000-0000000004aa', '00000000-0000-0000-0000-0000000004a1', '{}', true),
  ('10000000-0000-0000-0000-0000000004aa', '00000000-0000-0000-0000-0000000004a2', '{Sales User}', false);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000004a1', '10000000-0000-0000-0000-0000000004aa', 'Naming Co', 'NC');

select is(
  app.next_name('10000000-0000-0000-0000-0000000004aa', null, 'ACC-SINV-.YYYY.-', '2026-03-15'),
  'ACC-SINV-2026-00001',
  'template without # gets a 5-digit counter after the resolved prefix'
);

select is(
  app.next_name('10000000-0000-0000-0000-0000000004aa', null, 'ACC-SINV-.YYYY.-', '2026-12-31'),
  'ACC-SINV-2026-00002',
  'same prefix increments'
);

select is(
  app.next_name('10000000-0000-0000-0000-0000000004aa', null, 'ACC-SINV-.YYYY.-', '2027-01-01'),
  'ACC-SINV-2027-00001',
  'a new year starts a new counter'
);

select is(
  app.next_name('10000000-0000-0000-0000-0000000004bb', null, 'ACC-SINV-.YYYY.-', '2026-03-15'),
  'ACC-SINV-2026-00001',
  'counters are separate per organization'
);

select is(
  app.next_name('10000000-0000-0000-0000-0000000004aa', null, 'PO-.YY.-.MM.-.DD.-.###', '2026-03-05'),
  'PO-26-03-05-001',
  'YY/MM/DD tokens and explicit digit width'
);

select is(
  app.next_name('10000000-0000-0000-0000-0000000004aa', '20000000-0000-0000-0000-0000000004a1', 'JV-.ABBR.-.####', '2026-03-05'),
  'JV-NC-0001',
  'ABBR resolves the company abbreviation'
);

select throws_ok(
  $$select app.next_name('10000000-0000-0000-0000-0000000004aa', null, 'JV-.ABBR.-.####', '2026-03-05')$$,
  'P0001', 'naming_company_required: Company is required for series with .ABBR.',
  'ABBR without a company is rejected'
);

update public.naming_series set current = 99
 where org_id = '10000000-0000-0000-0000-0000000004aa' and prefix = 'PO-26-03-05-';
select is(
  app.next_name('10000000-0000-0000-0000-0000000004aa', null, 'PO-.YY.-.MM.-.DD.-.###', '2026-03-05'),
  'PO-26-03-05-100',
  'counter continues from an adjusted value and grows past the pad width'
);

-- Permissions
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000004a2","role":"authenticated"}', true);

select is(
  (select count(*)::int from public.naming_series where org_id = '10000000-0000-0000-0000-0000000004aa'),
  4,
  'members can read their organization''s counters'
);

update public.naming_series set current = 0 where org_id = '10000000-0000-0000-0000-0000000004aa';
select is(
  (select max(current)::int from public.naming_series where org_id = '10000000-0000-0000-0000-0000000004aa'),
  100,
  'non System Managers cannot reset counters'
);

reset role;
select ok(
  not has_function_privilege('authenticated', 'app.next_name(uuid, uuid, text, date)', 'execute'),
  'next_name is not callable through the API'
);

select * from finish();
rollback;
