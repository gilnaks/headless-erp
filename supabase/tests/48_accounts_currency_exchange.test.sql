begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000048a1', 'fx-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000048a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"FX Org","slug":"fx-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

select is(
  public.get_exchange_rate(current_setting('test.org')::uuid, 'USD', 'USD', '2026-01-15', 'selling'),
  1::numeric,
  'the same currency returns 1'
);

reset role;
update public.org_members
   set roles = '{System Manager,Accounts Manager}'
 where user_id = '00000000-0000-0000-0000-0000000048a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000048a1","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.currency_exchange (org_id, date, from_currency, to_currency, exchange_rate)
    values (current_setting('test.org')::uuid, '2026-01-15', 'USD', 'PHP', 56.5)$$,
  'Accounts Manager can add a rate'
);
select is(
  (select name from public.currency_exchange
    where org_id = current_setting('test.org')::uuid and from_currency = 'USD' and to_currency = 'PHP'),
  '2026-01-15-USD-PHP-Selling-Buying',
  'the name is the date, the currencies, and Selling-Buying'
);

insert into public.currency_exchange (org_id, date, from_currency, to_currency, exchange_rate)
values (current_setting('test.org')::uuid, '2026-02-01', 'USD', 'PHP', 60);
insert into public.currency_exchange (org_id, date, from_currency, to_currency, exchange_rate, for_buying, for_selling)
values (current_setting('test.org')::uuid, '2026-01-15', 'EUR', 'PHP', 50, true, false);

select is(
  public.get_exchange_rate(current_setting('test.org')::uuid, 'USD', 'PHP', '2026-01-20', 'selling'),
  56.5::numeric,
  'the lookup uses the latest row on or before the date'
);
select is(
  public.get_exchange_rate(current_setting('test.org')::uuid, 'EUR', 'PHP', '2026-01-20', 'selling'),
  0::numeric,
  'a buying-only row is not used for selling'
);
select is(
  public.get_exchange_rate(current_setting('test.org')::uuid, 'EUR', 'PHP', '2026-01-20', 'buying'),
  50::numeric,
  'a buying lookup uses the buying row'
);
select is(
  public.get_exchange_rate(current_setting('test.org')::uuid, 'GBP', 'PHP', '2026-01-20', 'selling'),
  0::numeric,
  'a missing pair returns 0'
);

select throws_ok(
  $$insert into public.currency_exchange (org_id, date, from_currency, to_currency, exchange_rate)
    values (current_setting('test.org')::uuid, '2026-01-15', 'PHP', 'PHP', 1)$$,
  'P0001',
  'currency_exchange_same: From Currency and To Currency cannot be same',
  'the same currency is rejected'
);
select throws_ok(
  $$insert into public.currency_exchange (org_id, date, from_currency, to_currency, exchange_rate)
    values (current_setting('test.org')::uuid, '2026-01-16', 'USD', 'PHP', 0)$$,
  'P0001',
  'currency_exchange_rate: Exchange Rate must be greater than zero',
  'a zero rate is rejected'
);
select throws_ok(
  $$insert into public.currency_exchange (org_id, date, from_currency, to_currency, exchange_rate, for_buying, for_selling)
    values (current_setting('test.org')::uuid, '2026-01-17', 'USD', 'EUR', 1, false, false)$$,
  'P0001',
  'currency_exchange_side: Currency Exchange must be applicable for Buying or for Selling',
  'a rate for neither side is rejected'
);

select * from finish();
rollback;
