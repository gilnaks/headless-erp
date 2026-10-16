begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000037f1', 'territory-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000037f1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Territory Org","slug":"territory-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select is((select count(*)::int from public.territory), 3, 'territories: root, country, and Rest Of The World');
select ok(
  exists (select 1 from public.territory where territory_name = 'Ivory Coast')
  and exists (select 1 from public.territory where territory_name = 'Rest Of The World'),
  'territory seed uses the organization country and adds Rest Of The World'
);

-- System Manager can read Territory. Only Sales Manager may delete, which is what the root guard checks.
reset role;
update public.org_members
   set roles = '{System Manager,Sales Manager}'
 where user_id = '00000000-0000-0000-0000-0000000037f1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000037f1","role":"authenticated"}', true);

select throws_ok(
  $$delete from public.territory where territory_name = 'All Territories'$$,
  'P0001', 'territory_root: All Territories cannot be deleted',
  'the territory root cannot be deleted'
);

select * from finish();
rollback;
