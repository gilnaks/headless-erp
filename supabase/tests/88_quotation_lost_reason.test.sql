begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008801', 'lost-reason-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008802', 'lost-reason-sales@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008801","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Lost Reason Org","slug":"lost-reason-88","country":"Ivory Coast"}') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = '{System Manager,Sales Manager}'
 where user_id = '00000000-0000-0000-0000-000000008801';
insert into public.org_members (org_id, user_id, roles)
values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-000000008802', '{Sales User}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008801","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.quotation_lost_reason (org_id, order_lost_reason)
    values (current_setting('test.org')::uuid, 'Price')$$,
  'Sales Manager can add a lost reason'
);
select throws_ok(
  $$insert into public.quotation_lost_reason (org_id, order_lost_reason)
    values (current_setting('test.org')::uuid, ' price ')$$,
  '23505',
  'duplicate key value violates unique constraint "quotation_lost_reason_name_uniq"',
  'a reason is unique per organization, ignoring case and surrounding spaces'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008802","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.quotation_lost_reason (org_id, order_lost_reason)
    values (current_setting('test.org')::uuid, 'Delivery')$$,
  '42501',
  null,
  'Sales User cannot create a lost reason'
);

select * from finish();
rollback;
