begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000035d1', 'customer-group-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000035d1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Customer Group Org","slug":"customer-group-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select is((select count(*)::int from public.customer_group), 5, 'customer groups: root plus the four A8 leaves');

-- System Manager can read Customer Group. Only Sales Manager may delete, which is what the root guard checks.
reset role;
update public.org_members
   set roles = '{System Manager,Sales Manager}'
 where user_id = '00000000-0000-0000-0000-0000000035d1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000035d1","role":"authenticated"}', true);

select throws_ok(
  $$delete from public.customer_group where customer_group_name = 'All Customer Groups'$$,
  'P0001', 'customer_group_root: All Customer Groups cannot be deleted',
  'the customer group root cannot be deleted'
);

select * from finish();
rollback;
