begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000039b1', 'supplier-group-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000039b1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Supplier Group Org","slug":"supplier-group-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select is((select count(*)::int from public.supplier_group), 8, 'supplier groups: root plus the seven A9 leaves');

-- System Manager can read Supplier Group. Only Purchase Manager may delete, which is what the root guard checks.
reset role;
update public.org_members
   set roles = '{System Manager,Purchase Manager}'
 where user_id = '00000000-0000-0000-0000-0000000039b1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000039b1","role":"authenticated"}', true);

select throws_ok(
  $$delete from public.supplier_group where supplier_group_name = 'All Supplier Groups'$$,
  'P0001', 'supplier_group_root: All Supplier Groups cannot be deleted',
  'the supplier group root cannot be deleted'
);

select * from finish();
rollback;
