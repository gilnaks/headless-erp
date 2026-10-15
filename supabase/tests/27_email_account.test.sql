begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000027a1', 'email-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000027a2', 'email-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000027b1', 'email-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000027b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Email Org B","slug":"email-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000027a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Email Org A","slug":"email-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000027a2', '{Sales User}');
insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000027c1', current_setting('test.org')::uuid, 'Acme', 'AC');

select set_config('test.a1', (public.save_doc('Email Account', jsonb_build_object(
  'org_id', current_setting('test.org'), 'email_account_name', ' Main ', 'email_id', ' Hello@Acme.Test ',
  'default_outgoing', true, 'api_key_secret', '00000000-0000-0000-0000-000000000001'
))) ->> 'id', true);

select is(
  (select (email_account_name, email_id, provider, default_outgoing, api_key_secret is null, has_api_key)::text
     from public.email_account where id = current_setting('test.a1')::uuid),
  '(Main,hello@acme.test,resend,t,t,f)',
  'name and address are trimmed (address lowercased); a secret id in the payload is ignored'
);

select lives_ok(
  format($$select public.set_email_account_key(%L, ' re_first ')$$, current_setting('test.a1')),
  'a System Manager stores the API key'
);
select is(
  (select has_api_key from public.email_account where id = current_setting('test.a1')::uuid),
  true, 'the account records that a key is stored'
);
select set_config('test.secret', (select api_key_secret::text from public.email_account where id = current_setting('test.a1')::uuid), true);

select lives_ok(
  format($$select public.set_email_account_key(%L, 're_second')$$, current_setting('test.a1')),
  'setting the key again replaces it'
);
select is(
  (select api_key_secret::text from public.email_account where id = current_setting('test.a1')::uuid),
  current_setting('test.secret'), 'a replaced key keeps its Vault secret'
);
select throws_ok(
  format($$select public.set_email_account_key(%L, '  ')$$, current_setting('test.a1')),
  'P0001', null, 'an empty key is rejected'
);

select lives_ok(
  format($$select public.save_doc('Email Account', jsonb_build_object('id', %L, 'api_key_secret', null, 'signature', ' Thanks '))$$,
    current_setting('test.a1')),
  'saving the account through save_doc works'
);
select is(
  (select (api_key_secret::text = current_setting('test.secret'), signature)::text
     from public.email_account where id = current_setting('test.a1')::uuid),
  '(t,Thanks)', 'save_doc cannot overwrite the secret id'
);

select set_config('test.a2', (public.save_doc('Email Account', jsonb_build_object(
  'org_id', current_setting('test.org'), 'email_account_name', 'Acme Sales', 'email_id', 'sales@acme.test',
  'company_id', '00000000-0000-0000-0000-0000000027c1'
))) ->> 'id', true);
do $$ begin perform public.set_email_account_key(current_setting('test.a2')::uuid, 're_company'); end $$;

select throws_ok(
  format($$select public.save_doc('Email Account', jsonb_build_object('id', %L, 'default_outgoing', true, 'enable_outgoing', false))$$,
    current_setting('test.a2')),
  'P0001', null, 'a default outgoing account must have outgoing enabled'
);
select throws_ok(
  $$select public.save_doc('Email Account', jsonb_build_object('org_id', current_setting('test.org'), 'email_account_name', 'Bad', 'email_id', 'not-an-email'))$$,
  'P0001', 'invalid_email: Enter a valid email address', 'the email address is format-checked'
);
select throws_ok(
  $$select public.save_doc('Email Account', jsonb_build_object('org_id', current_setting('test.org'), 'email_account_name', 'main', 'email_id', 'x@acme.test'))$$,
  '23505', null, 'account names are unique per organization (case-insensitive)'
);

select set_config('test.a3', (public.save_doc('Email Account', jsonb_build_object(
  'org_id', current_setting('test.org'), 'email_account_name', 'Notices', 'email_id', 'notices@acme.test', 'default_outgoing', true
))) ->> 'id', true);
select is(
  (select array_agg(email_account_name order by email_account_name) from public.email_account
    where org_id = current_setting('test.org')::uuid and default_outgoing),
  array['Notices'], 'a new default outgoing account clears the previous one'
);
do $$ begin perform public.save_doc('Email Account', jsonb_build_object('id', current_setting('test.a1'), 'default_outgoing', true)); end $$;

select throws_ok(
  format($$select * from public.email_sender(%L)$$, current_setting('test.org')),
  '42501', null, 'API roles cannot read sending credentials'
);

-- Sales User: no Email Account permission.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000027a2","role":"authenticated"}', true);
select is((select count(*)::int from public.email_account), 0, 'users without Email Account read see no accounts');
select throws_ok(
  format($$select public.set_email_account_key(%L, 're_hijack')$$, current_setting('test.a1')),
  '42501', null, 'users without Email Account write cannot set a key'
);
select throws_ok(
  format($$insert into public.email_log (org_id, sender, recipients, subject, status) values (%L, 'x@y.z', '{a@b.c}', 'Hi', 'Sent')$$,
    current_setting('test.org')),
  '42501', null, 'API roles cannot write the email log'
);

-- Org B owner sees nothing of org A.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000027b1","role":"authenticated"}', true);
select is((select count(*)::int from public.email_account), 0, 'accounts are scoped to their organization');

-- The server's sending module (service role).
reset role;
set local role service_role;
select is(
  (select (email_account_name, api_key)::text
     from public.email_sender(current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000027c1')),
  '("Acme Sales",re_company)', 'the company''s account is preferred'
);
select is(
  (select (email_account_name, api_key)::text from public.email_sender(current_setting('test.org')::uuid)),
  '(Main,re_second)', 'otherwise the organization''s default outgoing account (with the current key)'
);
select is(
  (select count(*)::int from public.email_sender(current_setting('test.org')::uuid, null, current_setting('test.a3')::uuid)),
  0, 'accounts without a stored key are never used'
);

insert into public.email_log (org_id, email_account_id, sender, recipients, subject, status, sent_by) values
  (current_setting('test.org')::uuid, current_setting('test.a1')::uuid, 'hello@acme.test', '{a@b.c}', 'From sales', 'Sent', '00000000-0000-0000-0000-0000000027a2'),
  (current_setting('test.org')::uuid, current_setting('test.a1')::uuid, 'hello@acme.test', '{a@b.c}', 'From owner', 'Sent', '00000000-0000-0000-0000-0000000027a1');
select throws_ok(
  $$update public.email_log set subject = 'changed'$$, '42501', null, 'the email log is append-only'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000027a2","role":"authenticated"}', true);
select is(
  (select array_agg(subject) from public.email_log), array['From sales'], 'senders read their own log rows'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000027a1","role":"authenticated"}', true);
select is((select count(*)::int from public.email_log), 2, 'System Managers read the organization''s log');

delete from public.email_account where id = current_setting('test.a1')::uuid;
reset role;
select is(
  (select count(*)::int from vault.secrets where id = current_setting('test.secret')::uuid),
  0, 'deleting an account deletes its key'
);

select * from finish();
rollback;
