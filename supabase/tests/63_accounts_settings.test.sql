begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000006301', 'settings-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000006302', 'settings-accounts@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006301","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Settings Co","slug":"accounts-63"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-000000006302', '{Accounts User}');

select results_eq(
  $$select unlink_payment_on_cancellation_of_invoice, over_billing_allowance = 0, add_taxes_from_item_tax_template,
           book_asset_depreciation_entry_automatically, default_ageing_range, stale_days, determine_address_tax_category_from
      from public.accounts_settings$$,
  $$values (true, true, true, true, '30, 60, 90, 120', 1, 'Billing Address')$$,
  'the seeded row has the plan defaults'
);

reset role;
select throws_ok(
  $$insert into public.accounts_settings (org_id) values (current_setting('test.org')::uuid)$$,
  '23505', null,
  'a second row for the same organization is rejected'
);
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006302","role":"authenticated"}', true);
update public.accounts_settings set merge_similar_account_heads = true;
select is(
  (select merge_similar_account_heads from public.accounts_settings),
  false,
  'Accounts User cannot update accounts settings'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006301","role":"authenticated"}', true);
update public.org_members
   set roles = '{Accounts Manager}'
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000006302';
insert into public.roles (org_id, name) values (current_setting('test.org')::uuid, 'Credit Clerk');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006302","role":"authenticated"}', true);
update public.accounts_settings set merge_similar_account_heads = true;
select is(
  (select merge_similar_account_heads from public.accounts_settings),
  true,
  'Accounts Manager can set merge similar account heads'
);
select throws_ok(
  $$update public.accounts_settings set credit_controller = 'Missing'$$,
  '23503', null,
  'an unknown role is rejected'
);
update public.accounts_settings set credit_controller = 'Credit Clerk';

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000006301","role":"authenticated"}', true);
delete from public.roles where org_id = current_setting('test.org')::uuid and name = 'Credit Clerk';
select is(
  (select credit_controller from public.accounts_settings),
  null,
  'deleting that role nulls the column'
);

select * from finish();
rollback;
