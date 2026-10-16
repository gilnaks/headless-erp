begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000040c1', 'terms-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000040c1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Terms Org","slug":"terms-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select lives_ok(
  $$insert into public.terms_and_conditions (org_id, title) values (current_setting('test.org')::uuid, 'Standard')$$,
  'System Manager can add terms'
);
select throws_ok(
  $$insert into public.terms_and_conditions (org_id, title) values (current_setting('test.org')::uuid, ' standard ')$$,
  '23505',
  'duplicate key value violates unique constraint "terms_title_uniq"',
  'a terms title is unique per organization, ignoring case and surrounding spaces'
);
select throws_ok(
  $$insert into public.terms_and_conditions (org_id, title, selling, buying)
    values (current_setting('test.org')::uuid, 'Empty', false, false)$$,
  'P0001', 'terms_module: At least one of Selling or Buying must be selected',
  'terms need a module unless disabled'
);

select * from finish();
rollback;
