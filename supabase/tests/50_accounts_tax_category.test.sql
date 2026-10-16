begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000050a1', 'tax-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000050a2', 'tax-accounts@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000050a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Tax Org","slug":"tax-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles)
values (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000050a2', '{Accounts User}');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000050a1","role":"authenticated"}', true);

insert into public.tax_category (org_id, title)
values (current_setting('test.org')::uuid, '  VAT  ');
select is(
  (select name from public.tax_category where title = 'VAT'),
  'VAT',
  'System Manager saves a trimmed title and the name matches'
);
select throws_ok(
  $$insert into public.tax_category (org_id, title) values (current_setting('test.org')::uuid, 'vat')$$,
  '23505', null, 'a repeated title is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000050a2","role":"authenticated"}', true);
select is((select name from public.tax_category where title = 'VAT'), 'VAT', 'Accounts User can read a tax category');
select throws_ok(
  $$insert into public.tax_category (org_id, title) values (current_setting('test.org')::uuid, 'Exempt')$$,
  '42501', null, 'Accounts User cannot insert a tax category'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000050a1","role":"authenticated"}', true);
insert into public.address (org_id, address_title, address_line1, city, tax_category_id)
  select current_setting('test.org')::uuid, 'Office', '1 Road', 'Abidjan', id
  from public.tax_category where title = 'VAT';
select ok(
  (select tax_category_id is not null from public.address where address_title = 'Office'),
  'an address can point at the category'
);
delete from public.tax_category where title = 'VAT';
select is(
  (select tax_category_id from public.address where address_title = 'Office'),
  null,
  'deleting the category clears the address link'
);

reset role;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
