begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000008601', 'stock86@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000008602', 'stock86-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008601","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Analytics Co", "slug": "stock-86", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Analytics Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
select set_config('test.company', (
  select c.id::text from public.companies c
   where c.org_id = current_setting('test.org')::uuid
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.products', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.root_group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.parent_id is null
), true);
select set_config('test.root_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.company')::uuid and w.parent_id is null
), true);
select set_config('test.this_month', (
  select (array['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'])[extract(month from current_date)::int]
    || ' ' || extract(year from current_date)::int
), true);
select set_config('test.prev_month', (
  select (array['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'])[extract(month from current_date - 40)::int]
    || ' ' || extract(year from current_date - 40)::int
), true);

insert into public.item_group (id, org_id, item_group_name, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000086b1', current_setting('test.org')::uuid, 'Parent 86', current_setting('test.root_group')::uuid, true);
insert into public.item_group (id, org_id, item_group_name, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000086b2', current_setting('test.org')::uuid, 'Child 86', '20000000-0000-0000-0000-0000000086b1', false);

insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000086a1', current_setting('test.org')::uuid, 'Group 86', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, true);
insert into public.warehouse (id, org_id, warehouse_name, company_id, parent_id, is_group) values
  ('20000000-0000-0000-0000-0000000086a2', current_setting('test.org')::uuid, 'Leaf 86', current_setting('test.company')::uuid, '20000000-0000-0000-0000-0000000086a1', false),
  ('20000000-0000-0000-0000-0000000086a3', current_setting('test.org')::uuid, 'Side 86', current_setting('test.company')::uuid, current_setting('test.root_wh')::uuid, false);

select set_config('test.group_wh', (
  select w.name from public.warehouse w where w.id = '20000000-0000-0000-0000-0000000086a1'
), true);
select set_config('test.leaf_wh', (
  select w.name from public.warehouse w where w.id = '20000000-0000-0000-0000-0000000086a2'
), true);

insert into public.brand (id, org_id, brand) values
  ('20000000-0000-0000-0000-0000000086c1', current_setting('test.org')::uuid, 'Acme 86');

insert into public.item (
  id, org_id, item_code, item_name, item_group_id, stock_uom_id, brand_id
) values
  ('20000000-0000-0000-0000-0000000086d1', current_setting('test.org')::uuid, 'SPLIT-86', 'SPLIT-86', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000086d2', current_setting('test.org')::uuid, 'OLD-86', 'OLD-86', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000086d3', current_setting('test.org')::uuid, 'GRP-86', 'GRP-86', '20000000-0000-0000-0000-0000000086b2', current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000086d4', current_setting('test.org')::uuid, 'WH-86', 'WH-86', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000086d5', current_setting('test.org')::uuid, 'BR-86', 'BR-86', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, '20000000-0000-0000-0000-0000000086c1'),
  ('20000000-0000-0000-0000-0000000086d6', current_setting('test.org')::uuid, 'NOBR-86', 'NOBR-86', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null),
  ('20000000-0000-0000-0000-0000000086d7', current_setting('test.org')::uuid, 'CAN-86', 'CAN-86', current_setting('test.products')::uuid, current_setting('test.nos')::uuid, null);

insert into public.stock_ledger_entry (
  org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
  voucher_type, voucher_id, voucher_no, actual_qty, qty_after_transaction, incoming_rate,
  valuation_rate, stock_value, stock_value_difference, stock_uom_id, is_cancelled
) values
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d1', '20000000-0000-0000-0000-0000000086a3',
    current_date - 40, '09:00', (current_date - 40) + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f1', 'SPLIT-OLD', 4, 4, 2, 2, 8, 8,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d1', '20000000-0000-0000-0000-0000000086a3',
    current_date, '09:00', current_date + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f2', 'SPLIT-NOW', 6, 10, 5, 5, 38, 30,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d2', '20000000-0000-0000-0000-0000000086a3',
    current_date - 100, '09:00', (current_date - 100) + time '09:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f3', 'OLD-86', 5, 5, 1, 1, 5, 5,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d3', '20000000-0000-0000-0000-0000000086a3',
    current_date, '10:00', current_date + time '10:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f4', 'GRP-86', 3, 3, 1, 1, 3, 3,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d4', '20000000-0000-0000-0000-0000000086a2',
    current_date, '11:00', current_date + time '11:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f5', 'WH-86', 4, 4, 1, 1, 4, 4,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d5', '20000000-0000-0000-0000-0000000086a3',
    current_date, '12:00', current_date + time '12:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f6', 'BR-86', 6, 6, 1, 1, 6, 6,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d6', '20000000-0000-0000-0000-0000000086a3',
    current_date, '12:30', current_date + time '12:30',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f7', 'NOBR-86', 2, 2, 1, 1, 2, 2,
    current_setting('test.nos')::uuid, false
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d7', '20000000-0000-0000-0000-0000000086a3',
    current_date, '13:00', current_date + time '13:00',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f8', 'CAN-86', 9, 9, 1, 1, 9, 9,
    current_setting('test.nos')::uuid, true
  ),
  (
    current_setting('test.org')::uuid, current_setting('test.company')::uuid,
    '20000000-0000-0000-0000-0000000086d7', '20000000-0000-0000-0000-0000000086a3',
    current_date, '13:01', current_date + time '13:01',
    'Stock Entry', '20000000-0000-0000-0000-0000000086f9', 'CAN-KEEP', 1, 1, 1, 1, 1, 1,
    current_setting('test.nos')::uuid, false
  );

select set_config('test.filters', jsonb_build_object(
  'company', current_setting('test.company'),
  'from_date', (current_date - 40)::text,
  'to_date', current_date::text,
  'tree_type', 'Item',
  'value_quantity', 'Quantity',
  'range', 'Monthly'
)::text, true);

set local role authenticated;
select set_config(
  'test.report',
  public.report_stock_analytics(current_setting('test.filters')::jsonb)::text,
  true
);

select throws_ok(
  $$ select public.report_stock_analytics('{}'::jsonb) $$,
  'P0001',
  'sana_company: Company is mandatory',
  'a missing company is rejected'
);
select throws_ok(
  format(
    'select public.report_stock_analytics(%L::jsonb)',
    jsonb_build_object('company', current_setting('test.company'))
  ),
  'P0001',
  'sana_dates: From Date and To Date are mandatory',
  'missing dates are rejected'
);
select throws_ok(
  format(
    'select public.report_stock_analytics(%L::jsonb)',
    jsonb_build_object(
      'company', current_setting('test.company'),
      'from_date', current_date::text,
      'to_date', (current_date - 1)::text,
      'tree_type', 'Item',
      'value_quantity', 'Quantity',
      'range', 'Monthly'
    )
  ),
  'P0001',
  'sana_dates: From Date and To Date are mandatory',
  'a from-date after the to-date is rejected'
);

select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(current_setting('test.report')::jsonb -> 'columns') col
       where col ->> 'label' = current_setting('test.prev_month')
    ))::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'entity' = 'SPLIT-86'
  ),
  4::numeric,
  'a monthly report puts the older receipt in its own month'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(current_setting('test.report')::jsonb -> 'columns') col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'entity' = 'SPLIT-86'
  ),
  6::numeric,
  'a monthly report puts the later receipt in the current month'
);
select is(
  (
    select entry ->> 'row_type'
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'entity' = 'SPLIT-86'
  ),
  'entry',
  'an analytics row is an entry'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(
            current_setting('test.filters')::jsonb || jsonb_build_object('value_quantity', 'Value')
          ) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.prev_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('value_quantity', 'Value')
        ) -> 'rows'
      ) entry
     where entry ->> 'entity' = 'SPLIT-86'
  ),
  8::numeric,
  'value mode sums stock value difference'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(
            current_setting('test.filters')::jsonb || jsonb_build_object('value_quantity', 'Value')
          ) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('value_quantity', 'Value')
        ) -> 'rows'
      ) entry
     where entry ->> 'entity' = 'SPLIT-86'
  ),
  30::numeric,
  'value mode keeps the later movement in its own month'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(jsonb_build_object(
            'company', current_setting('test.company'),
            'from_date', date_trunc('month', current_date)::date::text,
            'to_date', current_date::text,
            'tree_type', 'Item',
            'value_quantity', 'Quantity',
            'range', 'Monthly'
          )) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(jsonb_build_object(
          'company', current_setting('test.company'),
          'from_date', date_trunc('month', current_date)::date::text,
          'to_date', current_date::text,
          'tree_type', 'Item',
          'value_quantity', 'Quantity',
          'range', 'Monthly'
        )) -> 'rows'
      ) entry
     where entry ->> 'entity' = 'SPLIT-86'
  ),
  6::numeric,
  'a receipt before the from-date does not fill the first period'
);
select ok(
  not exists (
    select 1
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'entity' = 'OLD-86'
  ),
  'a receipt before the rounded period is omitted'
);

select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(
            current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Item Group')
          ) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Item Group')
        ) -> 'rows'
      ) entry
     where entry ->> 'entity' = 'Child 86'
  ),
  3::numeric,
  'an item group shows its own movement'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(
            current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Item Group')
          ) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Item Group')
        ) -> 'rows'
      ) entry
     where entry ->> 'entity' = 'Parent 86'
  ),
  3::numeric,
  'an item group parent sums its descendants'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(
            current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Warehouse')
          ) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Warehouse')
        ) -> 'rows'
      ) entry
     where entry ->> 'entity' = current_setting('test.leaf_wh')
  ),
  4::numeric,
  'a warehouse shows its own movement'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(
            current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Warehouse')
          ) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Warehouse')
        ) -> 'rows'
      ) entry
     where entry ->> 'entity' = current_setting('test.group_wh')
  ),
  4::numeric,
  'a warehouse parent sums its descendants'
);
select is(
  jsonb_array_length(
    public.report_stock_analytics(
      current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Brand')
    ) -> 'rows'
  ),
  1,
  'items without a brand are omitted from the brand tree'
);
select is(
  (
    select entry ->> 'entity'
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Brand')
        ) -> 'rows'
      ) entry
  ),
  'Acme 86',
  'brand grouping uses the brand name'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(
          public.report_stock_analytics(
            current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Brand')
          ) -> 'columns'
        ) col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(
        public.report_stock_analytics(
          current_setting('test.filters')::jsonb || jsonb_build_object('tree_type', 'Brand')
        ) -> 'rows'
      ) entry
  ),
  6::numeric,
  'a brand sums the items that carry it'
);
select is(
  (
    select (entry ->> (
      select col ->> 'field'
        from jsonb_array_elements(current_setting('test.report')::jsonb -> 'columns') col
       where col ->> 'label' = current_setting('test.this_month')
    ))::numeric
      from jsonb_array_elements(current_setting('test.report')::jsonb -> 'rows') entry
     where entry ->> 'entity' = 'CAN-86'
  ),
  1::numeric,
  'a cancelled row is ignored'
);
select is(
  jsonb_array_length(
    public.report_stock_analytics(current_setting('test.filters')::jsonb || jsonb_build_object(
      'item', '20000000-0000-0000-0000-0000000086d1'
    )) -> 'rows'
  ),
  1,
  'an item filter returns that item'
);
select is(
  (
    select entry ->> 'entity'
      from jsonb_array_elements(
        public.report_stock_analytics(current_setting('test.filters')::jsonb || jsonb_build_object(
          'item', '20000000-0000-0000-0000-0000000086d1'
        )) -> 'rows'
      ) entry
  ),
  'SPLIT-86',
  'an item filter matches the item code'
);
select is(
  jsonb_array_length(
    public.report_stock_analytics(current_setting('test.filters')::jsonb || jsonb_build_object(
      'warehouse', '20000000-0000-0000-0000-0000000086ff'
    )) -> 'rows'
  ),
  0,
  'an unknown warehouse returns no rows'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000008602","role":"authenticated"}', true);
select throws_ok(
  format(
    'select public.report_stock_analytics(%L::jsonb)',
    current_setting('test.filters')::jsonb
  ),
  'P0001',
  'sana_company: Company is mandatory',
  'a user outside the organization cannot read the company'
);

select * from finish();
rollback;
