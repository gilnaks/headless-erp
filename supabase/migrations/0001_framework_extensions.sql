-- 0001 framework: extensions, `app` schema, audit trigger.

create extension if not exists ltree with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create schema if not exists app;
grant usage on schema app to anon, authenticated, service_role;

-- Functions in `app` are not executable by default; each function grants explicitly.
alter default privileges in schema app revoke execute on functions from public;

-- Maintains updated_at/updated_by on every tenant table.
create or replace function app.touch_updated()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;
