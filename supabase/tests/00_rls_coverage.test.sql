begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

select is(
  (select array_agg(c.relname::text order by c.relname)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not (c.relrowsecurity and c.relforcerowsecurity)),
  null,
  'every public table has RLS enabled and forced'
);

select is(
  (select array_agg(c.relname::text order by c.relname)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and not exists (select 1 from pg_policy p where p.polrelid = c.oid)),
  null,
  'every public table has at least one policy'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and has_function_privilege('anon', p.oid, 'execute')),
  null,
  'anon cannot execute any app function'
);

select ok(
  not has_function_privilege('authenticated', 'app.custom_access_token_hook(jsonb)', 'execute')
  and has_function_privilege('supabase_auth_admin', 'app.custom_access_token_hook(jsonb)', 'execute'),
  'only the auth service can run the access token hook'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef and p.proname <> 'rls_auto_enable'),
  null,
  'public RPC entry points are security invoker'
);

select * from finish();
rollback;
