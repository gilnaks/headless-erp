begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007201', 'stock72@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007202', 'stock72-sales@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007203', 'stock72-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007201","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock Settings Co", "slug": "stock-72", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Settings Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-000000007202', '{Sales User}');

select is(
  (
    select item_naming_by = 'Item Code'
       and valuation_method = 'FIFO'
       and allow_negative_stock = false
       and auto_indent
       and auto_insert_price_list_rate_if_missing
       and update_price_list_based_on = 'Rate'
       and over_delivery_receipt_allowance is null
       and mr_qty_allowance is null
       and over_picking_allowance is null
       and stock_frozen_upto is null
       and stock_frozen_upto_days is null
       and not enable_stock_reservation
       and auto_create_serial_and_batch_bundle_for_outward
       and pick_serial_and_batch_based_on = 'FIFO'
       and use_serial_batch_fields
       and allow_existing_serial_no
       and set_qty_in_transactions_based_on_serial_no_input
       and show_barcode_field
       and clean_description_html
       and not do_not_use_batchwise_valuation
       and not allow_to_edit_stock_uom_qty_for_sales
       and not validate_material_transfer_warehouses
       and action_if_quality_inspection_is_not_submitted = 'Stop'
       and exists (
         select 1 from public.uom u
          where u.id = s.stock_uom_id and u.org_id = s.org_id and u.uom_name = 'Nos'
       )
      from public.stock_settings s
     where s.org_id = current_setting('test.org')::uuid
  ),
  true,
  'a new organization has the C4 stock settings defaults'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007202","role":"authenticated"}', true);
update public.stock_settings set allow_negative_stock = true where org_id = current_setting('test.org')::uuid;
select is(
  (select allow_negative_stock from public.stock_settings where org_id = current_setting('test.org')::uuid),
  false,
  'Sales User cannot write stock settings'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007201","role":"authenticated"}', true);
update public.org_members
   set roles = roles || array['Stock Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007201';
update public.stock_settings set allow_negative_stock = true where org_id = current_setting('test.org')::uuid;
select is(
  (select allow_negative_stock from public.stock_settings where org_id = current_setting('test.org')::uuid),
  true,
  'Stock Manager can change allow negative stock'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007203","role":"authenticated"}', true);
select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Stock Settings Other", "slug": "stock-72-b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock Settings Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select is(
  (select count(*) from public.stock_settings where org_id = current_setting('test.org')::uuid),
  0::bigint,
  'another organization cannot see the row'
);

select * from finish();
rollback;
