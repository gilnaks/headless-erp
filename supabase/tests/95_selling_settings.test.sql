begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000009501', 'sell95@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000009502', 'sell95-user@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000009503', 'sell95-mgr@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009501","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Selling Settings Co", "slug": "sell-set-95", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Selling Settings Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-000000009502', '{Sales User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-000000009503', '{Sales Manager}');

select set_config('test.buying', (
  select p.id::text from public.price_list p
   where p.org_id = current_setting('test.org')::uuid and p.price_list_name = 'Standard Buying'
), true);

select is(
  (
    select s.cust_master_name = 'Customer Name'
       and s.customer_group_id is null
       and s.territory_id is null
       and s.selling_price_list_id is null
       and s.so_required = 'No'
       and s.dn_required = 'No'
       and s.allow_multiple_items
       and s.sales_update_frequency = 'Each Transaction'
       and s.maintain_same_rate_action = 'Stop'
       and not s.maintain_same_sales_rate
       and not s.skip_delivery_note_for_service_items
       and not s.validate_selling_price
       and not s.allow_negative_rates_for_items
       and not s.enable_proforma_invoice
       and not s.enable_utm
       and s.blanket_order_allowance is null
       and s.role_to_override_stop_action is null
      from public.selling_settings s
     where s.org_id = current_setting('test.org')::uuid
  ),
  true,
  'a new organization has the A20 selling settings defaults'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009502","role":"authenticated"}', true);
update public.selling_settings
   set skip_delivery_note_for_service_items = true
 where org_id = current_setting('test.org')::uuid;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009501","role":"authenticated"}', true);
select is(
  (
    select skip_delivery_note_for_service_items
      from public.selling_settings
     where org_id = current_setting('test.org')::uuid
  ),
  false,
  'Sales User cannot write selling settings'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000009503","role":"authenticated"}', true);
update public.selling_settings
   set skip_delivery_note_for_service_items = true
 where org_id = current_setting('test.org')::uuid;
select is(
  (
    select skip_delivery_note_for_service_items
      from public.selling_settings
     where org_id = current_setting('test.org')::uuid
  ),
  true,
  'Sales Manager can turn on skip delivery for service items'
);

select throws_ok(
  $$update public.selling_settings
       set selling_price_list_id = current_setting('test.buying')::uuid
     where org_id = current_setting('test.org')::uuid$$,
  'P0001',
  'selling_price_list: Default Price List must be a selling price list',
  'a buying price list is rejected'
);

select * from finish();
rollback;
