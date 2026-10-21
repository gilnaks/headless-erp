begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008401', 'stock84@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008402', 'stock84-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008401","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Projected Co", "slug": "stock-84", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Projected Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
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
select set_config('test.root_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.parent_id is null
), true);

insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000084a1', current_setting('test.org')::uuid, 'Group 84', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, true);
insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000084a2', current_setting('test.org')::uuid, 'Leaf 84', current_setting('test.company')::uuid, '20000000-0000-0000-0000-0000000084a1', false),
  ('20000000-0000-0000-0000-0000000084a3', current_setting('test.org')::uuid, 'Side 84', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false);

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id, disabled
) values
  ('20000000-0000-0000-0000-0000000084d1', current_setting('test.org')::uuid, 'BAL-84', 'BAL-84', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, false),
  ('20000000-0000-0000-0000-0000000084d2', current_setting('test.org')::uuid, 'LOW-84', 'LOW-84', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, false),
  ('20000000-0000-0000-0000-0000000084d3', current_setting('test.org')::uuid, 'SIDE-84', 'SIDE-84', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, false),
  ('20000000-0000-0000-0000-0000000084d4', current_setting('test.org')::uuid, 'OFF-84', 'OFF-84', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, true);

insert into public.bin (
  org_id, item_id, warehouse_id, actual_qty, ordered_qty, indented_qty, reserved_qty, planned_qty, projected_qty, stock_uom_id
) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000084d1', '20000000-0000-0000-0000-0000000084a2', 10, 0, 4, 0, 0, 14, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000084d2', '20000000-0000-0000-0000-0000000084a2', 10, 0, 0, 0, 0, 10, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000084d3', '20000000-0000-0000-0000-0000000084a3', 7, 0, 0, 0, 0, 7, current_setting('test.nos')::uuid),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000084d4', '20000000-0000-0000-0000-0000000084a2', 3, 0, 0, 0, 0, 3, current_setting('test.nos')::uuid);

insert into public.item_reorder (
  org_id, parent_id, idx, warehouse_id, material_request_type, warehouse_reorder_level, warehouse_reorder_qty
) values
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000084d1', 1, '20000000-0000-0000-0000-0000000084a2', 'Purchase', 100, 1),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000084d1', 2, '20000000-0000-0000-0000-0000000084a2', 'Material Transfer', 20, 5),
  (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000084d2', 1, '20000000-0000-0000-0000-0000000084a2', 'Purchase', 5, 1);

select set_config('test.filters', jsonb_build_object(
  'company', current_setting('test.company')
)::text, true);

set local role authenticated;

select set_config(
  'test.report',
  public.report_stock_projected_qty(current_setting('test.filters')::jsonb)::text,
  true
);

select is(
  (
    select (entry ->> 'actual_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  10::numeric,
  'actual qty is the stored bin qty'
);
select is(
  (
    select (entry ->> 'indented_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  4::numeric,
  'requested qty is the stored indented qty'
);
select is(
  (
    select (entry ->> 'projected_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  14::numeric,
  'projected qty is the stored bin value'
);
select is(
  (
    select (entry ->> 'ordered_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  0::numeric,
  'ordered qty stays the stored value'
);
select is(
  (
    select (entry ->> 'reserved_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  0::numeric,
  'reserved qty stays the stored value'
);
select is(
  (
    select (entry ->> 'planned_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  0::numeric,
  'planned qty stays the stored value'
);
select is(
  (
    select (entry ->> 'shortage_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  6::numeric,
  'shortage uses the latest reorder row for that warehouse'
);
select is(
  (
    select entry ->> 'row_type'
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  'entry',
  'a projected row is an entry'
);
select is(
  (
    select (entry ->> 'shortage_qty')::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'LOW-84'
  ),
  0::numeric,
  'shortage is zero when the reorder level is not above projected qty'
);

select is(
  jsonb_array_length(
    public.report_stock_projected_qty(
      current_setting('test.filters')::jsonb || jsonb_build_object('item', '20000000-0000-0000-0000-0000000084d1')
    ) -> 'rows'
  ),
  1,
  'an item filter keeps one row'
);
select is(
  public.report_stock_projected_qty(
    current_setting('test.filters')::jsonb || jsonb_build_object('item', '20000000-0000-0000-0000-0000000084d1')
  ) #>> '{rows,0,item}',
  'BAL-84',
  'an item filter keeps that item'
);

select ok(
  exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_projected_qty(
          current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000084a1')
        ) -> 'rows'
      ) entry
     where entry ->> 'item' = 'BAL-84'
  ),
  'a group warehouse includes its child'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(
        public.report_stock_projected_qty(
          current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000084a1')
        ) -> 'rows'
      ) entry
     where entry ->> 'item' = 'SIDE-84'
  ),
  'a sibling warehouse is left out of the group'
);

select is(
  jsonb_array_length(
    public.report_stock_projected_qty(
      current_setting('test.filters')::jsonb || jsonb_build_object('warehouse', '20000000-0000-0000-0000-0000000084ff')
    ) -> 'rows'
  ),
  0,
  'an unknown warehouse returns no rows'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'item' = 'OFF-84'
  ),
  'a disabled item is omitted'
);

select is(
  (
    select (entry ->> 'actual_qty')::numeric
      from jsonb_array_elements(public.report_stock_projected_qty('{}'::jsonb) -> 'rows') entry
     where entry ->> 'item' = 'BAL-84'
  ),
  10::numeric,
  'a blank company still lists the bin'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008402","role":"authenticated"}', true);
select is(
  jsonb_array_length(public.report_stock_projected_qty(current_setting('test.filters')::jsonb) -> 'rows'),
  0,
  'a user outside the organization sees no rows'
);

select * from finish();
rollback;
