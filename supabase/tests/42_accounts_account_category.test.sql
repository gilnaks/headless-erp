begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000042e1', 'account-category-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000042e1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Account Category Org","slug":"account-category-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select ok(
  exists (select 1 from public.account_category where account_category_name = 'Cash and Cash Equivalents'),
  'the chart seed includes Cash and Cash Equivalents'
);
select cmp_ok(
  (select count(*)::int from public.account_category),
  '>',
  0,
  'a new organization gets the categories named in the vendored charts'
);

-- System Manager can read Account Category. Only Accounts Manager may create.
reset role;
update public.org_members
   set roles = '{System Manager,Accounts Manager}'
 where user_id = '00000000-0000-0000-0000-0000000042e1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000042e1","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.account_category (org_id, account_category_name)
    values (current_setting('test.org')::uuid, 'Headless Custom Category')$$,
  'Accounts Manager can add an account category'
);
select throws_ok(
  $$insert into public.account_category (org_id, account_category_name)
    values (current_setting('test.org')::uuid, ' cash and cash equivalents ')$$,
  '23505',
  'duplicate key value violates unique constraint "account_category_name_uniq"',
  'an account category name is unique per organization, ignoring case and surrounding spaces'
);

select * from finish();
rollback;
