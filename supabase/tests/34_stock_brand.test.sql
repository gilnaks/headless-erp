begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000034c1', 'brand-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000034c1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Brand Org","slug":"brand-org","country":"Ivory Coast"}') ->> 'id',
  true
);

-- System Manager can read Brand. Only Item Manager may create.
reset role;
update public.org_members
   set roles = '{System Manager,Item Manager}'
 where user_id = '00000000-0000-0000-0000-0000000034c1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000034c1","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.brand (org_id, brand) values (current_setting('test.org')::uuid, 'Acme')$$,
  'Item Manager can add a brand'
);
select throws_ok(
  $$insert into public.brand (org_id, brand) values (current_setting('test.org')::uuid, ' acme ')$$,
  '23505',
  'duplicate key value violates unique constraint "brand_name_uniq"',
  'a brand name is unique per organization, ignoring case and surrounding spaces'
);

select * from finish();
rollback;
