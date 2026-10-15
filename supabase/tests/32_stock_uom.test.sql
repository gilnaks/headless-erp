begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000032a1', 'uom-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000032a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"UOM Org","slug":"uom-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select is((select count(*)::int from public.uom), 21, 'a new organization gets the 21 curated units, including Dozen');
select is(
  (select must_be_whole_number from public.uom where uom_name = 'Nos'),
  true,
  'Nos must be a whole number'
);
select cmp_ok((select count(*)::int from public.uom_conversion_factor), '>', 0, 'curated conversions are copied');

select * from finish();
rollback;
