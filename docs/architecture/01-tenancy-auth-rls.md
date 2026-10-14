# 01 — Tenancy, Authentication, Permissions, RLS

## Tenancy model

```
organizations (tenant)  1 ──< companies (ERPNext "Company")  1 ──< transactional docs
      │
      └──< org_members (user ↔ org, roles[])  ──< user_permissions (restrict to records)
```

- **Organization** = ERPNext *site*. All data isolation is at `org_id`.
- **Company** = ERPNext *Company*. Several per org are allowed (group companies). Every transactional table and most masters carry `company_id`. Masters that ERPNext keeps company-agnostic (Item, Customer, Supplier, UOM, Item Group, Customer Group, Territory, Supplier Group, Brand, Price List) are org-scoped only; company-specific defaults live in child tables (`item_default`, `party_account`) as in ERPNext.
- Active tenant selection: URL carries the org slug (`/[org]/accounts/...`). Active company is a Zustand session value mirrored in a cookie (`hx_company`) so Server Components can read it.

### Core tables (migration `0002_tenancy.sql`)

```sql
create table organizations (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null check (slug ~ '^[a-z0-9-]{3,40}$'),
  name text not null,
  country text, default_currency text, time_zone text default 'UTC',
  plan text default 'free', status text default 'active',
  created_at timestamptz default now(), updated_at timestamptz default now()
);
create table org_members (
  org_id uuid references organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  roles text[] not null default '{}',          -- ERPNext role names
  is_owner boolean default false,
  status text default 'active',                -- active | invited | disabled
  primary key (org_id, user_id)
);
create table roles (                           -- per org, seeded from defaults, custom roles allowed
  org_id uuid references organizations(id) on delete cascade,
  name text, is_standard boolean default false, primary key (org_id, name)
);
create table role_permissions (                -- mirrors doctype JSON "permissions" (permlevel 0 only)
  org_id uuid, role text, doctype text,
  can_read bool default false, can_write bool default false, can_create bool default false,
  can_submit bool default false, can_cancel bool default false, can_amend bool default false,
  can_delete bool default false, can_report bool default true, can_export bool default true,
  if_owner bool default false,
  primary key (org_id, role, doctype),
  foreign key (org_id, role) references roles(org_id, name) on delete cascade
);
create table user_permissions (                -- ERPNext "User Permission"
  id uuid primary key default gen_random_uuid(),
  org_id uuid, user_id uuid, doctype text, record_id uuid,
  applicable_for text null,                    -- null = all doctypes, else a specific doctype
  is_default bool default false
);
create table invitations (id uuid pk, org_id, email, roles text[], token text unique, expires_at, accepted_at);
```

## Authentication (Supabase Auth + `@supabase/ssr`)

- Providers: email+password, magic link; Google OAuth optional later. Invite flow: owner creates `invitations` row → email with `/invite/[token]` → user signs up/in → Server Action `acceptInvitation()` inserts `org_members`.
- Three clients:
  - `src/lib/supabase/client.ts` — `createBrowserClient` (Client Components).
  - `src/lib/supabase/server.ts` — `createServerClient` with `cookies()` (awaited) for Server Components, Server Actions, Route Handlers.
  - `src/lib/supabase/proxy.ts` — used by `src/proxy.ts` to refresh tokens: call `supabase.auth.getClaims()`, copy refreshed cookies to request and response, apply the `Cache-Control/Expires/Pragma` headers passed to `setAll`.
- **Authorization on the server uses `getClaims()`** (JWT signature verified locally against JWKS). `getSession()` is only acceptable in the browser for UI hints.
- `proxy.ts` responsibilities: refresh session; redirect unauthenticated users from `/(app)` to `/login`; redirect authenticated users without an org to `/setup`; set `x-org-slug` request header for layouts. It never performs data authorization.
- Service-role key is used **only** in: provisioning (`app.provision_organization`, run via a Server Action that first verifies the caller), scheduled jobs (Edge Functions), and tests. It is never imported by code reachable from Client Components (`server-only` import guard).

## Custom claims

Add `org_ids` and a lightweight `roles` map to the JWT via a Supabase **Custom Access Token Hook** (`app.custom_access_token_hook`), so RLS can be evaluated without a join on hot paths:

```json
{ "app": { "orgs": { "<org_uuid>": ["Accounts Manager","Stock User"] } } }
```

RLS helpers read the claim first and fall back to `org_members` when the claim is absent (e.g. right after a role change — we also force a token refresh client-side after role edits).

## RLS helper functions (schema `app`, `security definer`, `stable`)

```sql
app.current_user_id()                 -- auth.uid()
app.user_org_ids()                    -- uuid[] from JWT claim or org_members
app.is_member(org_id)                 -- boolean
app.user_roles(org_id)                -- text[]
app.has_perm(org_id, doctype, action) -- action in read|write|create|submit|cancel|amend|delete
app.record_allowed(org_id, doctype, record_id)  -- user_permissions check (empty = allowed)
app.company_allowed(org_id, company_id)         -- shortcut for the most common user permission
```

Performance: functions are `stable`, wrapped as `(select app.is_member(org_id))` in policies so Postgres evaluates them once per statement; `org_id` is the leading column of every index.

## Policy template (apply to EVERY tenant table)

```sql
alter table sales_invoice enable row level security;
alter table sales_invoice force row level security;

create policy si_select on sales_invoice for select using (
  (select app.has_perm(org_id, 'Sales Invoice', 'read'))
  and (select app.company_allowed(org_id, company_id))
);
create policy si_insert on sales_invoice for insert with check (
  (select app.has_perm(org_id, 'Sales Invoice', 'create'))
  and (select app.company_allowed(org_id, company_id)) and docstatus = 0
);
create policy si_update on sales_invoice for update using (
  (select app.has_perm(org_id, 'Sales Invoice', 'write')) and docstatus = 0
) with check (docstatus = 0);
create policy si_delete on sales_invoice for delete using (
  (select app.has_perm(org_id, 'Sales Invoice', 'delete')) and docstatus = 0
);
```

Rules:
- Direct `update` is only possible while `docstatus = 0`. Submission, cancellation and amendment go through `app.submit_doc()` / `app.cancel_doc()` / `app.amend_doc()` which are `security definer` and perform their own `app.has_perm(..., 'submit'|'cancel'|'amend')` check before touching rows (so `docstatus` transitions never happen through table policies).
- Child tables get policies that delegate to the parent: `exists (select 1 from sales_invoice p where p.id = parent_id)` — RLS on the parent handles the rest.
- Ledger tables (`gl_entry`, `stock_ledger_entry`, `payment_ledger_entry`, `bin`): `select` only for members with the relevant read permission; no insert/update/delete policies — only `app.*` functions write to them.
- Global reference tables (`currency`, `country`, `uom_template`, `coa_template`): `select` for all authenticated users; writes only via migrations/service role.
- Storage buckets: `org-files` with path prefix `${org_id}/…` and policies checking `app.is_member((storage.foldername(name))[1]::uuid)`.

## Default role → doctype matrix

Seeded per org from a JSON generated out of the ERPNext doctype JSON `permissions` arrays (script in `scripts/extract-erpnext-perms.ps1`, output `supabase/seed/role_permissions.json`). Only roles in this list are seeded: System Manager, Accounts Manager, Accounts User, Auditor, Sales Manager, Sales User, Purchase Manager, Purchase User, Stock Manager, Stock User, Item Manager, Manufacturing Manager, Manufacturing User, Projects Manager, Projects User, Maintenance Manager, Maintenance User, Quality Manager (only for Quality Inspection if pulled in), Employee (read-only self stuff; minimal). The org owner is always System Manager.

Role Profiles (quick-assign bundles, from `setup/install.py`): Inventory, Manufacturing, Accounts, Sales, Purchase.

## Testing RLS

- `supabase/tests/rls_*.sql` (pgTAP): for every table, assert that user A in org 1 cannot `select/insert/update/delete` rows of org 2, and that a Sales User cannot update a submitted Sales Invoice.
- A generated test enumerates `pg_tables` in `public` and fails if any table has `rowsecurity = false` or no policies.
- Supabase MCP `get_advisors` (security) must return no RLS/`security definer` view warnings before a migration is merged.
