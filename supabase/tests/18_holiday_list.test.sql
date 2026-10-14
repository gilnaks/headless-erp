begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- The document-level checks are deferred to commit; fire them at the end of each statement instead.
set constraints all immediate;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000018a1', 'hl-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000018a2', 'hl-mfg-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000018a3', 'hl-stock-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000018b1', 'hl-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000018b1","role":"authenticated"}', true);
select set_config('test.org_b', public.create_organization('{"name":"HL Org B","slug":"hl-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.holiday_list (org_id, holiday_list_name, from_date, to_date) values (current_setting('test.org_b')::uuid, 'Other', '2026-01-01', '2026-12-31');
select set_config('test.list_b', (select id from public.holiday_list where holiday_list_name = 'Other')::text, true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000018a1","role":"authenticated"}', true);
select set_config('test.org', public.create_organization('{"name":"HL Org A","slug":"hl-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000018a2', '{Manufacturing User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000018a3', '{Stock User}');

select throws_ok(
  $$insert into public.holiday_list (org_id, holiday_list_name, from_date, to_date) values (current_setting('test.org')::uuid, 'Backwards', '2026-12-31', '2026-01-01')$$,
  'P0001', 'holiday_dates: To Date cannot be before From Date', 'To Date cannot be before From Date'
);

select set_config('test.list', (public.save_doc('Holiday List', jsonb_build_object(
  'org_id', current_setting('test.org'), 'holiday_list_name', ' HL 2026 ', 'from_date', '2026-01-01', 'to_date', '2026-12-31',
  'weekly_off', '', 'color', '#3366ff', 'country', 'Netherlands',
  'holidays', jsonb_build_array(
    jsonb_build_object('holiday_date', '2026-03-01', 'description', 'Sunday', 'weekly_off', true),
    jsonb_build_object('holiday_date', '2026-01-01', 'description', 'New Year'),
    jsonb_build_object('holiday_date', '2026-02-01', 'description', 'Sunday', 'weekly_off', true, 'is_half_day', true)
  )
))) ->> 'id', true);

select is(
  (select (holiday_list_name, weekly_off is null, total_holidays::float8)::text from public.holiday_list where id = current_setting('test.list')::uuid),
  '("HL 2026",t,2.5)', 'save_doc stores the list: trimmed name, empty weekly off, total counts half days as 0.5'
);
select is(
  (select array_agg(holiday_date::text order by idx) from public.holiday where parent_id = current_setting('test.list')::uuid),
  array['2026-01-01', '2026-02-01', '2026-03-01'], 'rows are ordered by weekly off, then date'
);
select throws_ok(
  $$insert into public.holiday (org_id, parent_id, idx, holiday_date, description) values (current_setting('test.org')::uuid, current_setting('test.list')::uuid, 9, '2027-01-01', 'Too late')$$,
  'P0001', 'holiday_out_of_range: The holiday on 2027-01-01 is not between From Date and To Date', 'holidays must fall within the dates'
);
select throws_ok(
  $$insert into public.holiday (org_id, parent_id, idx, holiday_date, description) values (current_setting('test.org')::uuid, current_setting('test.list')::uuid, 9, '2026-01-01', 'Again')$$,
  'P0001', 'holiday_duplicate: Holiday Date 2026-01-01 added multiple times', 'a date can only be added once'
);
select throws_ok(
  $$update public.holiday_list set to_date = '2026-02-15' where id = current_setting('test.list')::uuid$$,
  'P0001', null, 'the dates cannot shrink past existing holidays'
);

delete from public.holiday where parent_id = current_setting('test.list')::uuid and holiday_date = '2026-03-01';
select is(
  (select (total_holidays::float8, (select array_agg(idx order by idx) from public.holiday where parent_id = l.id))::text
     from public.holiday_list l where id = current_setting('test.list')::uuid),
  '(1.5,"{1,2}")', 'removing a row re-indexes and recomputes the total'
);

select ok(app.is_holiday(current_setting('test.list')::uuid, '2026-01-01'), 'is_holiday: a full holiday');
select ok(not app.is_holiday(current_setting('test.list')::uuid, '2026-02-01'), 'is_holiday: half days are not full holidays');
select ok(app.is_half_holiday(current_setting('test.list')::uuid, '2026-02-01'), 'is_half_holiday: a half day');
select ok(not app.is_holiday(current_setting('test.list')::uuid, '2026-01-02'), 'is_holiday: a working day');

select throws_ok(
  $$insert into public.holiday_list (org_id, holiday_list_name, from_date, to_date) values (current_setting('test.org')::uuid, 'hl 2026', '2026-01-01', '2026-12-31')$$,
  '23505', null, 'holiday list names are unique per organization (case-insensitive)'
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000018c1', current_setting('test.org')::uuid, 'HL Co', 'HLC');
update public.companies set default_holiday_list_id = current_setting('test.list')::uuid where id = '00000000-0000-0000-0000-0000000018c1';
select throws_ok(
  $$delete from public.holiday_list where id = current_setting('test.list')::uuid$$,
  '23503', null, 'a company''s default holiday list cannot be deleted'
);
select throws_ok(
  $$update public.companies set default_holiday_list_id = current_setting('test.list_b')::uuid where id = '00000000-0000-0000-0000-0000000018c1'$$,
  '23503', null, 'the default holiday list belongs to the same organization'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000018a2","role":"authenticated"}', true);
select is(
  (select (select count(*) from public.holiday_list)::int + (select count(*) from public.holiday)::int),
  3, 'Manufacturing User reads the list and its holidays (not another organization''s)'
);
select throws_ok(
  $$insert into public.holiday (org_id, parent_id, idx, holiday_date, description) values (current_setting('test.org')::uuid, current_setting('test.list')::uuid, 9, '2026-05-01', 'Labour Day')$$,
  '42501', null, 'Manufacturing User cannot add holidays'
);
update public.holiday set description = 'x' where parent_id = current_setting('test.list')::uuid;
select is((select count(*)::int from public.holiday where description = 'x'), 0, 'Manufacturing User cannot edit holidays');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000018a3","role":"authenticated"}', true);
select is((select count(*)::int from public.holiday), 0, 'roles without a rule see no holidays');

select * from finish();
rollback;
