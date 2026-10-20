begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007701', 'stock77@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007702', 'stock77-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007701","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Material Request Co", "slug": "stock-77", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Material Request Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
update public.org_members
   set roles = roles || array['Stock Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007701';
select set_config('test.group', (
  select g.id::text from public.item_group g
   where g.org_id = current_setting('test.org')::uuid and g.item_group_name = 'Products'
), true);
select set_config('test.nos', (
  select u.id::text from public.uom u
   where u.org_id = current_setting('test.org')::uuid and u.uom_name = 'Nos'
), true);
select set_config('test.wh', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Stores'
), true);
select set_config('test.fg', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Finished Goods'
), true);
select set_config('test.company', (
  select w.company_id::text from public.warehouse w where w.id = current_setting('test.wh')::uuid
), true);
insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  ('20000000-0000-0000-0000-0000000077d1', current_setting('test.org')::uuid, 'PUR-77', 'PUR-77', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000077d2', current_setting('test.org')::uuid, 'ISSUE-77', 'ISSUE-77', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000077d3', current_setting('test.org')::uuid, 'XFER-77', 'XFER-77', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000077d4', current_setting('test.org')::uuid, 'CUST-77', 'CUST-77', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000077d5', current_setting('test.org')::uuid, 'OVER-77', 'OVER-77', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);
select set_config('test.receipt_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.purpose = 'Material Receipt'
), true);
select set_config('test.issue_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.purpose = 'Material Issue'
), true);
select set_config('test.transfer_type', (
  select t.id::text from public.stock_entry_type t
   where t.org_id = current_setting('test.org')::uuid and t.purpose = 'Material Transfer'
), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007701","role":"authenticated"}', true);

select set_config('test.purchase', (
  public.save_doc('Material Request', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'material_request_type', 'Purchase',
    'transaction_date', '2026-04-01',
    'schedule_date', '2026-04-15',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d1',
      'qty', 10,
      'warehouse_id', current_setting('test.wh')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.purchase_submitted', public.submit_doc('Material Request', current_setting('test.purchase')::uuid)::text, true);

select is(
  (
    select (select r.status = 'Pending' and r.per_ordered = 0 and r.name like 'MAT-MR-2026-%' and r.docstatus = 1
              from public.material_request r where r.id = current_setting('test.purchase')::uuid)
       and (select b.indented_qty = 10 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000077d1'
               and b.warehouse_id = current_setting('test.wh')::uuid)
       and (select count(*) = 0 from public.stock_ledger_entry s
             where s.voucher_id = current_setting('test.purchase')::uuid)
  ),
  true,
  'a purchase request is pending, indents the bin, and posts no stock ledger'
);

select set_config('test.issue_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-04-02',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d2',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.issue_in_submitted', public.submit_doc('Stock Entry', current_setting('test.issue_in')::uuid)::text, true);
select set_config('test.issue', (
  public.save_doc('Material Request', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'material_request_type', 'Material Issue',
    'transaction_date', '2026-04-03',
    'schedule_date', '2026-04-15',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d2',
      'qty', 10,
      'warehouse_id', current_setting('test.wh')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.issue_submitted', public.submit_doc('Material Request', current_setting('test.issue')::uuid)::text, true);
select set_config('test.issue_se', (
  public.make_stock_entry_from_material_request(current_setting('test.issue')::uuid) ->> 'id'
), true);
select set_config('test.issue_se_submitted', public.submit_doc('Stock Entry', current_setting('test.issue_se')::uuid)::text, true);

select is(
  (
    select (select r.status = 'Issued' and r.per_ordered = 100
              from public.material_request r where r.id = current_setting('test.issue')::uuid)
       and (select i.ordered_qty = 10 from public.material_request_item i
             where i.parent_id = current_setting('test.issue')::uuid)
       and (select b.indented_qty = 0 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000077d2'
               and b.warehouse_id = current_setting('test.wh')::uuid)
  ),
  true,
  'an issue of 10 fulfilled by a stock entry is Issued and the indent returns to zero'
);

select set_config('test.issue_se_cancelled', public.cancel_doc('Stock Entry', current_setting('test.issue_se')::uuid)::text, true);

select is(
  (
    select (select r.status = 'Pending' and r.per_ordered = 0
              from public.material_request r where r.id = current_setting('test.issue')::uuid)
       and (select i.ordered_qty = 0 from public.material_request_item i
             where i.parent_id = current_setting('test.issue')::uuid)
       and (select b.indented_qty = -10 and b.actual_qty = 10 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000077d2'
               and b.warehouse_id = current_setting('test.wh')::uuid)
  ),
  true,
  'cancelling the issue stock entry returns the request to Pending'
);

select set_config('test.xfer_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-04-04',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d3',
      'qty', 10, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.xfer_in_submitted', public.submit_doc('Stock Entry', current_setting('test.xfer_in')::uuid)::text, true);
select set_config('test.transfer', (
  public.save_doc('Material Request', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'material_request_type', 'Material Transfer',
    'transaction_date', '2026-04-05',
    'schedule_date', '2026-04-15',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d3',
      'qty', 10,
      'warehouse_id', current_setting('test.fg')::uuid,
      'from_warehouse_id', current_setting('test.wh')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.transfer_submitted', public.submit_doc('Material Request', current_setting('test.transfer')::uuid)::text, true);
select set_config('test.transfer_row', (
  select i.id::text from public.material_request_item i
   where i.parent_id = current_setting('test.transfer')::uuid
), true);
select set_config('test.transfer_se', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.transfer_type')::uuid,
    'posting_date', '2026-04-06',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d3',
      'qty', 5,
      'uom_id', current_setting('test.nos')::uuid,
      's_warehouse_id', current_setting('test.wh')::uuid,
      't_warehouse_id', current_setting('test.fg')::uuid,
      'material_request_id', current_setting('test.transfer')::uuid,
      'material_request_item', current_setting('test.transfer_row')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.transfer_se_submitted', public.submit_doc('Stock Entry', current_setting('test.transfer_se')::uuid)::text, true);

select is(
  (
    select (select r.status = 'Partially Received' and r.per_ordered = 50
              from public.material_request r where r.id = current_setting('test.transfer')::uuid)
       and (select i.ordered_qty = 5 from public.material_request_item i
             where i.id = current_setting('test.transfer_row')::uuid)
  ),
  true,
  'a transfer fulfilled halfway is Partially Received at 50 percent'
);

select set_config('test.transfer_more', (
  public.make_stock_entry_from_material_request(current_setting('test.transfer')::uuid) ->> 'id'
), true);
select set_config('test.transfer_stopped', public.material_request_set_status(current_setting('test.transfer')::uuid, 'Stopped')::text, true);
select throws_ok(
  format($$select public.submit_doc('Stock Entry', %L::uuid)$$, current_setting('test.transfer_more')),
  'P0001',
  (
    select format('mr_stopped: Material Request %s is cancelled or stopped', r.name)
      from public.material_request r
     where r.id = current_setting('test.transfer')::uuid
  ),
  'a stopped request blocks the stock entry'
);

select set_config('test.customer', (
  public.save_doc('Material Request', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'material_request_type', 'Customer Provided',
    'transaction_date', '2026-04-07',
    'schedule_date', '2026-04-15',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d4',
      'qty', 4,
      'warehouse_id', current_setting('test.wh')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.customer_submitted', public.submit_doc('Material Request', current_setting('test.customer')::uuid)::text, true);
select set_config('test.customer_se', (
  public.make_stock_entry_from_material_request(current_setting('test.customer')::uuid) ->> 'id'
), true);
select set_config('test.customer_se_submitted', public.submit_doc('Stock Entry', current_setting('test.customer_se')::uuid)::text, true);

select is(
  (
    select (select r.status = 'Received' and r.per_ordered = 100
              from public.material_request r where r.id = current_setting('test.customer')::uuid)
       and (select d.allow_zero_valuation_rate and d.amount = 0 and e.purpose = 'Material Receipt'
              from public.stock_entry_detail d
              join public.stock_entry e on e.id = d.parent_id
             where e.id = current_setting('test.customer_se')::uuid)
       and (select b.actual_qty = 4 and b.indented_qty = 0 from public.bin b
             where b.item_id = '20000000-0000-0000-0000-0000000077d4'
               and b.warehouse_id = current_setting('test.wh')::uuid)
  ),
  true,
  'a zero-rate customer provided receipt reaches Received'
);

select throws_ok(
  $$select public.save_doc('Material Request', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'material_request_type', 'Subcontracting',
    'transaction_date', '2026-04-08',
    'schedule_date', '2026-04-15',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d1',
      'qty', 1,
      'warehouse_id', current_setting('test.wh')::uuid
    ))
  ))$$,
  'P0001',
  'mr_type: Subcontracting is not available',
  'subcontracting is rejected'
);

select set_config('test.over_in', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.receipt_type')::uuid,
    'posting_date', '2026-04-09',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d5',
      'qty', 20, 'basic_rate', 5,
      't_warehouse_id', current_setting('test.wh')::uuid,
      'uom_id', current_setting('test.nos')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.over_in_submitted', public.submit_doc('Stock Entry', current_setting('test.over_in')::uuid)::text, true);
select set_config('test.over', (
  public.save_doc('Material Request', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'material_request_type', 'Material Issue',
    'transaction_date', '2026-04-10',
    'schedule_date', '2026-04-15',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d5',
      'qty', 10,
      'warehouse_id', current_setting('test.wh')::uuid
    ))
  )) ->> 'id'
), true);
select set_config('test.over_submitted', public.submit_doc('Material Request', current_setting('test.over')::uuid)::text, true);
select set_config('test.over_row', (
  select i.id::text from public.material_request_item i
   where i.parent_id = current_setting('test.over')::uuid
), true);
select set_config('test.over_se', (
  public.save_doc('Stock Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'stock_entry_type_id', current_setting('test.issue_type')::uuid,
    'posting_date', '2026-04-11',
    'items', jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000077d5',
      'qty', 11,
      'uom_id', current_setting('test.nos')::uuid,
      's_warehouse_id', current_setting('test.wh')::uuid,
      'material_request_id', current_setting('test.over')::uuid,
      'material_request_item', current_setting('test.over_row')::uuid
    ))
  )) ->> 'id'
), true);
select throws_ok(
  format($$select public.submit_doc('Stock Entry', %L::uuid)$$, current_setting('test.over_se')),
  'P0001',
  (
    select format(
      'mr_qty: The total Issue / Transfer quantity 11 in Material Request %s cannot be greater than requested quantity 10 for Item OVER-77',
      r.name
    )
      from public.material_request r
     where r.id = current_setting('test.over')::uuid
  ),
  'a stock entry above the requested qty is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007702","role":"authenticated"}', true);
select is(
  (select count(*) = 0 from public.material_request),
  true,
  'a user outside the organization cannot read the material request'
);

select * from finish();
rollback;
