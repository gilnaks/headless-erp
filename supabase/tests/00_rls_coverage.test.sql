begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

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

-- Tenant tables that are not documents: logs, membership plumbing and per-org flags with their own policies.
select is(
  (select array_agg(c.relname::text order by c.relname)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and exists (select 1 from pg_attribute a where a.attrelid = c.oid and a.attname = 'org_id' and not a.attisdropped)
      and not exists (select 1 from public.doctype_meta d where d.table_name = c.relname)
      and c.relname <> all (array[
        'bin', 'email_log', 'gl_entry', 'invitations', 'onboarding_progress', 'org_currency',
        'payment_ledger_entry', 'role_permissions', 'stock_ledger_entry'
      ])),
  null,
  'every tenant table is registered in doctype_meta (or explicitly exempt)'
);

select is(
  (select array_agg(d.doctype order by d.doctype) from public.doctype_meta d
    where to_regclass('public.' || quote_ident(d.table_name)) is null),
  null,
  'every doctype_meta table exists'
);

-- Naming Series is authorized by role (app.orgs_with_role), not by role_permissions.
select is(
  (select array_agg(d.doctype order by d.doctype) from public.doctype_meta d
    where not d.is_child and d.doctype <> 'Naming Series'
      and exists (select 1 from information_schema.columns c
                   where c.table_schema = 'public' and c.table_name = d.table_name and c.column_name = 'org_id')
      and not exists (select 1 from public.role_permission_template t
                       where t.doctype = d.doctype and t.role = 'System Manager' and t.can_read)),
  null,
  'every tenant doctype grants System Manager read by default'
);

-- Child tables defer to the parent row's policy (parent_id); everything else filters on org_id.
select is(
  (select array_agg(c.relname || '.' || p.polname order by c.relname, p.polname)
     from pg_policy p
     join pg_class c on c.oid = p.polrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and exists (select 1 from pg_attribute a where a.attrelid = c.oid and a.attname = 'org_id' and not a.attisdropped)
      and (
        coalesce(pg_get_expr(p.polqual, p.polrelid), '') in ('true', '(true)')
        or coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') in ('true', '(true)')
        or (coalesce(pg_get_expr(p.polqual, p.polrelid), '') || ' ' || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''))
           !~ '(org_id|parent_id)'
      )),
  null,
  'tenant table policies filter on org_id (child tables on their parent)'
);

select * from finish();
rollback;
