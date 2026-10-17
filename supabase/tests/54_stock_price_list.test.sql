begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000054a1', 'price-list-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000054a2', 'price-list-sales@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000054a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Price List Org","slug":"price-list-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles)
values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000054a2', '{Sales User}');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000054a1","role":"authenticated"}', true);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000054c1', current_setting('test.org')::uuid, 'Price Co', 'PC');

select is(
  (
    select p.currency
      from public.price_list p
     where p.org_id = current_setting('test.org')::uuid
       and p.name = 'Standard Selling'
  ),
  'XOF',
  'Standard Selling uses the organization currency'
);
select ok(
  (
    select p.selling and not p.buying
      from public.price_list p
     where p.org_id = current_setting('test.org')::uuid
       and p.name = 'Standard Selling'
  ),
  'Standard Selling is a selling list'
);
select is(
  (
    select p.currency
      from public.price_list p
     where p.org_id = current_setting('test.org')::uuid
       and p.name = 'Standard Buying'
  ),
  'XOF',
  'Standard Buying uses the organization currency'
);
select ok(
  (
    select p.buying and not p.selling
      from public.price_list p
     where p.org_id = current_setting('test.org')::uuid
       and p.name = 'Standard Buying'
  ),
  'Standard Buying is a buying list'
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000054c2', current_setting('test.org')::uuid, 'Other Co', 'OC');
select is(
  (
    select count(*)::int
      from public.price_list p
     where p.org_id = current_setting('test.org')::uuid
  ),
  2,
  'a second company does not add a list'
);
select throws_ok(
  $$insert into public.price_list (org_id, price_list_name, currency)
    values (current_setting('test.org')::uuid, 'Neither', 'XOF')$$,
  'P0001',
  'price_list_side: At least one of Buying or Selling must be selected',
  'neither buying nor selling is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000054a2","role":"authenticated"}', true);
select is(
  (
    select count(*)::int
      from public.price_list p
     where p.org_id = current_setting('test.org')::uuid
  ),
  2,
  'Sales User can read the price lists'
);
select throws_ok(
  $$insert into public.price_list (org_id, price_list_name, currency, selling)
    values (current_setting('test.org')::uuid, 'Retail', 'XOF', true)$$,
  '42501',
  null,
  'Sales User cannot create a price list'
);

reset role;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
