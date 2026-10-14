begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a2', 'sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'owner-b@test.local', 'authenticated', 'authenticated');

insert into public.organizations (id, slug, name, country, default_currency, time_zone) values
  ('10000000-0000-0000-0000-00000000000a', 'org-a', 'Org A', 'India', 'INR', 'Asia/Kolkata'),
  ('10000000-0000-0000-0000-00000000000b', 'org-b', 'Org B', 'United States', 'USD', 'Not/AZone');

do $$ begin perform app.sync_role_permissions(); end $$;

insert into public.org_members (org_id, user_id, roles, is_owner) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', '{}', true),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', '{Sales User}', false),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', '{}', true);

select results_eq(
  $$select date_format, time_format, number_format, time_zone, float_precision, first_day_of_the_week, language
      from public.system_settings where org_id = '10000000-0000-0000-0000-00000000000a'$$,
  $$values ('dd-mm-yyyy', 'HH:mm:ss', '#,##,###.##', 'Asia/Kolkata', '3', 'Sunday', 'en')$$,
  'a new organization gets System Settings from its country, currency and time zone'
);

select results_eq(
  $$select date_format, number_format, time_zone from public.system_settings
      where org_id = '10000000-0000-0000-0000-00000000000b'$$,
  $$values ('mm-dd-yyyy', '#,###.##', 'UTC')$$,
  'unknown org time zones fall back to UTC'
);

select ok(
  exists (select 1 from public.role_permissions
          where org_id = '10000000-0000-0000-0000-00000000000a' and role = 'Sales User'
            and doctype = 'System Settings' and can_read and not can_write),
  'other roles get read-only access to System Settings'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

update public.system_settings set float_precision = '4', date_format = 'yyyy-mm-dd'
where org_id = '10000000-0000-0000-0000-00000000000a';

select is(
  (select float_precision || ' ' || date_format from public.system_settings
    where org_id = '10000000-0000-0000-0000-00000000000a'),
  '4 yyyy-mm-dd',
  'System Manager can edit System Settings'
);

select throws_ok(
  $$update public.system_settings set date_format = 'yyyy/dd/mm' where org_id = '10000000-0000-0000-0000-00000000000a'$$,
  '23514', null,
  'date formats outside Frappe''s options are rejected'
);

select throws_ok(
  $$update public.system_settings set time_zone = 'Mars/Olympus' where org_id = '10000000-0000-0000-0000-00000000000a'$$,
  'P0001', 'time_zone_unknown: Unknown time zone: Mars/Olympus',
  'unknown time zones are rejected'
);

select is(
  (select count(*)::int from public.system_settings),
  1,
  'members only see their own org row'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);

update public.system_settings set float_precision = '9' where org_id = '10000000-0000-0000-0000-00000000000a';

select is(
  (select float_precision from public.system_settings where org_id = '10000000-0000-0000-0000-00000000000a'),
  '4',
  'non System Managers can read but not edit System Settings'
);

delete from public.system_settings where org_id = '10000000-0000-0000-0000-00000000000a';

select is(
  (select count(*)::int from public.system_settings),
  1,
  'rows cannot be deleted through the API'
);

select * from finish();
rollback;
