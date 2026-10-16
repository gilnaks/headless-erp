begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000041d1', 'stock-entry-type-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000041d1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Stock Entry Type Org","slug":"stock-entry-type-org","country":"Ivory Coast"}') ->> 'id',
  true
);

select is(
  (select count(*)::int from public.stock_entry_type where is_standard),
  8,
  'a new organization gets the eight standard stock entry types'
);
select lives_ok(
  $$insert into public.stock_entry_type (org_id, name) values (current_setting('test.org')::uuid, 'Scrap')$$,
  'System Manager can add a stock entry type'
);
select throws_ok(
  $$insert into public.stock_entry_type (org_id, name) values (current_setting('test.org')::uuid, ' material issue ')$$,
  '23505',
  'duplicate key value violates unique constraint "stock_entry_type_name_uniq"',
  'a stock entry type name is unique per organization, ignoring case and surrounding spaces'
);
select throws_ok(
  $$delete from public.stock_entry_type where name = 'Material Issue'$$,
  'P0001',
  'stock_entry_type_standard: a standard Stock Entry Type cannot be deleted',
  'a standard stock entry type cannot be deleted'
);
select throws_ok(
  $$update public.stock_entry_type set name = 'Renamed' where name = 'Material Issue'$$,
  'P0001',
  'stock_entry_type_standard: a standard Stock Entry Type cannot be renamed',
  'a standard stock entry type cannot be renamed'
);
select throws_ok(
  $$insert into public.stock_entry_type (org_id, name, purpose)
    values (current_setting('test.org')::uuid, 'Transit Transfer', 'Material Transfer')$$,
  'P0001',
  'stock_entry_type_purpose: Purpose must match the name',
  'purpose must match the name'
);

select * from finish();
rollback;
