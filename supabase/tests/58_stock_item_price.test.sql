begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000058a1', 'item-price-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000058a2', 'item-price-sales@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000058a3', 'item-price-user@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000058a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Item Price Org","slug":"item-price-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000058a2', '{Sales Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000058a3', '{Sales User}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000058a1","role":"authenticated"}', true);
insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000058c1', current_setting('test.org')::uuid, 'Price Co', 'PC');

reset role;
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.box', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Box'
), true);
select set_config('test.selling', (
  select p.id::text from public.price_list p
   where p.org_id = current_setting('test.org')::uuid and p.price_list_name = 'Standard Selling'
), true);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  (
    '20000000-0000-0000-0000-0000000058d1',
    current_setting('test.org')::uuid,
    'Widget',
    '',
    current_setting('test.products')::uuid,
    current_setting('test.nos')::uuid
  );
insert into public.price_list (id, org_id, price_list_name, currency, enabled, selling) values
  ('20000000-0000-0000-0000-0000000058e1', current_setting('test.org')::uuid, 'Closed', 'XOF', false, true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000058a2","role":"authenticated"}', true);

insert into public.item_price (id, org_id, item_id, price_list_id, price_list_rate, supplier_id) values
  (
    '20000000-0000-0000-0000-0000000058d2',
    current_setting('test.org')::uuid,
    '20000000-0000-0000-0000-0000000058d1',
    current_setting('test.selling')::uuid,
    10,
    '20000000-0000-0000-0000-0000000058f1'
  );
select ok(
  (
    select p.name is not null and p.name <> 'Widget'
      from public.item_price p
     where p.id = '20000000-0000-0000-0000-0000000058d2'
  ),
  'the name is set and is not the item code'
);
select is(
  (
    select p.item_name from public.item_price p
     where p.id = '20000000-0000-0000-0000-0000000058d2'
  ),
  'Widget',
  'a blank item name on the price becomes the item name'
);
select is(
  (
    select p.uom_id::text from public.item_price p
     where p.id = '20000000-0000-0000-0000-0000000058d2'
  ),
  current_setting('test.nos'),
  'a blank UOM becomes Nos'
);
select is(
  (
    select p.valid_from from public.item_price p
     where p.id = '20000000-0000-0000-0000-0000000058d2'
  ),
  current_date,
  'a blank valid-from is today'
);
select throws_ok(
  $$insert into public.item_price (org_id, item_id, uom_id, price_list_id, price_list_rate)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000058d1',
      current_setting('test.box')::uuid,
      current_setting('test.selling')::uuid,
      12
    )$$,
  'P0001',
  'item_price_uom: UOM not found in Item',
  'a UOM that is not on the item is rejected'
);
select throws_ok(
  $$insert into public.item_price (org_id, item_id, price_list_id, price_list_rate)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000058d1',
      '20000000-0000-0000-0000-0000000058e1',
      12
    )$$,
  'P0001',
  'item_price_list: The price list does not exist or is disabled',
  'a disabled price list is rejected'
);
select throws_ok(
  $$insert into public.item_price (org_id, item_id, price_list_id, price_list_rate, valid_upto)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000058d1',
      current_setting('test.selling')::uuid,
      12,
      current_date - 1
    )$$,
  'P0001',
  'item_price_dates: Valid Upto cannot be before Valid From',
  'a valid-upto before valid-from is rejected'
);
select throws_ok(
  $$insert into public.item_price (org_id, item_id, price_list_id, price_list_rate)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000058d1',
      current_setting('test.selling')::uuid,
      11
    )$$,
  'P0001',
  'item_price_duplicate: Item Price appears multiple times based on Price List, Supplier/Customer, Currency, Item, Batch, UOM, Qty, and Dates.',
  'a second identical row is rejected'
);
select lives_ok(
  $$insert into public.item_price (org_id, item_id, price_list_id, price_list_rate, packing_unit)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000058d1',
      current_setting('test.selling')::uuid,
      9,
      10
    )$$,
  'packing unit 10 is a different price'
);
select is(
  (
    select p.supplier_id from public.item_price p
     where p.id = '20000000-0000-0000-0000-0000000058d2'
  ),
  null,
  'a selling list clears the supplier'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000058a3","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.item_price (org_id, item_id, price_list_id, price_list_rate, packing_unit)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000058d1',
      current_setting('test.selling')::uuid,
      8,
      20
    )$$,
  '42501',
  null,
  'Sales User cannot create'
);

reset role;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
