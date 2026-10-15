begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000022a1', 'lh-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000022a2', 'lh-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000022b1', 'lh-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000022b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"LH Org B","slug":"lh-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.letter_head (id, org_id, letter_head_name) values
  ('00000000-0000-0000-0000-0000000022f1', current_setting('test.org_b')::uuid, 'B Letter Head');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000022a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"LH Org A","slug":"lh-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000022a2', '{Sales User}');

-- set_as_default / validate_disabled_and_default
insert into public.letter_head (id, org_id, letter_head_name, content) values
  ('00000000-0000-0000-0000-0000000022e1', current_setting('test.org')::uuid, ' Standard ', '<p>Acme</p>');
select ok((select is_default from public.letter_head where id = '00000000-0000-0000-0000-0000000022e1'), 'the first enabled letter head becomes the default');
select is((select letter_head_name from public.letter_head where id = '00000000-0000-0000-0000-0000000022e1'), 'Standard', 'the name is trimmed');
insert into public.letter_head (id, org_id, letter_head_name) values
  ('00000000-0000-0000-0000-0000000022e2', current_setting('test.org')::uuid, 'Plain');
select ok(not (select is_default from public.letter_head where id = '00000000-0000-0000-0000-0000000022e2'), 'later letter heads are not the default');
update public.letter_head set is_default = true where id = '00000000-0000-0000-0000-0000000022e2';
select is(
  (select array_agg(letter_head_name order by letter_head_name) from public.letter_head where is_default),
  '{Plain}', 'setting a default clears the previous one'
);
select throws_ok(
  $$update public.letter_head set disabled = true where id = '00000000-0000-0000-0000-0000000022e2'$$,
  'P0001', 'letter_head_disabled_default: Letter Head cannot be both disabled and default',
  'the default letter head cannot be disabled'
);
select throws_ok(
  $$insert into public.letter_head (org_id, letter_head_name) values (current_setting('test.org')::uuid, 'standard')$$,
  '23505', null, 'letter head names are unique per organization (case-insensitive)'
);
select throws_ok(
  format($$insert into public.letter_head (org_id, letter_head_name, source, image) values (current_setting('test.org')::uuid, 'Foreign', 'Image', '%s/letter-head/x.png')$$, current_setting('test.org_b')),
  '23514', null, 'images must live in the organization''s own folder'
);

-- Company.default_letter_head
insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000022c1', current_setting('test.org')::uuid, 'LH Co', 'LHC');
update public.companies set default_letter_head_id = '00000000-0000-0000-0000-0000000022e1' where id = '00000000-0000-0000-0000-0000000022c1';
select is((select default_letter_head_id from public.companies where id = '00000000-0000-0000-0000-0000000022c1'), '00000000-0000-0000-0000-0000000022e1'::uuid, 'a company links its default letter head');
select throws_ok(
  $$update public.companies set default_letter_head_id = '00000000-0000-0000-0000-0000000022f1' where id = '00000000-0000-0000-0000-0000000022c1'$$,
  '23503', null, 'a company cannot link another organization''s letter head'
);
delete from public.letter_head where id = '00000000-0000-0000-0000-0000000022e1';
select is((select default_letter_head_id from public.companies where id = '00000000-0000-0000-0000-0000000022c1'), null, 'deleting the letter head clears the company link');

-- RLS
select is((select count(*)::int from public.letter_head), 1, 'letter heads of another organization are invisible');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000022a2","role":"authenticated"}', true);
select is((select count(*)::int from public.letter_head), 1, 'every role reads letter heads');
select throws_ok(
  $$insert into public.letter_head (org_id, letter_head_name) values (current_setting('test.org')::uuid, 'Sales')$$,
  '42501', null, 'non System Managers cannot add letter heads'
);

-- Storage policies on the org-files bucket
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('org-files', '%s/letter-head/sales.png')$$, current_setting('test.org')),
  '42501', null, 'members without Letter Head write cannot upload'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000022a1","role":"authenticated"}', true);
select lives_ok(
  format($$insert into storage.objects (bucket_id, name) values ('org-files', '%s/letter-head/logo.png')$$, current_setting('test.org')),
  'System Managers upload into their organization''s letter-head folder'
);
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('org-files', '%s/letter-head/logo.png')$$, current_setting('test.org_b')),
  '42501', null, 'uploads into another organization''s folder are rejected'
);
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('org-files', '%s/other/logo.png')$$, current_setting('test.org')),
  '42501', null, 'uploads into folders without an owning doctype are rejected'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000022b1","role":"authenticated"}', true);
select is((select count(*)::int from storage.objects where bucket_id = 'org-files'), 0, 'files of another organization are invisible');

select * from finish();
rollback;
