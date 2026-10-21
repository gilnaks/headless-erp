begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007401', 'stock74@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000007402', 'stock74-other@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007401","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Stock GL Co", "slug": "stock-74", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock GL Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);

reset role;
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
select set_config('test.wip', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Work In Progress'
), true);
select set_config('test.fg', (
  select w.id::text from public.warehouse w
   where w.org_id = current_setting('test.org')::uuid and w.warehouse_name = 'Finished Goods'
), true);
select set_config('test.company', (
  select w.company_id::text from public.warehouse w where w.id = current_setting('test.wh')::uuid
), true);
select set_config('test.inv', (
  select c.default_inventory_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
select set_config('test.adj', (
  select c.stock_adjustment_account_id::text from public.companies c
   where c.id = current_setting('test.company')::uuid
), true);
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000074c1', current_setting('test.org')::uuid, 'WIP Stock',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Stock'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_type)
  select '20000000-0000-0000-0000-0000000074c9', current_setting('test.org')::uuid, 'Temporary Opening',
         current_setting('test.company')::uuid, a.parent_id, 'Asset', 'Temporary'
    from public.account a
   where a.id = current_setting('test.inv')::uuid;
select set_config('test.temp', '20000000-0000-0000-0000-0000000074c9', true);
update public.warehouse
   set account_id = '20000000-0000-0000-0000-0000000074c1'
 where org_id = current_setting('test.org')::uuid and warehouse_name = 'Work In Progress';

insert into public.item (id, org_id, item_code, item_name, item_group_id, stock_uom_id) values
  ('20000000-0000-0000-0000-0000000074d1', current_setting('test.org')::uuid, 'REC-74', 'REC-74', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000074d2', current_setting('test.org')::uuid, 'OPEN-74', 'OPEN-74', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000074d3', current_setting('test.org')::uuid, 'XFER-74', 'XFER-74', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000074d4', current_setting('test.org')::uuid, 'SAME-74', 'SAME-74', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000074d5', current_setting('test.org')::uuid, 'OFF-74', 'OFF-74', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000074d6', current_setting('test.org')::uuid, 'BACK-74', 'BACK-74', current_setting('test.group')::uuid, current_setting('test.nos')::uuid),
  ('20000000-0000-0000-0000-0000000074d7', current_setting('test.org')::uuid, 'CAN-74', 'CAN-74', current_setting('test.group')::uuid, current_setting('test.nos')::uuid);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007401","role":"authenticated"}', true);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d1',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-02-01',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074a1', 'voucher_no', 'REC-1'
  )));
end
$$;

select is(
  (
    select (select g.debit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074a1'
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 50
       and (select g.credit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074a1'
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 50
  ),
  true,
  'a receipt debits inventory and credits stock adjustment'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d1',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', -4,
    'posting_date', '2026-02-02',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074a2', 'voucher_no', 'ISS-1'
  )));
end
$$;

select is(
  (
    select (select g.credit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074a2'
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 20
       and (select g.debit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074a2'
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 20
  ),
  true,
  'an issue credits inventory and debits stock adjustment'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d2',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5, 'is_opening', true,
    'posting_date', '2026-01-02',
    'voucher_type', 'Stock Reconciliation', 'voucher_id', '10000000-0000-0000-0000-0000000074b1', 'voucher_no', 'OPEN-1'
  )));
end
$$;

select is(
  (
    select (select g.credit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074b1'
               and g.account_id = current_setting('test.temp')::uuid and not g.is_cancelled) = 50
       and (select count(*) from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074b1'
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 0
  ),
  true,
  'an opening receipt credits temporary opening'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d3',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-02-03',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074c2', 'voucher_no', 'XIN-1'
  )));
  perform app.make_sl_entries(jsonb_build_array(
    jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000074d3',
      'warehouse_id', current_setting('test.wh'),
      'actual_qty', -10,
      'posting_date', '2026-02-04',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074c3', 'voucher_no', 'XFER-1'
    ),
    jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000074d3',
      'warehouse_id', current_setting('test.wip'),
      'actual_qty', 10, 'incoming_rate', 5,
      'posting_date', '2026-02-04',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074c3', 'voucher_no', 'XFER-1'
    )
  ));
end
$$;

select is(
  (
    select (select g.debit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074c3'
               and g.account_id = '20000000-0000-0000-0000-0000000074c1' and not g.is_cancelled) = 50
       and (select g.credit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074c3'
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 50
       and (select count(*) from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074c3'
               and g.account_id = current_setting('test.adj')::uuid and not g.is_cancelled) = 0
  ),
  true,
  'a transfer debits the target warehouse account and credits the source'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d4',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-02-05',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074e1', 'voucher_no', 'SIN-1'
  )));
  perform app.make_sl_entries(jsonb_build_array(
    jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000074d4',
      'warehouse_id', current_setting('test.wh'),
      'actual_qty', -10,
      'posting_date', '2026-02-06',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074e2', 'voucher_no', 'SAME-1'
    ),
    jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000074d4',
      'warehouse_id', current_setting('test.fg'),
      'actual_qty', 10, 'incoming_rate', 5,
      'posting_date', '2026-02-06',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074e2', 'voucher_no', 'SAME-1'
    )
  ));
end
$$;

select is(
  (select count(*) from public.gl_entry g
    where g.voucher_id = '10000000-0000-0000-0000-0000000074e2' and not g.is_cancelled),
  0::bigint,
  'a transfer whose warehouses share an account posts no GL'
);

select set_config(
  'test.off_company',
  public.create_company(jsonb_build_object(
    'org_id', current_setting('test.org'),
    'company_name', 'Stock GL Off',
    'abbr', 'OFF',
    'default_currency', 'PHP',
    'country', 'Philippines',
    'enable_perpetual_inventory', false
  )) ->> 'id',
  true
);
select set_config('test.off_wh', (
  select w.id::text from public.warehouse w
   where w.company_id = current_setting('test.off_company')::uuid and w.warehouse_name = 'Stores'
), true);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d5',
    'warehouse_id', current_setting('test.off_wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-02-07',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074f1', 'voucher_no', 'OFF-1'
  )));
end
$$;

select is(
  (
    select (select count(*) from public.stock_ledger_entry s
             where s.voucher_id = '10000000-0000-0000-0000-0000000074f1' and not s.is_cancelled) = 1
       and (select count(*) from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074f1') = 0
  ),
  true,
  'perpetual inventory off still posts the stock ledger and posts no GL'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d6',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 10,
    'posting_date', '2026-03-02',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074a3', 'voucher_no', 'BACK-IN'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d6',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', -4,
    'posting_date', '2026-03-03',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074a4', 'voucher_no', 'BACK-OUT'
  )));
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d6',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 2,
    'posting_date', '2026-03-01',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074a5', 'voucher_no', 'BACK-EARLY'
  )));
end
$$;

select is(
  (
    select (select g.credit from public.gl_entry g
             where g.voucher_id = '10000000-0000-0000-0000-0000000074a4'
               and g.account_id = current_setting('test.inv')::uuid and not g.is_cancelled) = 8
       and exists (
         select 1 from public.gl_entry g
          where g.voucher_id = '10000000-0000-0000-0000-0000000074a4'
            and g.is_cancelled and g.credit = 40
       )
  ),
  true,
  'a backdated receipt rebuilds the later issue and cancels the previous stock GL'
);

do $$
begin
  perform app.make_sl_entries(jsonb_build_array(jsonb_build_object(
    'item_id', '20000000-0000-0000-0000-0000000074d7',
    'warehouse_id', current_setting('test.wh'),
    'actual_qty', 10, 'incoming_rate', 5,
    'posting_date', '2026-02-08',
    'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074a6', 'voucher_no', 'CAN-1'
  )));
  perform app.make_sl_entries(
    jsonb_build_array(jsonb_build_object(
      'item_id', '20000000-0000-0000-0000-0000000074d7',
      'warehouse_id', current_setting('test.wh'),
      'actual_qty', -10,
      'posting_date', '2026-02-08',
      'voucher_type', 'Stock Entry', 'voucher_id', '10000000-0000-0000-0000-0000000074a6', 'voucher_no', 'CAN-1'
    )),
    '{"is_cancelled": true}'::jsonb
  );
end
$$;

select is(
  (select count(*) from public.gl_entry g
    where g.voucher_id = '10000000-0000-0000-0000-0000000074a6' and not g.is_cancelled),
  0::bigint,
  'cancelling the receipt leaves no open GL'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007402","role":"authenticated"}', true);
select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Stock GL Other", "slug": "stock-74-b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Stock GL Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select is(
  (select count(*) from public.gl_entry where org_id = current_setting('test.org')::uuid),
  0::bigint,
  'another organization cannot see the rows'
);

select * from finish();
rollback;
