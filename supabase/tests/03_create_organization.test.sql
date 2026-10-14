begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'founder@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);

select is(
  public.create_organization('{"name":"  Acme Inc ","slug":"Acme-Inc","country":"Netherlands","default_currency":"eur"}') ->> 'slug',
  'acme-inc',
  'creates the organization and normalises the slug'
);

select results_eq(
  $$select name, country, default_currency, time_zone from public.organizations where slug = 'acme-inc'$$,
  $$values ('Acme Inc', 'Netherlands', 'EUR', 'UTC')$$,
  'organization fields are stored and defaulted'
);

select results_eq(
  $$select roles, is_owner from public.org_members m join public.organizations o on o.id = m.org_id where o.slug = 'acme-inc'$$,
  $$values ('{System Manager}'::text[], true)$$,
  'caller becomes the owner with System Manager'
);

select ok(
  (select count(*) from public.roles r join public.organizations o on o.id = r.org_id where o.slug = 'acme-inc')
    = (select count(*) from public.role_template),
  'standard roles are seeded'
);

select ok(
  app.has_perm((select id from public.organizations where slug = 'acme-inc'), 'Company', 'create'),
  'default permissions are seeded (owner can create companies)'
);

select throws_ok(
  $$select public.create_organization('{"name":"Again","slug":"acme-inc"}')$$,
  'P0001', 'slug_taken: this URL is already in use', 'slugs are unique'
);

select throws_ok(
  $$select public.create_organization('{"name":"Bad","slug":"a b"}')$$,
  'P0001', 'invalid_slug: use 3-40 lowercase letters, digits or dashes', 'slug format is validated'
);

reset role;
select ok(
  not has_function_privilege('anon', 'public.create_organization(jsonb)', 'execute'),
  'anon cannot create organizations'
);

select * from finish();
rollback;
