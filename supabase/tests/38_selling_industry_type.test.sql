begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000038a1', 'industry-type-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000038a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Industry Type Org","slug":"industry-type-org","country":"Ivory Coast"}') ->> 'id',
  true
);

-- System Manager can read Industry Type. Only Sales Manager may create.
reset role;
update public.org_members
   set roles = '{System Manager,Sales Manager}'
 where user_id = '00000000-0000-0000-0000-0000000038a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000038a1","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.industry_type (org_id, industry) values (current_setting('test.org')::uuid, 'Retail')$$,
  'Sales Manager can add an industry type'
);
select throws_ok(
  $$insert into public.industry_type (org_id, industry) values (current_setting('test.org')::uuid, ' retail ')$$,
  '23505',
  'duplicate key value violates unique constraint "industry_type_name_uniq"',
  'an industry is unique per organization, ignoring case and surrounding spaces'
);

select * from finish();
rollback;
