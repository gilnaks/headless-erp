begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000044a1', 'cost-center-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000044a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Cost Center Org","slug":"cost-center-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000044a1', current_setting('test.org')::uuid, 'Ledger Co', 'LC');

select ok(
  exists (
    select 1 from public.cost_center
    where company_id = '20000000-0000-0000-0000-0000000044a1'
      and cost_center_name = 'Ledger Co'
      and parent_id is null
      and is_group
  ),
  'a company insert seeds a group root named after the company'
);
select ok(
  exists (
    select 1 from public.cost_center child
    join public.cost_center root on root.id = child.parent_id
    where child.company_id = '20000000-0000-0000-0000-0000000044a1'
      and child.cost_center_name = 'Main'
      and child.is_group = false
      and root.cost_center_name = 'Ledger Co'
  ),
  'Main is a non-group child of the company root'
);
select ok(
  exists (
    select 1 from public.companies c
    join public.cost_center a on a.id = c.cost_center_id
    where c.id = '20000000-0000-0000-0000-0000000044a1'
      and a.cost_center_name = 'Main'
      and a.is_group = false
  ),
  'the company cost center points at Main'
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000044a2', current_setting('test.org')::uuid, 'Other Co', 'OC');

-- System Manager can read Cost Center. Only Accounts Manager may create or change one.
reset role;
update public.org_members
   set roles = '{System Manager,Accounts Manager}'
 where user_id = '00000000-0000-0000-0000-0000000044a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000044a1","role":"authenticated"}', true);

select throws_ok(
  $$update public.cost_center set company_id = '20000000-0000-0000-0000-0000000044a2'
     where id = (
       select id from public.cost_center
       where company_id = '20000000-0000-0000-0000-0000000044a1' and parent_id is null
       limit 1
     )$$,
  'P0001',
  'cost_center_company: Company cannot be changed for an existing Cost Center',
  'company cannot change after insert'
);
select lives_ok(
  $$insert into public.cost_center (org_id, cost_center_name, company_id, parent_id)
    values (
      current_setting('test.org')::uuid,
      'Headless Workshop',
      '20000000-0000-0000-0000-0000000044a1',
      (select id from public.cost_center
        where company_id = '20000000-0000-0000-0000-0000000044a1'
          and cost_center_name = 'Ledger Co')
    )$$,
  'Accounts Manager can add a child under the company root'
);
select throws_ok(
  $$insert into public.cost_center (org_id, cost_center_name, company_id, parent_id)
    values (
      current_setting('test.org')::uuid,
      'Headless Orphan',
      '20000000-0000-0000-0000-0000000044a2',
      (select id from public.cost_center
        where company_id = '20000000-0000-0000-0000-0000000044a1'
          and cost_center_name = 'Ledger Co')
    )$$,
  'P0001',
  'cost_center_parent: Parent cost center must belong to the same company',
  'a parent from another company is rejected'
);

select * from finish();
rollback;
