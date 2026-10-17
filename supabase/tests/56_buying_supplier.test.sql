begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000056a1', 'supplier-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000056a2', 'supplier-purchase@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000056a3', 'supplier-reader@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Supplier Org","slug":"supplier-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000056a2', '{Purchase Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000056a3', '{Purchase User}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a1","role":"authenticated"}', true);
insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000056c1', current_setting('test.org')::uuid, 'Supplier Co', 'SC');

reset role;
insert into public.account (id, org_id, account_name, company_id, parent_id, root_type, account_currency, account_type)
values
  (
    '20000000-0000-0000-0000-0000000056e1',
    current_setting('test.org')::uuid,
    'Supplier Payable',
    '20000000-0000-0000-0000-0000000056c1',
    (
      select a.parent_id from public.account a
       where a.company_id = '20000000-0000-0000-0000-0000000056c1' and a.account_type = 'Payable'
       limit 1
    ),
    'Liability', 'XOF', 'Payable'
  ),
  (
    '20000000-0000-0000-0000-0000000056e2',
    current_setting('test.org')::uuid,
    'Group Payable',
    '20000000-0000-0000-0000-0000000056c1',
    (
      select a.parent_id from public.account a
       where a.company_id = '20000000-0000-0000-0000-0000000056c1' and a.account_type = 'Payable'
       limit 1
    ),
    'Liability', 'XOF', 'Payable'
  );
select set_config(
  'test.cash',
  (
    select a.id::text from public.account a
     where a.company_id = '20000000-0000-0000-0000-0000000056c1' and a.account_type = 'Cash'
     limit 1
  ),
  true
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a2","role":"authenticated"}', true);

insert into public.supplier (id, org_id, supplier_name) values
  ('20000000-0000-0000-0000-0000000056d1', current_setting('test.org')::uuid, '  Acme  ');
select is(
  (
    select s.name from public.supplier s
     where s.id = '20000000-0000-0000-0000-0000000056d1'
  ),
  'Acme',
  'the name is the trimmed supplier name'
);
select throws_ok(
  $$insert into public.supplier (org_id, supplier_name)
    values (current_setting('test.org')::uuid, 'acme')$$,
  '23505',
  null,
  'a duplicate name is rejected'
);
select throws_ok(
  $$update public.supplier set supplier_group_id = (
      select g.id from public.supplier_group g
       where g.org_id = current_setting('test.org')::uuid and g.supplier_group_name = 'All Supplier Groups'
    )
    where id = '20000000-0000-0000-0000-0000000056d1'$$,
  'P0001',
  'supplier_group_leaf: Cannot select a group type Supplier Group',
  'a group supplier group is rejected'
);
select throws_ok(
  $$update public.supplier set default_price_list_id = (
      select p.id from public.price_list p
       where p.org_id = current_setting('test.org')::uuid and p.name = 'Standard Selling'
    )
    where id = '20000000-0000-0000-0000-0000000056d1'$$,
  'P0001',
  'supplier_price_list: Default price list must be a buying list',
  'a selling price list is rejected'
);

update public.supplier
   set supplier_group_id = (
     select g.id from public.supplier_group g
      where g.org_id = current_setting('test.org')::uuid and g.supplier_group_name = 'Services'
   )
 where id = '20000000-0000-0000-0000-0000000056d1';

select lives_ok(
  $$insert into public.supplier_party_account (org_id, parent_id, idx, company_id, account_id)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000056d1',
      1,
      '20000000-0000-0000-0000-0000000056c1',
      '20000000-0000-0000-0000-0000000056e1'
    )$$,
  'a payable account is kept'
);
select throws_ok(
  $$insert into public.supplier_party_account (org_id, parent_id, idx, company_id, account_id)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000056d1',
      2,
      '20000000-0000-0000-0000-0000000056c1',
      current_setting('test.cash')::uuid
    )$$,
  'P0001',
  'party_account_type: Row 2: Account must be a Payable account',
  'another account type is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a3","role":"authenticated"}', true);
select is(
  public.get_party_account(
    'Supplier',
    '20000000-0000-0000-0000-0000000056d1',
    '20000000-0000-0000-0000-0000000056c1'
  )::text,
  '20000000-0000-0000-0000-0000000056e1',
  'the supplier party account wins'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a2","role":"authenticated"}', true);
delete from public.supplier_party_account where parent_id = '20000000-0000-0000-0000-0000000056d1';
insert into public.supplier_group_party_account (org_id, parent_id, idx, company_id, account_id)
  select current_setting('test.org')::uuid, g.id, 1, '20000000-0000-0000-0000-0000000056c1',
         '20000000-0000-0000-0000-0000000056e2'
    from public.supplier_group g
   where g.org_id = current_setting('test.org')::uuid and g.supplier_group_name = 'Services';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a3","role":"authenticated"}', true);
select is(
  public.get_party_account(
    'Supplier',
    '20000000-0000-0000-0000-0000000056d1',
    '20000000-0000-0000-0000-0000000056c1'
  )::text,
  '20000000-0000-0000-0000-0000000056e2',
  'the supplier group account is next'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a2","role":"authenticated"}', true);
delete from public.supplier_group_party_account
 where account_id = '20000000-0000-0000-0000-0000000056e2';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a3","role":"authenticated"}', true);
select is(
  public.get_party_account(
    'Supplier',
    '20000000-0000-0000-0000-0000000056d1',
    '20000000-0000-0000-0000-0000000056c1'
  )::text,
  (
    select c.default_payable_account_id::text
      from public.companies c
     where c.id = '20000000-0000-0000-0000-0000000056c1'
  ),
  'the company payable is the fallback'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a2","role":"authenticated"}', true);
insert into public.supplier_group_party_account (org_id, parent_id, idx, company_id, account_id)
  select current_setting('test.org')::uuid, g.id, 1, '20000000-0000-0000-0000-0000000056c1',
         '20000000-0000-0000-0000-0000000056e2'
    from public.supplier_group g
   where g.org_id = current_setting('test.org')::uuid and g.supplier_group_name = 'Services';
do $$ begin
  perform public.get_supplier_group_details('20000000-0000-0000-0000-0000000056d1');
end $$;
select is(
  (
    select a.account_id::text from public.supplier_party_account a
     where a.parent_id = '20000000-0000-0000-0000-0000000056d1'
  ),
  '20000000-0000-0000-0000-0000000056e2',
  'group details copy the payable account'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000056a3","role":"authenticated"}', true);
select is(
  (
    select s.name from public.supplier s
     where s.id = '20000000-0000-0000-0000-0000000056d1'
  ),
  'Acme',
  'Purchase User can read a supplier'
);
select throws_ok(
  $$insert into public.supplier (org_id, supplier_name)
    values (current_setting('test.org')::uuid, 'Other Supplier')$$,
  '42501',
  null,
  'Purchase User cannot create a supplier'
);

reset role;
update public.supplier set supplier_group_id = null
 where org_id = current_setting('test.org')::uuid;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
