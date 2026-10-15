begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

-- The document-level checks are deferred to commit (after app.save_doc writes the rows); fire them per save.
create function pg_temp.save(p_doctype text, p_payload jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := public.save_doc(p_doctype, p_payload);
  set constraints all immediate;
  set constraints all deferred;
  return r;
end
$$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000026a1', 'contact-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000026a2', 'contact-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000026a3', 'contact-late-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000026b1', 'contact-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000026b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Contact Org B","slug":"contact-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
select set_config('test.contact_b', (pg_temp.save('Contact', jsonb_build_object('org_id', current_setting('test.org_b'), 'first_name', 'Other'))) ->> 'id', true);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000026a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Contact Org A","slug":"contact-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000026a2', '{Sales User}');
insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000026c1', current_setting('test.org')::uuid, 'Acme', 'AC');

select set_config('test.c1', (pg_temp.save('Contact', jsonb_build_object(
  'org_id', current_setting('test.org'), 'first_name', ' Jane ', 'middle_name', '', 'last_name', 'Doe', 'is_primary_contact', true,
  'email_ids', jsonb_build_array(jsonb_build_object('email_id', 'jane@acme.test'), jsonb_build_object('email_id', ' contact-sales-a@test.local ', 'is_primary', true)),
  'phone_nos', jsonb_build_array(jsonb_build_object('phone', '111', 'is_primary_phone', true), jsonb_build_object('phone', '222', 'is_primary_mobile_no', true)),
  'links', jsonb_build_array(jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000026c1'))
))) ->> 'id', true);

select is(
  (select (name, full_name, email_id, phone, mobile_no, status)::text from public.contact where id = current_setting('test.c1')::uuid),
  '("Jane Doe-Acme","Jane Doe",contact-sales-a@test.local,111,222,Passive)',
  'name is the full name plus the first link, primary rows fill email / phone / mobile'
);
select is(
  (select user_id::text from public.contact where id = current_setting('test.c1')::uuid),
  '00000000-0000-0000-0000-0000000026a2', 'the member with the primary email becomes the contact''s user (set_user)'
);
select is(
  (select link_title from public.contact_link where parent_id = current_setting('test.c1')::uuid),
  'Acme', 'link rows carry the linked record''s title'
);

select set_config('test.c2', (pg_temp.save('Contact', jsonb_build_object(
  'org_id', current_setting('test.org'), 'first_name', 'Jane', 'last_name', 'Doe', 'is_primary_contact', true,
  'links', jsonb_build_array(jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000026c1'))
))) ->> 'id', true);
select is(
  (select (name, email_id is null)::text from public.contact where id = current_setting('test.c2')::uuid),
  '("Jane Doe-Acme-1",t)', 'a clashing name gets a -1 suffix; no email rows means no email'
);
select is(
  (select is_primary_contact from public.contact where id = current_setting('test.c1')::uuid),
  false, 'a new primary contact unsets the previous one for the same party'
);
select is(
  (select array_agg(name) from public.party_contacts('Company', '00000000-0000-0000-0000-0000000026c1')),
  array['Jane Doe-Acme-1', 'Jane Doe-Acme'], 'party_contacts: primary first'
);

select set_config('test.c3', (pg_temp.save('Contact', jsonb_build_object(
  'org_id', current_setting('test.org'), 'first_name', 'Late', 'last_name', 'Joiner',
  'email_ids', jsonb_build_array(jsonb_build_object('email_id', 'Contact-Late-A@test.local', 'is_primary', true))
))) ->> 'id', true);
select is(
  (select (name, user_id is null)::text from public.contact where id = current_setting('test.c3')::uuid),
  '("Late Joiner",t)', 'without links the name is the full name; non-members are not matched'
);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000026a3', '{Projects User}');
select is(
  (select user_id::text from public.contact where id = current_setting('test.c3')::uuid),
  '00000000-0000-0000-0000-0000000026a3', 'a member added later is matched by email'
);

select throws_ok(
  $$select pg_temp.save('Contact', jsonb_build_object('org_id', current_setting('test.org'), 'first_name', 'X',
      'email_ids', jsonb_build_array(jsonb_build_object('email_id', 'a@x.test', 'is_primary', true), jsonb_build_object('email_id', 'b@x.test', 'is_primary', true))))$$,
  'P0001', 'contact_primary_email: Only one Email ID can be set as primary.', 'one primary email'
);
select throws_ok(
  $$select pg_temp.save('Contact', jsonb_build_object('org_id', current_setting('test.org'), 'first_name', 'X',
      'phone_nos', jsonb_build_array(jsonb_build_object('phone', '1', 'is_primary_phone', true), jsonb_build_object('phone', '2', 'is_primary_phone', true))))$$,
  'P0001', 'contact_primary_phone: Only one Phone can be set as primary.', 'one primary phone'
);
select throws_ok(
  $$select pg_temp.save('Contact', jsonb_build_object('org_id', current_setting('test.org'), 'first_name', 'X',
      'phone_nos', jsonb_build_array(jsonb_build_object('phone', '1', 'is_primary_mobile_no', true), jsonb_build_object('phone', '2', 'is_primary_mobile_no', true))))$$,
  'P0001', 'contact_primary_mobile: Only one Mobile No can be set as primary.', 'one primary mobile'
);
select throws_ok(
  $$select pg_temp.save('Contact', jsonb_build_object('org_id', current_setting('test.org'), 'first_name', 'X',
      'email_ids', jsonb_build_array(jsonb_build_object('email_id', 'not-an-email'))))$$,
  'P0001', 'invalid_email: not-an-email is not a valid Email Address', 'emails are validated'
);
select throws_ok(
  $$insert into public.contact (org_id, first_name, gender) values (current_setting('test.org')::uuid, 'X', 'Unknown')$$,
  '23514', null, 'gender is one of the standard genders'
);

select lives_ok(
  $$select pg_temp.save('Contact', jsonb_build_object('id', current_setting('test.c1'), 'first_name', 'Janet',
      'email_ids', jsonb_build_array(jsonb_build_object('email_id', 'jane@acme.test'))))$$,
  'editing the contact keeps working'
);
select is(
  (select (name, full_name, email_id is null)::text from public.contact where id = current_setting('test.c1')::uuid),
  '("Jane Doe-Acme","Janet Doe",t)', 'the name is set once; dropping the primary email clears email_id'
);

update public.companies set default_sales_contact_id = current_setting('test.c2')::uuid where id = '00000000-0000-0000-0000-0000000026c1';
select throws_ok(
  $$update public.companies set default_sales_contact_id = current_setting('test.contact_b')::uuid where id = '00000000-0000-0000-0000-0000000026c1'$$,
  '23503', null, 'the default sales contact belongs to the same organization'
);
update public.companies set company_name = 'Acme BV' where id = '00000000-0000-0000-0000-0000000026c1';
select is(
  (select array_agg(distinct link_title) from public.contact_link where link_id = '00000000-0000-0000-0000-0000000026c1'),
  array['Acme BV'], 'renaming the party refreshes contact link titles'
);
delete from public.contact where id = current_setting('test.c2')::uuid;
select is(
  (select default_sales_contact_id from public.companies where id = '00000000-0000-0000-0000-0000000026c1'),
  null, 'deleting the default sales contact clears it on the company'
);

select is(app.file_doctype(current_setting('test.org') || '/contact/x.png'), 'Contact', 'contact images use the contact folder');
select throws_ok(
  $$update public.contact set image = current_setting('test.org_b') || '/contact/x.png' where id = current_setting('test.c1')::uuid$$,
  '23514', null, 'a contact image must live in its own organization''s contact folder'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000026a2","role":"authenticated"}', true);
select is(
  (select (select count(*) from public.contact)::int + (select count(*) from public.contact_email)::int
          + (select count(*) from public.contact_link)::int),
  5, 'Sales User reads contacts and their rows (not another organization''s)'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000026a3","role":"authenticated"}', true);
select is((select count(*)::int from public.contact), 0, 'roles without a rule see no contacts');
select is((select count(*)::int from public.party_contacts('Company', '00000000-0000-0000-0000-0000000026c1')), 0, 'party_contacts applies RLS');

select * from finish();
rollback;
