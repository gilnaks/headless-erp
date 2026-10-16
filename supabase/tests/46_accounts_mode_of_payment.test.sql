begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000046a1', 'mode-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000046a2', 'mode-us@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000046a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Mode Org","slug":"mode-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

select is(
  (select array_agg(mode_of_payment || ':' || coalesce(type, '') order by mode_of_payment)
     from public.mode_of_payment
    where org_id = current_setting('test.org')::uuid),
  array['Bank Draft:Bank', 'Cash:Cash', 'Cheque:Bank', 'Credit Card:Bank', 'Wire Transfer:Bank'],
  'an organization insert seeds the five modes, with Cheque outside the United States'
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000046a1', current_setting('test.org')::uuid, 'Cash Co', 'CC'),
  ('20000000-0000-0000-0000-0000000046a2', current_setting('test.org')::uuid, 'Other Co', 'OC');

select ok(
  exists (
    select 1
      from public.mode_of_payment_account a
      join public.mode_of_payment m on m.id = a.parent_id
      join public.companies c on c.id = a.company_id
     where a.company_id = '20000000-0000-0000-0000-0000000046a1'
       and m.mode_of_payment = 'Cash'
       and m.enabled
       and c.default_cash_account_id is not null
       and a.default_account_id = c.default_cash_account_id
  ),
  'Cash uses the company default cash account'
);
select ok(
  exists (
    select 1
      from public.mode_of_payment_account a
      join public.companies c on c.id = a.company_id
      join public.mode_of_payment m on m.id = a.parent_id
     where a.company_id = '20000000-0000-0000-0000-0000000046a2'
       and m.mode_of_payment = 'Cash'
       and a.default_account_id = c.default_cash_account_id
       and a.default_account_id is distinct from (
         select default_cash_account_id from public.companies
          where id = '20000000-0000-0000-0000-0000000046a1'
       )
  ),
  'a second company gets its own Cash row'
);

reset role;
update public.mode_of_payment_account a
   set default_account_id = (
     select id from public.account
      where company_id = '20000000-0000-0000-0000-0000000046a1'
        and account_type = 'Receivable' and is_group = false
      limit 1
   )
 where a.company_id = '20000000-0000-0000-0000-0000000046a1'
   and a.parent_id = (
     select id from public.mode_of_payment
      where org_id = current_setting('test.org')::uuid and mode_of_payment = 'Cash'
   );
do $$ begin perform app.set_mode_of_payment_account('20000000-0000-0000-0000-0000000046a1'); end $$;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000046a1","role":"authenticated"}', true);

select ok(
  exists (
    select 1
      from public.mode_of_payment_account a
      join public.companies c on c.id = a.company_id
     where a.company_id = '20000000-0000-0000-0000-0000000046a1'
       and a.default_account_id = (
         select id from public.account
          where company_id = a.company_id and account_type = 'Receivable' and is_group = false
          limit 1
       )
       and a.default_account_id is distinct from c.default_cash_account_id
  ),
  'an existing Cash row is left alone'
);

reset role;
update public.org_members
   set roles = '{System Manager,Accounts Manager}'
 where user_id = '00000000-0000-0000-0000-0000000046a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000046a1","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.mode_of_payment (org_id, mode_of_payment, type)
    values (current_setting('test.org')::uuid, 'Petty Cash', 'Cash')$$,
  'Accounts Manager can add a mode of payment'
);
select throws_ok(
  $$insert into public.mode_of_payment_account (org_id, parent_id, idx, company_id)
    values (
      current_setting('test.org')::uuid,
      (select id from public.mode_of_payment
        where org_id = current_setting('test.org')::uuid and mode_of_payment = 'Cash'),
      2,
      '20000000-0000-0000-0000-0000000046a1'
    )$$,
  'P0001',
  'mode_of_payment_company: Same Company is entered more than once',
  'the same company cannot be entered twice'
);
select throws_ok(
  $$insert into public.mode_of_payment_account (org_id, parent_id, idx, company_id, default_account_id)
    values (
      current_setting('test.org')::uuid,
      (select id from public.mode_of_payment
        where org_id = current_setting('test.org')::uuid and mode_of_payment = 'Wire Transfer'),
      1,
      '20000000-0000-0000-0000-0000000046a1',
      (select default_cash_account_id from public.companies
        where id = '20000000-0000-0000-0000-0000000046a2')
    )$$,
  'P0001',
  'mode_of_payment_account: Account does not match with Company in Mode of Payment',
  'an account from another company is rejected'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000046a2","role":"authenticated"}', true);
select set_config(
  'test.org_us',
  app.create_organization('{"name":"Mode US","slug":"mode-us","country":"United States","default_currency":"USD"}') ->> 'id',
  true
);
select ok(
  exists (
    select 1 from public.mode_of_payment
     where org_id = current_setting('test.org_us')::uuid
       and mode_of_payment = 'Check' and type = 'Bank'
  )
  and not exists (
    select 1 from public.mode_of_payment
     where org_id = current_setting('test.org_us')::uuid and mode_of_payment = 'Cheque'
  ),
  'a United States organization seeds Check instead of Cheque'
);

select * from finish();
rollback;
