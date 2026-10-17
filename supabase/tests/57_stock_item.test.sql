begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000057a1', 'item-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000057a2', 'item-manager@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000057a3', 'item-reader@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000057a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Item Org","slug":"item-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000057a2', '{Item Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000057a3', '{Stock User}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000057a1","role":"authenticated"}', true);
insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000057c1', current_setting('test.org')::uuid, 'Item Co', 'IC'),
  ('20000000-0000-0000-0000-0000000057c2', current_setting('test.org')::uuid, 'Other Co', 'OC');

reset role;
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.stores', (
  select w.id::text from public.warehouse w
   where w.company_id = '20000000-0000-0000-0000-0000000057c1' and w.warehouse_name = 'Stores'
), true);
select set_config('test.other_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = '20000000-0000-0000-0000-0000000057c2' and w.warehouse_name = 'Stores'
), true);
insert into public.uom (id, org_id, uom_name, enabled) values
  ('20000000-0000-0000-0000-0000000057e1', current_setting('test.org')::uuid, 'Off', false);
insert into public.item_group_default (org_id, parent_id, idx, company_id, default_warehouse_id) values
  (
    current_setting('test.org')::uuid,
    current_setting('test.products')::uuid,
    1,
    '20000000-0000-0000-0000-0000000057c1',
    current_setting('test.stores')::uuid
  );

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000057a2","role":"authenticated"}', true);

insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  (
    '20000000-0000-0000-0000-0000000057d1',
    current_setting('test.org')::uuid,
    '  Widget  ',
    '',
    current_setting('test.products')::uuid,
    current_setting('test.nos')::uuid
  );
select is(
  (
    select i.name from public.item i
     where i.id = '20000000-0000-0000-0000-0000000057d1'
  ),
  'Widget',
  'the name is the trimmed item code'
);
select is(
  (
    select i.item_name from public.item i
     where i.id = '20000000-0000-0000-0000-0000000057d1'
  ),
  'Widget',
  'a blank item name becomes the code'
);
select throws_ok(
  $$insert into public.item (org_id, item_code, item_group_id, stock_uom_id)
    values (
      current_setting('test.org')::uuid,
      'widget',
      current_setting('test.products')::uuid,
      current_setting('test.nos')::uuid
    )$$,
  '23505',
  null,
  'a duplicate code is rejected'
);
select throws_ok(
  $$update public.item set item_group_id = (
      select g.id from public.item_group g
       where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'All Item Groups'
    )
    where id = '20000000-0000-0000-0000-0000000057d1'$$,
  'P0001',
  'item_group_leaf: Item Group must be a leaf',
  'a group item group is rejected'
);
select throws_ok(
  $$update public.item set stock_uom_id = '20000000-0000-0000-0000-0000000057e1'
    where id = '20000000-0000-0000-0000-0000000057d1'$$,
  'P0001',
  'item_uom: Stock UOM is disabled',
  'a disabled UOM is rejected'
);
select throws_ok(
  $$insert into public.item (org_id, item_code, item_group_id, stock_uom_id, end_of_life)
    values (
      current_setting('test.org')::uuid,
      'Old',
      current_setting('test.products')::uuid,
      current_setting('test.nos')::uuid,
      current_date - 1
    )$$,
  'P0001',
  'item_end_of_life: End of Life cannot be before today',
  'an end of life before today is rejected'
);
select lives_ok(
  $$update public.item set end_of_life = null
    where id = '20000000-0000-0000-0000-0000000057d1'$$,
  'a blank end of life is saved'
);
select is(
  (
    select i.end_of_life::text from public.item i
     where i.id = '20000000-0000-0000-0000-0000000057d1'
  ),
  '2099-12-31',
  'a blank end of life becomes 2099-12-31'
);
select throws_ok(
  $$update public.item set has_variants = true
    where id = '20000000-0000-0000-0000-0000000057d1'$$,
  'P0001',
  'item_variants: Item variants are not built',
  'has_variants is rejected'
);
select is(
  (
    select u.conversion_factor::text from public.item_uom u
     where u.parent_id = '20000000-0000-0000-0000-0000000057d1'
       and u.uom_id = current_setting('test.nos')::uuid
  ),
  '1.000000000',
  'the stock UOM row is factor 1'
);
select throws_ok(
  $$update public.item_uom set conversion_factor = 2
    where parent_id = '20000000-0000-0000-0000-0000000057d1'$$,
  'P0001',
  'item_uom_factor: Conversion factor for default Unit of Measure must be 1 in row 1',
  'a second factor is rejected'
);
select throws_ok(
  $$insert into public.item_default (org_id, parent_id, idx, company_id, default_warehouse_id)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000057d1',
      2,
      '20000000-0000-0000-0000-0000000057c1',
      current_setting('test.other_wh')::uuid
    )$$,
  'P0001',
  'item_default_company: Row 2: Warehouse does not belong to the company',
  'a warehouse from another company is rejected'
);
insert into public.item_barcode (org_id, parent_id, idx, barcode) values
  (
    current_setting('test.org')::uuid,
    '20000000-0000-0000-0000-0000000057d1',
    1,
    'ABC'
  );
insert into public.item (id, org_id, item_code, item_group_id, stock_uom_id) values
  (
    '20000000-0000-0000-0000-0000000057d2',
    current_setting('test.org')::uuid,
    'Other',
    current_setting('test.products')::uuid,
    current_setting('test.nos')::uuid
  );
select throws_ok(
  $$insert into public.item_barcode (org_id, parent_id, idx, barcode)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000057d2',
      1,
      'abc'
    )$$,
  '23505',
  null,
  'a duplicate barcode is rejected'
);
select is(
  (
    select d.default_warehouse_id::text from public.item_default d
     where d.parent_id = '20000000-0000-0000-0000-0000000057d1'
  ),
  current_setting('test.stores'),
  'empty defaults are copied from the item group'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000057a3","role":"authenticated"}', true);
select is(
  (
    select i.name from public.item i
     where i.id = '20000000-0000-0000-0000-0000000057d1'
  ),
  'Widget',
  'Stock User can read an item'
);
select throws_ok(
  $$insert into public.item (org_id, item_code, item_group_id, stock_uom_id)
    values (
      current_setting('test.org')::uuid,
      'Denied',
      current_setting('test.nos')::uuid,
      current_setting('test.nos')::uuid
    )$$,
  '42501',
  null,
  'Stock User cannot create an item'
);

reset role;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
