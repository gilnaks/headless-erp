-- 0123 setup: Email Account -> public.email_account (outbound only, Resend) + public.email_log (docs/modules/00-setup.md §2.14).
-- ERPNext sources: erpnext/setup/install.py (create_custom_company_links: Email Account `company`; default_mail_footer).
-- Frappe Email Account (frappe/email/doctype/email_account: default_outgoing "only one", enable_outgoing,
-- always_use_account_email_id_as_sender, always_use_account_name_as_sender_name, add_signature/signature, footer) and
-- Email Queue / Communication (send log) ported from memory: the frappe repository is not cloned.
--
-- The provider API key lives in Supabase Vault; the row keeps only the secret id. API roles can set the key
-- (`set_email_account_key`) but never read it; sending reads it with the service role (`email_sender`).

create table if not exists public.email_account (
  id                                     uuid primary key default gen_random_uuid(),
  org_id                                 uuid not null references public.organizations (id) on delete cascade,
  email_account_name                     text not null check (length(trim(email_account_name)) > 0),
  email_id                               text not null check (email_id ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  company_id                             uuid,
  provider                               text not null default 'resend' check (provider in ('resend')),
  api_key_secret                         uuid,
  has_api_key                            boolean generated always as (api_key_secret is not null) stored,
  enable_outgoing                        boolean not null default true,
  default_outgoing                       boolean not null default false,
  always_use_account_email_id_as_sender  boolean not null default false,
  always_use_account_name_as_sender_name boolean not null default false,
  add_signature                          boolean not null default false,
  signature                              text,
  footer                                 text,
  enabled                                boolean not null default true,
  created_at                             timestamptz not null default now(),
  created_by                             uuid default auth.uid(),
  updated_at                             timestamptz not null default now(),
  updated_by                             uuid,
  unique (org_id, id),
  foreign key (org_id, company_id) references public.companies (org_id, id) on delete set null (company_id)
);

create unique index if not exists email_account_name_uniq on public.email_account (org_id, lower(email_account_name));
create unique index if not exists email_account_default_uniq on public.email_account (org_id) where default_outgoing;
create index if not exists email_account_company_idx on public.email_account (company_id);

-- Frappe EmailAccount.validate: trims; `default_outgoing` needs outgoing enabled and clears the previous default
-- (definer: the cleared row may be hidden from the caller). The secret id only changes inside set_email_account_key.
create or replace function app.email_account_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.email_account_name := trim(new.email_account_name);
  new.email_id := lower(trim(new.email_id));
  if new.email_id !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception using errcode = 'P0001', message = 'invalid_email: Enter a valid email address';
  end if;
  new.signature := nullif(trim(new.signature), '');
  new.footer := nullif(trim(new.footer), '');
  if current_setting('app.email_secret_write', true) is distinct from 'on' then
    new.api_key_secret := case when tg_op = 'INSERT' then null else old.api_key_secret end;
  end if;

  if pg_trigger_depth() > 1 then
    return new;
  end if;
  if new.default_outgoing and not (new.enabled and new.enable_outgoing) then
    raise exception using errcode = 'P0001',
      message = 'email_default_disabled: The default outgoing account must be enabled for outgoing email';
  end if;
  if new.default_outgoing then
    update public.email_account a set default_outgoing = false
     where a.org_id = new.org_id and a.default_outgoing and a.id <> new.id;
  end if;
  return new;
end;
$$;

-- The deleted account's key goes with it.
create or replace function app.email_account_drop_secret()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.api_key_secret is not null then
    delete from vault.secrets s where s.id = old.api_key_secret;
  end if;
  return old;
end;
$$;

-- Stores (or replaces) the account's provider key in Vault. Callers need write on Email Account (RLS on the row read).
create or replace function app.set_email_account_key(p_id uuid, p_secret text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.email_account;
  v_secret uuid;
begin
  select * into v from public.email_account where id = p_id;
  if not found or not app.has_perm(v.org_id, 'Email Account', 'write') then
    raise exception using errcode = '42501', message = 'permission_denied: not permitted to change this Email Account';
  end if;
  if p_secret is null or length(trim(p_secret)) = 0 then
    raise exception using errcode = 'P0001', message = 'email_key_required: Enter the API key';
  end if;

  if v.api_key_secret is not null and exists (select 1 from vault.secrets s where s.id = v.api_key_secret) then
    perform vault.update_secret(v.api_key_secret, trim(p_secret));
  else
    v_secret := vault.create_secret(trim(p_secret), 'email_account:' || p_id::text, 'Email Account API key');
    perform set_config('app.email_secret_write', 'on', true);
    update public.email_account set api_key_secret = v_secret where id = p_id;
    perform set_config('app.email_secret_write', 'off', true);
  end if;
end;
$$;

create or replace function public.set_email_account_key(p_id uuid, p_secret text)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.set_email_account_key(p_id, p_secret);
$$;

-- Sending account for a message (service role only, it returns the key). Frappe get_outgoing_email_account:
-- the given account, else the company's default-outgoing (or only) account, else the org default. Enabled
-- accounts with outgoing on and a stored key only; no row = use the platform sender.
create or replace function app.email_sender(p_org uuid, p_company uuid default null, p_account uuid default null)
returns table (
  email_account_id uuid, email_account_name text, email_id text, api_key text,
  always_use_account_email_id_as_sender boolean, always_use_account_name_as_sender_name boolean,
  add_signature boolean, signature text, footer text
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.email_account_name, a.email_id, s.decrypted_secret,
         a.always_use_account_email_id_as_sender, a.always_use_account_name_as_sender_name,
         a.add_signature, a.signature, a.footer
    from public.email_account a
    join vault.decrypted_secrets s on s.id = a.api_key_secret
   where a.org_id = p_org and a.enabled and a.enable_outgoing
     and (case when p_account is not null then a.id = p_account
               else (p_company is not null and a.company_id = p_company) or a.default_outgoing end)
   order by (a.company_id = p_company) is true desc, a.default_outgoing desc, a.created_at
   limit 1;
$$;

create or replace function public.email_sender(p_org uuid, p_company uuid default null, p_account uuid default null)
returns table (
  email_account_id uuid, email_account_name text, email_id text, api_key text,
  always_use_account_email_id_as_sender boolean, always_use_account_name_as_sender_name boolean,
  add_signature boolean, signature text, footer text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app.email_sender(p_org, p_company, p_account);
$$;

------------------------------------------------------------------------------------------------------------------------
-- Send log (Frappe Email Queue / Communication, reduced): written by the server's sending module (service role),
-- append-only; System Managers read all of the org's rows, senders their own.
------------------------------------------------------------------------------------------------------------------------

create table if not exists public.email_log (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations (id) on delete cascade,
  email_account_id    uuid references public.email_account (id) on delete set null,
  sender              text not null,
  reference_doctype   text,
  reference_id        uuid,
  recipients          text[] not null,
  cc                  text[] not null default '{}',
  subject             text not null,
  status              text not null check (status in ('Sent', 'Error')),
  provider_message_id text,
  error               text,
  sent_by             uuid references auth.users (id) on delete set null,
  created_at          timestamptz not null default now()
);

create index if not exists email_log_org_idx on public.email_log (org_id, created_at desc);
create index if not exists email_log_reference_idx on public.email_log (reference_doctype, reference_id);
create index if not exists email_log_account_idx on public.email_log (email_account_id);
create index if not exists email_log_sent_by_idx on public.email_log (sent_by);

revoke update, delete, truncate on public.email_log from anon, authenticated, service_role;

revoke execute on function
  app.email_account_validate(), app.email_account_drop_secret(), app.set_email_account_key(uuid, text),
  public.set_email_account_key(uuid, text), app.email_sender(uuid, uuid, uuid), public.email_sender(uuid, uuid, uuid)
from public, anon, authenticated;
grant execute on function app.set_email_account_key(uuid, text), public.set_email_account_key(uuid, text) to authenticated;
grant execute on function app.email_sender(uuid, uuid, uuid), public.email_sender(uuid, uuid, uuid) to service_role;

drop trigger if exists email_account_validate on public.email_account;
create trigger email_account_validate
  before insert or update on public.email_account
  for each row execute function app.email_account_validate();

drop trigger if exists touch_updated on public.email_account;
create trigger touch_updated
  before update on public.email_account
  for each row execute function app.touch_updated();

drop trigger if exists email_account_drop_secret on public.email_account;
create trigger email_account_drop_secret
  after delete on public.email_account
  for each row execute function app.email_account_drop_secret();

alter table public.email_account enable row level security;
alter table public.email_account force row level security;
alter table public.email_log enable row level security;
alter table public.email_log force row level security;

drop policy if exists email_account_select on public.email_account;
create policy email_account_select on public.email_account for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Email Account', 'read'))::uuid[]));
drop policy if exists email_account_insert on public.email_account;
create policy email_account_insert on public.email_account for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Email Account', 'create'))::uuid[]));
drop policy if exists email_account_update on public.email_account;
create policy email_account_update on public.email_account for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Email Account', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Email Account', 'write'))::uuid[]));
drop policy if exists email_account_delete on public.email_account;
create policy email_account_delete on public.email_account for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Email Account', 'delete'))::uuid[]));

drop policy if exists email_log_select on public.email_log;
create policy email_log_select on public.email_log for select to authenticated
  using (sent_by = (select auth.uid()) or org_id = any ((select app.orgs_with_perm('Email Account', 'read'))::uuid[]));

------------------------------------------------------------------------------------------------------------------------
-- Registry & default permissions (Frappe Email Account JSON: System Manager rwcd)
------------------------------------------------------------------------------------------------------------------------

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Email Account', 'email_account', 'setup', 'email_account_name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values ('System Manager', 'Email Account', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
