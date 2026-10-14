-- 0003 framework: lock down `app` function privileges; RPC entry points live in `public`.
-- Supabase grants EXECUTE on new functions to anon/authenticated via role-level default privileges, which a
-- schema-level revoke cannot override, so every `app` function must be revoked/granted explicitly.
-- `app` is not an exposed API schema: callable entry points are `public.<fn>` security-invoker wrappers.

revoke usage on schema app from anon;
revoke execute on all functions in schema app from public, anon, authenticated;

-- RLS helpers: policies run as the caller, so authenticated needs EXECUTE (not reachable via the API).
grant execute on function
  app.user_org_ids(), app.is_member(uuid), app.user_roles(uuid), app.orgs_with_role(text),
  app.orgs_with_perm(text, text), app.has_perm(uuid, text, text), app.has_role(uuid, text),
  app.allowed_records(uuid, text, text), app.record_allowed(uuid, text, uuid, text),
  app.company_allowed(uuid, uuid, text), app.accept_invitation(text)
to authenticated;

grant execute on function app.custom_access_token_hook(jsonb) to supabase_auth_admin;

create or replace function public.accept_invitation(p_token text)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select app.accept_invitation(p_token);
$$;

revoke execute on function public.accept_invitation(text) from public, anon;
grant execute on function public.accept_invitation(text) to authenticated;
