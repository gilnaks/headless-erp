begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000045a1', 'warehouse-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000045a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Warehouse Org","slug":"warehouse-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000045a1', current_setting('test.org')::uuid, 'Stores Co', 'SC');

select ok(
  exists (
    select 1 from public.warehouse_type
    where org_id = current_setting('test.org')::uuid and name = 'Transit'
  ),
  'an organization insert seeds the Transit warehouse type'
);
select ok(
  exists (
    select 1 from public.warehouse
    where company_id = '20000000-0000-0000-0000-0000000045a1'
      and warehouse_name = 'All Warehouses'
      and parent_id is null
      and is_group
  ),
  'a company insert seeds a group root named All Warehouses'
);
select ok(
  exists (
    select 1 from public.warehouse child
    join public.warehouse root on root.id = child.parent_id
    where child.company_id = '20000000-0000-0000-0000-0000000045a1'
      and child.warehouse_name = 'Stores'
      and child.is_group = false
      and root.warehouse_name = 'All Warehouses'
  ),
  'Stores is a non-group child of All Warehouses'
);
select ok(
  exists (
    select 1 from public.companies c
    join public.warehouse w on w.id = c.default_warehouse_id
    where c.id = '20000000-0000-0000-0000-0000000045a1'
      and w.warehouse_name = 'Stores'
      and w.is_group = false
      and c.default_in_transit_warehouse_id is null
  ),
  'the company default warehouse is Stores and in-transit stays empty'
);
select ok(
  exists (
    select 1 from public.warehouse w
    join public.warehouse_type t on t.id = w.warehouse_type_id
    where w.company_id = '20000000-0000-0000-0000-0000000045a1'
      and w.warehouse_name = 'Goods In Transit'
      and t.name = 'Transit'
  ),
  'Goods In Transit uses the Transit warehouse type'
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000045a2', current_setting('test.org')::uuid, 'Other Co', 'OC');

-- System Manager can read Warehouse. Only Item Manager may create or change one.
reset role;
update public.org_members
   set roles = '{System Manager,Item Manager}'
 where user_id = '00000000-0000-0000-0000-0000000045a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000045a1","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.warehouse (org_id, warehouse_name, company_id, parent_id)
    values (
      current_setting('test.org')::uuid,
      'Cold Room',
      '20000000-0000-0000-0000-0000000045a1',
      (select id from public.warehouse
        where company_id = '20000000-0000-0000-0000-0000000045a1'
          and warehouse_name = 'All Warehouses')
    )$$,
  'Item Manager can add a child under All Warehouses'
);
select throws_ok(
  $$insert into public.warehouse (org_id, warehouse_name, company_id, parent_id)
    values (
      current_setting('test.org')::uuid,
      'Orphan Bin',
      '20000000-0000-0000-0000-0000000045a2',
      (select id from public.warehouse
        where company_id = '20000000-0000-0000-0000-0000000045a1'
          and warehouse_name = 'All Warehouses')
    )$$,
  'P0001',
  'warehouse_parent: Parent warehouse must belong to the same company',
  'a parent from another company is rejected'
);
select throws_ok(
  $$update public.warehouse set account_id = (
       select id from public.account
       where company_id = '20000000-0000-0000-0000-0000000045a1'
         and account_type = 'Receivable'
         and is_group = false
       limit 1
     )
     where company_id = '20000000-0000-0000-0000-0000000045a1'
       and warehouse_name = 'Stores'$$,
  'P0001',
  'warehouse_account: Warehouse account must be a Stock ledger of the same company',
  'a receivable account is rejected'
);

select * from finish();
rollback;
