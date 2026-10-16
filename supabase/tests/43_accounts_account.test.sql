begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000043f1', 'account-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000043f1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Account Org","slug":"account-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000043f1', current_setting('test.org')::uuid, 'Ledger Co', 'LC');

select ok(
  exists (
    select 1 from public.account
    where company_id = '20000000-0000-0000-0000-0000000043f1'
      and account_name = 'Application of Funds (Assets)'
      and is_group
  ),
  'a company insert expands the Standard chart and the first root is a group'
);
select ok(
  exists (
    select 1 from public.companies c
    join public.account a on a.id = c.default_receivable_account_id
    where c.id = '20000000-0000-0000-0000-0000000043f1'
      and a.is_group = false
      and a.account_type = 'Receivable'
  ),
  'the receivable default points at a non-group Receivable account'
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000043f2', current_setting('test.org')::uuid, 'Other Co', 'OC');

-- System Manager can read Account. Only Accounts Manager may create or change one.
reset role;
update public.org_members
   set roles = '{System Manager,Accounts Manager}'
 where user_id = '00000000-0000-0000-0000-0000000043f1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000043f1","role":"authenticated"}', true);

select throws_ok(
  $$update public.account set company_id = '20000000-0000-0000-0000-0000000043f2'
     where id = (
       select id from public.account
       where company_id = '20000000-0000-0000-0000-0000000043f1' and parent_id is null
       limit 1
     )$$,
  'P0001',
  'account_company: Company cannot be changed for an existing account',
  'company cannot change after insert'
);
select throws_ok(
  $$update public.account set account_currency = 'USD'
     where id = (
       select id from public.account
       where company_id = '20000000-0000-0000-0000-0000000043f1' and parent_id is null
       limit 1
     )$$,
  'P0001',
  'account_currency: Account currency must be the company currency',
  'account currency must be the company currency'
);
select lives_ok(
  $$insert into public.account (org_id, account_name, company_id, parent_id, root_type, account_currency)
    values (
      current_setting('test.org')::uuid,
      'Headless Petty Cash',
      '20000000-0000-0000-0000-0000000043f1',
      (select id from public.account
        where company_id = '20000000-0000-0000-0000-0000000043f1'
          and account_name = 'Application of Funds (Assets)'),
      'Asset',
      'XOF'
    )$$,
  'Accounts Manager can add a child under the asset root'
);
select lives_ok(
  $$insert into public.account (
      org_id, account_name, company_id, parent_id, root_type, account_currency, balance_must_be, freeze_account
    ) values (
      current_setting('test.org')::uuid,
      'Headless Blank Defaults',
      '20000000-0000-0000-0000-0000000043f1',
      (select id from public.account
        where company_id = '20000000-0000-0000-0000-0000000043f1'
          and account_name = 'Application of Funds (Assets)'),
      'Asset',
      'XOF',
      null,
      null
    )$$,
  'an empty balance rule and freeze value use their defaults'
);
select throws_ok(
  $$insert into public.account (org_id, account_name, company_id, parent_id, root_type, account_currency)
    values (
      current_setting('test.org')::uuid,
      'Headless Orphan',
      '20000000-0000-0000-0000-0000000043f2',
      (select id from public.account
        where company_id = '20000000-0000-0000-0000-0000000043f1'
          and account_name = 'Application of Funds (Assets)'),
      'Asset',
      'XOF'
    )$$,
  'P0001',
  'account_parent_company: Parent account must belong to the same company',
  'a parent from another company is rejected'
);

select * from finish();
rollback;
