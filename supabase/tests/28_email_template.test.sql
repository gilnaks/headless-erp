begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000028a1', 'template-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000028a2', 'template-sales-mgr-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000028a3', 'template-stock-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000028b1', 'template-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000028b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Template Org B","slug":"template-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000028a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Template Org A","slug":"template-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000028a2', '{Sales Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000028a3', '{Stock User}');

select set_config('test.t1', (public.save_doc('Email Template', jsonb_build_object(
  'org_id', current_setting('test.org'), 'name', ' Quotation Follow-up ', 'subject', ' Your quotation {{doc.name}} ',
  'response_html', ' <p>Dear {{doc.customer_name}}</p> ', 'response', ''
))) ->> 'id', true);

select is(
  (select (name, subject, use_html, response_html, response is null)::text from public.email_template where id = current_setting('test.t1')::uuid),
  '("Quotation Follow-up","Your quotation {{doc.name}}",t,"<p>Dear {{doc.customer_name}}</p>",t)',
  'name, subject and bodies are trimmed; use_html defaults to true'
);
select throws_ok(
  $$select public.save_doc('Email Template', jsonb_build_object('org_id', current_setting('test.org'), 'name', 'quotation follow-up', 'subject', 'x'))$$,
  '23505', null, 'template names are unique per organization (case-insensitive)'
);
select throws_ok(
  $$select public.save_doc('Email Template', jsonb_build_object('org_id', current_setting('test.org'), 'name', 'No subject', 'subject', ' '))$$,
  '23514', null, 'a subject is required'
);

-- Sales Manager: read and write, no create or delete.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000028a2","role":"authenticated"}', true);
select lives_ok(
  format($$select public.save_doc('Email Template', jsonb_build_object('id', %L, 'subject', 'Quotation {{doc.name}}'))$$, current_setting('test.t1')),
  'Sales Managers can edit templates'
);
select throws_ok(
  $$select public.save_doc('Email Template', jsonb_build_object('org_id', current_setting('test.org'), 'name', 'Mine', 'subject', 'x'))$$,
  '42501', null, 'Sales Managers cannot create templates'
);
select throws_ok(
  format($$select public.delete_doc('Email Template', %L)$$, current_setting('test.t1')),
  '42501', null, 'Sales Managers cannot delete templates'
);

-- Stock User: read only.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000028a3","role":"authenticated"}', true);
select is(
  (select subject from public.email_template where id = current_setting('test.t1')::uuid),
  'Quotation {{doc.name}}', 'every role reads templates'
);
select throws_ok(
  format($$select public.save_doc('Email Template', jsonb_build_object('id', %L, 'subject', 'Hacked'))$$, current_setting('test.t1')),
  '42501', null, 'other roles cannot edit templates'
);

-- Other organization.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000028b1","role":"authenticated"}', true);
select is((select count(*)::int from public.email_template), 0, 'templates are scoped to their organization');
select lives_ok(
  $$select public.save_doc('Email Template', jsonb_build_object('org_id', current_setting('test.org_b'), 'name', 'Quotation Follow-up', 'subject', 'x'))$$,
  'another organization can reuse the name'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000028a1","role":"authenticated"}', true);
select lives_ok(
  format($$select public.delete_doc('Email Template', %L)$$, current_setting('test.t1')),
  'System Managers delete templates'
);

select * from finish();
rollback;
