-- 0223 accounts: delete payment terms templates before their terms when an organization goes.
-- A template row references the term, and organization cascade does not promise that order.

create or replace function app.organizations_clear_payment_terms()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.payment_terms_template where org_id = old.id;
  return old;
end;
$$;

revoke execute on function app.organizations_clear_payment_terms() from public, anon, authenticated;

drop trigger if exists organizations_clear_payment_terms on public.organizations;
create trigger organizations_clear_payment_terms
  before delete on public.organizations
  for each row execute function app.organizations_clear_payment_terms();
