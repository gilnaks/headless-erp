begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000033b1', 'item-group-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000033b1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Item Group Org","slug":"item-group-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select is((select count(*)::int from public.item_group), 6, 'item groups: root plus the five A5 leaves');

-- System Manager can read Item Group. Only Item Manager may delete, which is what the root guard checks.
reset role;
update public.org_members
   set roles = '{System Manager,Item Manager}'
 where user_id = '00000000-0000-0000-0000-0000000033b1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000033b1","role":"authenticated"}', true);

select throws_ok(
  $$delete from public.item_group where item_group_name = 'All Item Groups'$$,
  'P0001', 'item_group_root: All Item Groups cannot be deleted',
  'the item group root cannot be deleted'
);

select * from finish();
rollback;
