begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008001', 'stock80@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008002', 'stock80-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008001","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Reorder Co", "slug": "stock-80", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Reorder Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.stores', (
  select c.default_warehouse_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.all_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.parent_id is null
), true);

insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values (
  '20000000-0000-0000-0000-0000000080a1',
  current_setting('test.org')::uuid,
  'Zone 80',
  current_setting('test.company')::uuid,
  current_setting('test.all_wh')::uuid,
  true
);
insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id) values
  ('20000000-0000-0000-0000-0000000080a2', current_setting('test.org')::uuid, 'Leaf 80', current_setting('test.company')::uuid, '20000000-0000-0000-0000-0000000080a1'),
  ('20000000-0000-0000-0000-0000000080a3', current_setting('test.org')::uuid, 'Side 80', current_setting('test.company')::uuid, '20000000-0000-0000-0000-0000000080a1');

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id, lead_time_days, disabled
) values
  ('20000000-0000-0000-0000-0000000080d1', current_setting('test.org')::uuid, 'P1-80', 'P1-80', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, 3, false),
  ('20000000-0000-0000-0000-0000000080d2', current_setting('test.org')::uuid, 'P2-80', 'P2-80', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, 0, false),
  ('20000000-0000-0000-0000-0000000080d3', current_setting('test.org')::uuid, 'ISSUE-80', 'ISSUE-80', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, false),
  ('20000000-0000-0000-0000-0000000080d4', current_setting('test.org')::uuid, 'HIGH-80', 'HIGH-80', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, false),
  ('20000000-0000-0000-0000-0000000080d5', current_setting('test.org')::uuid, 'OFF-80', 'OFF-80', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, true),
  ('20000000-0000-0000-0000-0000000080d6', current_setting('test.org')::uuid, 'GRP-80', 'GRP-80', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, false),
  ('20000000-0000-0000-0000-0000000080d7', current_setting('test.org')::uuid, 'CAN-80', 'CAN-80', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null, false);

insert into public.item_reorder (
  org_id, parent_id, idx, warehouse_id, warehouse_group_id, material_request_type, warehouse_reorder_level, warehouse_reorder_qty
) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d1', 1, current_setting('test.stores')::uuid, null, 'Purchase', 10, 2.4),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d2', 1, current_setting('test.stores')::uuid, null, 'Purchase', 5, 4),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d3', 1, current_setting('test.stores')::uuid, null, 'Material Issue', 8, 1),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d4', 1, current_setting('test.stores')::uuid, null, 'Purchase', 10, 5),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d5', 1, current_setting('test.stores')::uuid, null, 'Purchase', 10, 1),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d6', 1, '20000000-0000-0000-0000-0000000080a2', '20000000-0000-0000-0000-0000000080a1', 'Purchase', 10, 9),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d7', 1, current_setting('test.stores')::uuid, null, 'Purchase', 10, 6);

insert into public.bin (org_id, item_id, warehouse_id, actual_qty, ordered_qty, stock_uom_id) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d4', current_setting('test.stores')::uuid, 4, 6, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d6', '20000000-0000-0000-0000-0000000080a2', 4, 0, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000080d6', '20000000-0000-0000-0000-0000000080a3', 8, 0, current_setting('test.nos')::uuid);

insert into public.material_request (
  id, org_id, name, company_id, material_request_type, transaction_date, schedule_date, status, docstatus
) values (
  '20000000-0000-0000-0000-0000000080e1',
  current_setting('test.org')::uuid,
  'CAN-80',
  current_setting('test.company')::uuid,
  'Purchase',
  current_date,
  current_date,
  'Cancelled',
  2
);
insert into public.material_request_item (
  org_id, parent_id, idx, item_id, qty, uom_id, schedule_date, warehouse_id
) values (
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000080e1',
  1,
  '20000000-0000-0000-0000-0000000080d7',
  6,
  current_setting('test.nos')::uuid,
  current_date,
  current_setting('test.stores')::uuid
);

update public.stock_settings set auto_indent = false where org_id = current_setting('test.org')::uuid;
select is(app.reorder_items(), 0, 'auto_indent off creates nothing');

update public.stock_settings set auto_indent = true where org_id = current_setting('test.org')::uuid;
select is(app.reorder_items(), 2, 'a short item drafts one request per company and purpose');
select is(
  (
    select count(distinct i.parent_id)::int
      from public.material_request_item i
     where i.item_id in (
       '20000000-0000-0000-0000-0000000080d1',
       '20000000-0000-0000-0000-0000000080d2'
     )
  ),
  1,
  'two purchase items share one draft'
);
select is(
  (
    select m.material_request_type
      from public.material_request_item i
      join public.material_request m on m.id = i.parent_id
     where i.item_id = '20000000-0000-0000-0000-0000000080d3'
  ),
  'Material Issue',
  'a second purpose is its own draft'
);
select is(
  (
    select count(*)::int from public.material_request_item i
     where i.item_id = '20000000-0000-0000-0000-0000000080d4'
  ),
  0,
  'a level that is not below is skipped'
);
select is(
  (
    select count(*)::int from public.material_request_item i
     where i.item_id = '20000000-0000-0000-0000-0000000080d5'
  ),
  0,
  'a disabled item is skipped'
);
select is(
  (
    select count(*)::int from public.material_request_item i
     where i.item_id = '20000000-0000-0000-0000-0000000080d6'
  ),
  0,
  'a group warehouse sums the child bins'
);
select is(
  (
    select i.qty = 3 and i.schedule_date = current_date + 3 and m.docstatus = 0 and m.status = 'Draft'
      from public.material_request_item i
      join public.material_request m on m.id = i.parent_id
     where i.item_id = '20000000-0000-0000-0000-0000000080d1'
       and m.docstatus = 0
  ),
  true,
  'the draft uses the stock UOM, rounds a whole number up, and adds lead time'
);
select is(
  (
    select count(*)::int
      from public.material_request_item i
      join public.material_request m on m.id = i.parent_id
     where i.item_id = '20000000-0000-0000-0000-0000000080d7'
       and m.docstatus = 0
  ),
  1,
  'a cancelled request does not suppress a new draft'
);

select is(app.reorder_items(), 0, 'an open draft suppresses a second run');

set local role authenticated;
select throws_ok(
  $$
    select app.reorder_items()
  $$,
  '42501',
  'permission denied for function reorder_items',
  'authenticated cannot run the reorder job'
);

select * from finish();
rollback;
