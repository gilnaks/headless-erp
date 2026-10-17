begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000060a1', 'bundle-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000060a2', 'bundle-stock@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000060a3', 'bundle-user@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000060a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Bundle Org","slug":"bundle-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000060a2', '{Stock Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000060a3', '{Stock User}');

select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item) values
  ('20000000-0000-0000-0000-0000000060d1', current_setting('test.org')::uuid, 'Kit', 'Kit', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, false),
  ('20000000-0000-0000-0000-0000000060d2', current_setting('test.org')::uuid, 'Part', 'Part', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, true),
  ('20000000-0000-0000-0000-0000000060d4', current_setting('test.org')::uuid, 'Inner', 'Inner', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, false),
  ('20000000-0000-0000-0000-0000000060d5', current_setting('test.org')::uuid, 'Other', 'Other', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, false);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id, is_stock_item, is_fixed_asset) values
  ('20000000-0000-0000-0000-0000000060d3', current_setting('test.org')::uuid, 'Asset', 'Asset', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, false, true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000060a2","role":"authenticated"}', true);
insert into public.product_bundle (id, org_id, new_item_id) values
  ('20000000-0000-0000-0000-0000000060e1', current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060d1');
insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060e1', 1, '20000000-0000-0000-0000-0000000060d2', 1);

select ok(
  (
    select name from public.product_bundle
     where id = '20000000-0000-0000-0000-0000000060e1'
  ) like 'PB-Kit-001',
  'the name is PB-Kit-001'
);
select is(
  (
    select i.uom_id::text from public.product_bundle_item i
     where i.parent_id = '20000000-0000-0000-0000-0000000060e1'
  ),
  current_setting('test.nos'),
  'a blank component UOM becomes the item stock UOM'
);

select throws_ok(
  $$insert into public.product_bundle (org_id, new_item_id)
    values (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060d2')$$,
  'P0001',
  'product_bundle_stock: Parent Item must not be a Stock Item',
  'a stock parent is rejected'
);
select throws_ok(
  $$insert into public.product_bundle (org_id, new_item_id)
    values (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060d3')$$,
  'P0001',
  'product_bundle_asset: Parent Item must not be a Fixed Asset',
  'a fixed-asset parent is rejected'
);
select throws_ok(
  $$insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000060e1',
      2,
      '20000000-0000-0000-0000-0000000060d2',
      0
    )$$,
  'P0001',
  'product_bundle_qty: Quantity must be greater than zero',
  'a non-positive quantity is rejected'
);
select throws_ok(
  $$insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty, uom_id)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000060e1',
      2,
      '20000000-0000-0000-0000-0000000060d2',
      1.5,
      current_setting('test.nos')::uuid
    )$$,
  'P0001',
  'product_bundle_uom: Quantity cannot be a fraction for this UOM',
  'a fractional quantity on Nos is rejected'
);

insert into public.product_bundle (id, org_id, new_item_id) values
  ('20000000-0000-0000-0000-0000000060e3', current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060d4');
insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060e3', 1, '20000000-0000-0000-0000-0000000060d2', 1);
do $$ begin
  perform public.submit_doc('Product Bundle', '20000000-0000-0000-0000-0000000060e3');
end $$;
select throws_ok(
  $$insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000060e1',
      2,
      '20000000-0000-0000-0000-0000000060d4',
      1
    )$$,
  'P0001',
  'product_bundle_child: Child Item should not be a Product Bundle',
  'a child that is an active bundle is rejected'
);

do $$ begin
  perform public.submit_doc('Product Bundle', '20000000-0000-0000-0000-0000000060e1');
end $$;
insert into public.product_bundle (id, org_id, new_item_id) values
  ('20000000-0000-0000-0000-0000000060e2', current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060d1');
insert into public.product_bundle_item (org_id, parent_id, idx, item_id, qty) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060e2', 1, '20000000-0000-0000-0000-0000000060d2', 1);
do $$ begin
  perform public.submit_doc('Product Bundle', '20000000-0000-0000-0000-0000000060e2');
end $$;
select is(
  (
    select b.is_active from public.product_bundle b
     where b.id = '20000000-0000-0000-0000-0000000060e1'
  ),
  false,
  'submit deactivates the other submitted bundle'
);

do $$ begin
  perform public.cancel_doc('Product Bundle', '20000000-0000-0000-0000-0000000060e2');
end $$;
select is(
  (
    select b.is_active from public.product_bundle b
     where b.id = '20000000-0000-0000-0000-0000000060e2'
  ),
  false,
  'cancel clears is_active'
);

do $$ begin
  perform public.cancel_doc('Product Bundle', '20000000-0000-0000-0000-0000000060e3');
  perform public.amend_doc('Product Bundle', '20000000-0000-0000-0000-0000000060e3');
end $$;
select is(
  (
    select b.name from public.product_bundle b
     where b.amended_from = '20000000-0000-0000-0000-0000000060e3'
  ),
  'PB-Inner-002',
  'an amendment is named PB-Inner-002'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000060a3","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.product_bundle (org_id, new_item_id)
    values (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000060d5')$$,
  '42501',
  null,
  'Stock User cannot create'
);

reset role;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
