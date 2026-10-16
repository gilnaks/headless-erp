begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000049a1', 'party-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000049a2', 'party-accounts-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000049b1', 'party-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000049b1","role":"authenticated"}', true);
select set_config(
  'test.org_b',
  app.create_organization('{"name":"Party Org B","slug":"party-org-b","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000049a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Party Org A","slug":"party-org-a","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles)
values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000049a2', '{Accounts User}');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000049a1","role":"authenticated"}', true);

select is(
  (select account_type from public.party_type where name = 'Customer'),
  'Receivable',
  'a new organization gets Customer as Receivable'
);
select is(
  (select account_type from public.party_type where name = 'Supplier'),
  'Payable',
  'a new organization gets Supplier as Payable'
);
select ok(
  not exists (select 1 from public.party_type where name in ('Employee', 'Shareholder')),
  'Employee and Shareholder are not seeded'
);
select is(
  (select name from public.print_heading where print_heading = 'Credit Note'),
  'Credit Note',
  'Credit Note is named from the heading'
);
select ok(
  exists (select 1 from public.print_heading where name = 'Debit Note' and print_heading = 'Debit Note'),
  'Debit Note is seeded'
);
select is((select count(*)::int from public.party_type), 2, 'the other organization stays invisible');
select is((select count(*)::int from public.print_heading), 2, 'the other organization''s headings stay invisible');

reset role;
select throws_ok(
  $$insert into public.party_type (org_id, name, account_type)
    values (current_setting('test.org')::uuid, ' customer ', 'Receivable')$$,
  '23505', null, 'a repeated party type is rejected'
);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000049a2","role":"authenticated"}', true);

select is(
  (select account_type from public.party_type where name = 'Customer'),
  'Receivable',
  'Accounts User can read a party type'
);
select throws_ok(
  $$insert into public.party_type (org_id, name, account_type)
    values (current_setting('test.org')::uuid, 'Employee', 'Payable')$$,
  '42501', null, 'Accounts User cannot insert a party type'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000049a1","role":"authenticated"}', true);
insert into public.print_heading (org_id, print_heading)
values (current_setting('test.org')::uuid, '  Provisional  ');
select is(
  (select name from public.print_heading where print_heading = 'Provisional'),
  'Provisional',
  'System Manager saves a heading and the name is the trimmed heading'
);
select throws_ok(
  $$insert into public.print_heading (org_id, print_heading)
    values (current_setting('test.org')::uuid, 'credit note')$$,
  '23505', null, 'a repeated heading is rejected'
);

select * from finish();
rollback;
