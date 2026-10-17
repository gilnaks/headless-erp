begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000055a1', 'customer-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000055a2', 'customer-sales@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000055a3', 'customer-stock@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000055a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Customer Org","slug":"customer-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000055a2', '{Sales User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000055a3', '{Stock User}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000055a1","role":"authenticated"}', true);
insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000055c1', current_setting('test.org')::uuid, 'Customer Co', 'CC');

reset role;
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_currency, account_type)
values
  (
    '20000000-0000-0000-0000-0000000055e1',
    current_setting('test.org')::uuid,
    'Customer Receivable',
    '20000000-0000-0000-0000-0000000055c1',
    (
      select a.parent_id from public.account a
       where a.company_id = '20000000-0000-0000-0000-0000000055c1' and a.account_type = 'Receivable'
       limit 1
    ),
    'Asset', 'XOF', 'Receivable'
  ),
  (
    '20000000-0000-0000-0000-0000000055e2',
    current_setting('test.org')::uuid,
    'Group Receivable',
    '20000000-0000-0000-0000-0000000055c1',
    (
      select a.parent_id from public.account a
       where a.company_id = '20000000-0000-0000-0000-0000000055c1' and a.account_type = 'Receivable'
       limit 1
    ),
    'Asset', 'XOF', 'Receivable'
  );
insert into public.sales_person (org_id, sales_person_name, enabled)
values (current_setting('test.org')::uuid, 'Closed Rep', false);
update public.customer_group g
   set default_price_list_id = (
     select p.id from public.price_list p
      where p.org_id = g.org_id and p.name = 'Standard Selling'
   )
 where g.org_id = current_setting('test.org')::uuid
   and g.customer_group_name = 'Individual';

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000055a2","role":"authenticated"}', true);

insert into public.customer (id, org_id, customer_name) values
  ('20000000-0000-0000-0000-0000000055d1', current_setting('test.org')::uuid, '  Acme  ');
insert into public.customer (id, org_id, customer_name) values
  ('20000000-0000-0000-0000-0000000055d2', current_setting('test.org')::uuid, 'Acme');
insert into public.customer (id, org_id, customer_name) values
  ('20000000-0000-0000-0000-0000000055d3', current_setting('test.org')::uuid, 'Acme - 5');
insert into public.customer (id, org_id, customer_name) values
  ('20000000-0000-0000-0000-0000000055d4', current_setting('test.org')::uuid, 'Acme');

select is(
  (
    select c.name from public.customer c
     where c.id = '20000000-0000-0000-0000-0000000055d1'
  ),
  'Acme',
  'the name is the trimmed customer name'
);
select is(
  (
    select c.name from public.customer c
     where c.id = '20000000-0000-0000-0000-0000000055d2'
  ),
  'Acme - 2',
  'a duplicate becomes Name - 2'
);
select is(
  (
    select c.name from public.customer c
     where c.id = '20000000-0000-0000-0000-0000000055d4'
  ),
  'Acme - 6',
  'an existing Name - 5 makes the next Name - 6'
);

select throws_ok(
  $$update public.customer set customer_group_id = (
      select g.id from public.customer_group g
       where g.org_id = current_setting('test.org')::uuid and g.customer_group_name = 'All Customer Groups'
    )
    where id = '20000000-0000-0000-0000-0000000055d1'$$,
  'P0001',
  'customer_group_leaf: Cannot select a group type Customer Group',
  'a group customer group is rejected'
);
select throws_ok(
  $$update public.customer set default_price_list_id = (
      select p.id from public.price_list p
       where p.org_id = current_setting('test.org')::uuid and p.name = 'Standard Buying'
    )
    where id = '20000000-0000-0000-0000-0000000055d1'$$,
  'P0001',
  'customer_price_list: Default price list must be a selling list',
  'a buying price list is rejected'
);

update public.customer
   set customer_group_id = (
     select g.id from public.customer_group g
      where g.org_id = current_setting('test.org')::uuid and g.customer_group_name = 'Individual'
   )
 where id = '20000000-0000-0000-0000-0000000055d1';

select lives_ok(
  $$insert into public.customer_party_account (org_id, parent_id, idx, company_id, account_id)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000055d1',
      1,
      '20000000-0000-0000-0000-0000000055c1',
      '20000000-0000-0000-0000-0000000055e1'
    )$$,
  'a receivable account is kept'
);
select throws_ok(
  $$insert into public.customer_party_account (org_id, parent_id, idx, company_id, account_id)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000055d2',
      1,
      '20000000-0000-0000-0000-0000000055c1',
      (select a.id from public.account a
        where a.company_id = '20000000-0000-0000-0000-0000000055c1' and a.account_type = 'Cash'
        limit 1)
    )$$,
  'P0001',
  'party_account_type: Row 1: Account must be a Receivable account',
  'another account type is rejected'
);

select is(
  public.get_party_account(
    'Customer',
    '20000000-0000-0000-0000-0000000055d1',
    '20000000-0000-0000-0000-0000000055c1'
  )::text,
  '20000000-0000-0000-0000-0000000055e1',
  'the customer party account wins'
);
delete from public.customer_party_account where parent_id = '20000000-0000-0000-0000-0000000055d1';
reset role;
insert into public.customer_group_party_account (org_id, parent_id, idx, company_id, account_id)
  select current_setting('test.org')::uuid, g.id, 1, '20000000-0000-0000-0000-0000000055c1',
       '20000000-0000-0000-0000-0000000055e2'
  from public.customer_group g
 where g.org_id = current_setting('test.org')::uuid and g.customer_group_name = 'Individual';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000055a2","role":"authenticated"}', true);
select is(
  public.get_party_account(
    'Customer',
    '20000000-0000-0000-0000-0000000055d1',
    '20000000-0000-0000-0000-0000000055c1'
  )::text,
  '20000000-0000-0000-0000-0000000055e2',
  'the customer group account is next'
);
reset role;
delete from public.customer_group_party_account
 where account_id = '20000000-0000-0000-0000-0000000055e2';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000055a2","role":"authenticated"}', true);
select is(
  public.get_party_account(
    'Customer',
    '20000000-0000-0000-0000-0000000055d1',
    '20000000-0000-0000-0000-0000000055c1'
  )::text,
  (
    select c.default_receivable_account_id::text
      from public.companies c
     where c.id = '20000000-0000-0000-0000-0000000055c1'
  ),
  'the company receivable is the fallback'
);

do $$ begin
  perform public.get_customer_group_details('20000000-0000-0000-0000-0000000055d1');
end $$;
select is(
  (
    select c.default_price_list_id from public.customer c
     where c.id = '20000000-0000-0000-0000-0000000055d1'
  ),
  (
    select g.default_price_list_id from public.customer_group g
     where g.org_id = current_setting('test.org')::uuid and g.customer_group_name = 'Individual'
  ),
  'group details copy the selling price list'
);

insert into public.customer_sales_team (org_id, parent_id, idx, sales_person_id, allocated_percentage)
  select current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000055d1', n.idx, s.id, 40
  from public.sales_person s
  cross join (values (1), (2)) as n(idx)
 where s.org_id = current_setting('test.org')::uuid and s.sales_person_name = 'Sales Team';
select throws_ok(
  $$set constraints customer_sales_team_refresh immediate$$,
  'P0001',
  'sales_team_total: Total contribution percentage should be equal to 100',
  'a sales team that does not total 100 is rejected'
);
delete from public.customer_sales_team where parent_id = '20000000-0000-0000-0000-0000000055d1';

insert into public.customer_sales_team (org_id, parent_id, idx, sales_person_id, allocated_percentage)
  select current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000055d1', 1, s.id, 100
  from public.sales_person s
 where s.org_id = current_setting('test.org')::uuid and s.sales_person_name = 'Closed Rep';
select throws_ok(
  $$set constraints customer_sales_team_refresh immediate$$,
  'P0001',
  'sales_person_disabled: Sales Person Closed Rep is disabled',
  'a disabled sales person is rejected'
);
delete from public.customer_sales_team where parent_id = '20000000-0000-0000-0000-0000000055d1';

select is(
  (
    select c.name from public.customer c
     where c.id = '20000000-0000-0000-0000-0000000055d1'
  ),
  'Acme',
  'Sales User can read a customer'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000055a3","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.customer (org_id, customer_name)
    values (current_setting('test.org')::uuid, 'Stock Customer')$$,
  '42501',
  null,
  'Stock User cannot create a customer'
);

reset role;
update public.customer set customer_group_id = null
 where org_id = current_setting('test.org')::uuid;
set constraints customer_sales_team_refresh deferred;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
