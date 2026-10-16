begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000036e1', 'sales-person-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000036e1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Sales Person Org","slug":"sales-person-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select is((select count(*)::int from public.sales_person), 1, 'sales team root is seeded');

-- System Manager can read Sales Person. Only Sales Manager may delete, which is what the root guard checks.
reset role;
update public.org_members
   set roles = '{System Manager,Sales Manager}'
 where user_id = '00000000-0000-0000-0000-0000000036e1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000036e1","role":"authenticated"}', true);

select throws_ok(
  $$delete from public.sales_person where sales_person_name = 'Sales Team'$$,
  'P0001', 'sales_person_root: Sales Team cannot be deleted',
  'the sales person root cannot be deleted'
);

select * from finish();
rollback;
