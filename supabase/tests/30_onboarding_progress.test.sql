begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000030a1', 'onboard-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000030a2', 'onboard-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000030b1', 'onboard-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000030b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Onboard Org B","slug":"onboard-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000030a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Onboard Org A","slug":"onboard-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000030a2', '{Sales User}');

select is(
  (select array_agg(step order by idx) from public.onboarding_progress where org_id = current_setting('test.org')::uuid),
  array['invite_users', 'accounting', 'selling', 'buying', 'stock', 'manufacturing', 'projects', 'assets'],
  'new organizations get the onboarding steps in order'
);
select is(
  (select count(*)::int from public.onboarding_progress where completed_at is not null or skipped_at is not null),
  0, 'no step starts done'
);

do $$ begin
  perform app.create_invitation(current_setting('test.org')::uuid, 'new-hire@test.local', '{Sales User}', '');
end $$;
select isnt(
  (select completed_at from public.onboarding_progress where org_id = current_setting('test.org')::uuid and step = 'invite_users'),
  null, 'inviting a user completes Invite Users'
);

select lives_ok(
  format($$select public.onboarding_skip(%L, 'stock')$$, current_setting('test.org')),
  'System Managers skip steps'
);
select isnt(
  (select skipped_at from public.onboarding_progress where org_id = current_setting('test.org')::uuid and step = 'stock'),
  null, 'the skipped step is recorded'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000030a2","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.onboarding_progress where org_id = current_setting('test.org')::uuid),
  8, 'members read the checklist'
);
select throws_ok(
  format($$select public.onboarding_skip(%L, 'selling')$$, current_setting('test.org')),
  '42501', null, 'other roles cannot skip steps'
);
select throws_ok(
  format($$select public.onboarding_dismiss(%L)$$, current_setting('test.org')),
  '42501', null, 'other roles cannot dismiss the checklist'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000030a1","role":"authenticated"}', true);
do $$ begin
  perform public.onboarding_dismiss(current_setting('test.org')::uuid);
end $$;
select isnt(
  (select onboarding_dismissed_at from public.organizations where id = current_setting('test.org')::uuid),
  null, 'System Managers dismiss the checklist'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000030b1","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.onboarding_progress where org_id = current_setting('test.org')::uuid),
  0, 'other organizations do not see the checklist'
);

select * from finish();
rollback;
