begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Spec: src/lib/html/sanitize.test.ts
select is(
  app.sanitize_html(
    '<div style="text-align:right"><h2>Acme</h2><p><b>Bold</b> <em>it</em></p>'
    || '<table><tbody><tr><td colspan="2">Cell</td></tr></tbody></table><img src="https://x.test/logo.png" alt="Logo" /></div>'
  ),
  '<div style="text-align:right"><h2>Acme</h2><p><b>Bold</b> <em>it</em></p>'
    || '<table><tbody><tr><td colspan="2">Cell</td></tr></tbody></table><img src="https://x.test/logo.png" alt="Logo" /></div>',
  'clean formatting, tables and images are unchanged'
);
select is(
  app.sanitize_html('<p>Hi</p><script>alert(1)</script><style>p{}</style><iframe src=''x''></iframe>'),
  '<p>Hi</p>',
  'scripts, style blocks and iframes are removed with their content'
);
select is(
  app.sanitize_html('<img src="https://x.test/a.png" onerror="alert(1)" /><p onclick="x()">t</p>'),
  '<img src="https://x.test/a.png" /><p>t</p>',
  'event handlers are stripped'
);
select is(app.sanitize_html('<a href="javascript:alert(1)">x</a>'), '<a>x</a>', 'javascript: URLs are removed');
select is(app.sanitize_html('<a href="JaVaScRiPt:alert(1)">x</a>'), '<a>x</a>', 'javascript: is matched case-insensitively');
select is(app.sanitize_html('<img src="//evil.test/a.png" />'), '<img />', 'protocol-relative URLs are removed');
select is(
  app.sanitize_html('<img src="data:image/png;base64,AAA" />'),
  '<img src="data:image/png;base64,AAA" />',
  'data: URLs are allowed on images'
);
select is(app.sanitize_html('<a href="data:text/html,x">x</a>'), '<a>x</a>', 'data: URLs are not allowed on links');
select is(
  app.sanitize_html('<p style="color: red; background-image: url(x)">t</p>'),
  '<p style="color:red">t</p>',
  'unsafe style properties are dropped and safe values are compacted'
);
select is(
  app.sanitize_html('<p style="width: expression(alert(1))">t</p>'),
  '<p>t</p>',
  'expression() styles drop the style attribute'
);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000031a1', 'search-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000031b1', 'search-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000031b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Search Org B","slug":"search-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.letter_head (id, org_id, letter_head_name, content) values
  ('00000000-0000-0000-0000-0000000031f1', current_setting('test.org_b')::uuid, 'Secret Head', '<p>Secret</p>');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000031a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Search Org A","slug":"search-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);

select set_config('test.dirty', (public.save_doc('Letter Head', jsonb_build_object(
  'org_id', current_setting('test.org'),
  'letter_head_name', 'Dirty',
  'content', '<p>Hi</p><script>alert(1)</script>'
))) ->> 'id', true);
select is(
  (select content from public.letter_head where letter_head_name = 'Dirty'),
  '<p>Hi</p>',
  'save_doc strips scripts even when the client does not'
);

select is(
  (select label from public.search_link(current_setting('test.org')::uuid, 'Letter Head', 'dirt', '{}')),
  'Dirty',
  'search_link finds a letter head by title in one call'
);
select is(
  (select count(*)::int from public.search_link(
    current_setting('test.org_b')::uuid, 'Letter Head', '', array['00000000-0000-0000-0000-0000000031f1']::uuid[]
  )),
  0,
  'search_link does not return another organization''s rows'
);
select is(
  (select count(*)::int from public.search_link(
    current_setting('test.org')::uuid, 'letter_head; delete from public.organizations; --', '', '{}'
  )),
  0,
  'a crafted doctype name is not executed as SQL'
);
select ok(
  (select count(*) from public.organizations where slug = 'search-org-a') = 1,
  'the crafted doctype did not delete organizations'
);
select is(
  (select label from public.search_link(current_setting('test.org')::uuid, 'User', 'search-owner-a', '{}')),
  'search-owner-a@test.local',
  'User links come from the member directory'
);

select * from finish();
rollback;
