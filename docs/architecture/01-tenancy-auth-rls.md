# 01 — Tenancy, Authentication, Permissions, RLS

## Tenancy model

```
organizations (tenant)  1 ──< companies (ERPNext "Company")  1 ──< transactional docs
      │
      └──< org_members (user ↔ org, roles[])  ──< user_permissions (restrict to records)
```

- **Organization** = ERPNext *site*. All data isolation is at `org_id`.
- **Company** = ERPNext *Company*. Several per org are allowed (group companies). Every transactional table and most masters carry `company_id`. Masters that ERPNext keeps company-agnostic (Item, Customer, Supplier, UOM, Item Group, Customer Group, Territory, Supplier Group, Brand, Price List) are org-scoped only; company-specific defaults live in child tables (`item_default`, `party_account`) as in ERPNext.
- Active tenant selection: URL carries the org slug (`/[org]/accounts/...`). Active company is a Zustand session value persisted in `localStorage` (`hx_company`, per org).

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

## Authentication (Supabase Auth, browser session)

- Providers: email+password, magic link; Google OAuth optional later. Invite flow: owner creates `invitations` row → email with `/invite/[token]` → user signs up/in → `acceptInvitation()` calls the `accept_invitation` RPC, which inserts `org_members`.
- One app client: `src/lib/supabase/client.ts` (`createClient` from `@supabase/supabase-js`, persist session in `localStorage`, `autoRefreshToken`). The publishable key is `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY`. There is no cookie client and no `proxy.ts`.
- **Authorization is RLS.** The JWT is a hint. `getSession()` may drive route guards and button visibility; it must not be the only check on a write. Access tokens stay short-lived (Supabase default 1 hour or less). A strict Content-Security-Policy is set on the static host (see `06-deployment-ops.md`) so a script cannot read `localStorage` from another origin.
- Route guards (TanStack Router `beforeLoad`): public paths are `/login`, `/signup`, `/forgot-password`, `/update-password`, `/auth/callback`, `/invite/$token`. Anywhere else, a signed-out user goes to `/login?next=<path>`. Signed-in users leave `/login` and `/signup`. A signed-in user with no org in their claims who opens `/` goes to `/setup`. Guards do not authorize rows. The org layout loads the org through RLS (unknown or foreign slug → not found).
- `/auth/callback` is a client route. It accepts a PKCE `code` (`exchangeCodeForSession`) or `token_hash` + `type` (`verifyOtp`), then navigates to a sanitised same-origin `next` (`src/lib/auth/redirect.ts`), or to `/login?error=link_invalid`. Hosted projects must list `<APP_URL>/auth/callback**` in `additional_redirect_urls` (`supabase/config.toml`, pushed with `supabase config push`). Sign-out is `supabase.auth.signOut()` from the user menu, then navigate to `/login`.
- After `provision_organization` or `accept_invitation` the client calls `supabase.auth.refreshSession()` so the new membership appears in the `app.orgs` claim before navigating to `/[slug]`.
- Organizations are created by `app.provision_organization(jsonb)` (`0116`, 00-setup §3.1), which runs as the signed-in user (security definer, no service role) and calls `app.create_organization(jsonb)` (`0005`) as its Stage A (the P0 `public.create_organization` RPC was dropped in `0117`). That function inserts `organizations`, syncs role permissions and adds the caller as owner with `System Manager`. Slugs match `^[a-z0-9-]{3,40}$` and may not collide with top-level routes (`app.reserved_slugs()`, `0006`; mirrored in `src/lib/schemas/organization.ts`).
- Dev helper: `node scripts/dev-user.mjs <email> <password>` creates a confirmed user, and `--magic-link <email>` prints a sign-in URL, because the hosted mailer is rate-limited and rejects reserved domains such as `.test`. It reads the service-role key from `.env.local` and is never imported by app code.
- Service-role key is used **only** in: Edge Functions, dev scripts, and tests. It is never prefixed `VITE_` and never imported by `src/`. Email sending moves to an Edge Function that reads Vault; the browser calls that function with the user JWT. Provisioning does not need the service role: the signed-in client calls `provision_organization`.

## Custom claims

Add `org_ids` and a lightweight `roles` map to the JWT via a Supabase **Custom Access Token Hook** (`app.custom_access_token_hook`), so RLS can be evaluated without a join on hot paths:

```json
{ "app": { "orgs": { "<org_uuid>": ["Accounts Manager","Stock User"] } } }
```

The claim is for **UI hints only** (`can()` to hide buttons). RLS helpers always read `org_members`/`role_permissions` (security definer, PK-indexed), so removing a member or a role takes effect immediately instead of when the access token expires. The org layout reads the caller's `org_members.roles` (own row, readable through RLS), not the claim. When the two differ (`rolesDiffer` in `src/lib/auth/orgs.ts`), `ClaimsRefresher` calls `supabase.auth.refreshSession()` once per roles signature (guarded in `sessionStorage`), so the token catches up after role edits without a refresh loop.

The hook is enabled in `supabase/config.toml` (`[auth.hook.custom_access_token]`) and pushed to hosted projects with `supabase config push`.

## Function privileges & RPC surface

- Schema `app` is **not** an exposed API schema. Supabase grants `EXECUTE` on new functions to `anon`/`authenticated` through role-level default privileges, so every `app` function is revoked from `public, anon, authenticated` and granted back explicitly (`0003_framework_function_grants.sql`): RLS helpers → `authenticated` (policies run as the caller), the token hook → `supabase_auth_admin` only, trigger functions → nobody.
- Callable entry points (`accept_invitation`, `save_doc`, `submit_doc`, `cancel_doc`, `amend_doc`, `map_doc`, `search_link`) are thin `security invoker` wrappers in `public` that delegate to the implementation in `app`, so the browser calls `supabase.rpc('submit_doc', …)` and the advisors stay clean. `search_link` stays invoker end to end so RLS applies to the rows it returns.
- pgTAP (`00_rls_coverage.test.sql`) also fails when a table with `org_id` has no `doctype_meta` row (exempt: `email_log`, `invitations`, `onboarding_progress`, `org_currency`, `role_permissions`, `gl_entry`, `payment_ledger_entry`), when a tenant doctype has no System Manager read template (exempt: Naming Series, authorized by role), or when a policy on a tenant table neither filters on `org_id` nor (child tables) on `parent_id`. Add new non-document tenant tables to the exemption list deliberately.
- pgTAP (`00_rls_coverage.test.sql`) fails if `anon` can execute any `app` function or if a `public` function is `security definer`. Known exception: `public.rls_auto_enable()`, the Supabase-managed event-trigger function behind the "auto-enable RLS" project setting (hosted only, not callable as RPC).

## RLS helper functions (schema `app`, `security definer`, `stable`)

Implemented in `supabase/migrations/0002_framework_tenancy.sql`:

```sql
app.user_org_ids()                    -- uuid[] of orgs where the user is an active member
app.is_member(org_id)                 -- boolean
app.user_roles(org_id)                -- text[] (disabled roles excluded)
app.orgs_with_perm(doctype, action)   -- uuid[] of orgs where the user has the permission
app.orgs_with_role(role)              -- uuid[] of orgs where the user holds the role
app.has_perm(org_id, doctype, action) -- action in read|write|create|submit|cancel|amend|delete|report|export
app.has_role(org_id, role)            -- boolean
app.allowed_records(org_id, doctype, applicable_for)       -- uuid[] or null (= unrestricted)
app.record_allowed(org_id, doctype, record_id, applicable_for) -- user_permissions check (none = allowed)
app.company_allowed(org_id, company_id, applicable_for)    -- shortcut for the most common user permission
```

`app.allowed_records` (from `0109`) uses the caller's rows for `doctype` whose `applicable_for` is null or equals
`applicable_for` (default: `doctype` itself, so a doctype's own list honours rows scoped to it). On tree doctypes
(`doctype_meta.is_tree`) each record expands to its descendants through the `path` ltree unless the row has
`hide_descendants`. It runs once per row in `company_allowed(org_id, id)` policies, which is fine for masters such
as Company; high-volume transaction tables should compare against the array once per statement
(`company_id = any ((select app.allowed_records(...))::uuid[])` plus the null-allowed and unrestricted cases).

Performance: policies compare the row's `org_id` against an array computed once per statement — `org_id = any ((select app.orgs_with_perm('Sales Invoice', 'read'))::uuid[])` (the cast makes it a scalar subquery; without it Postgres treats `any (select …)` as a row set) — instead of calling `app.has_perm(org_id, …)` per row. `app.has_perm()` remains the API for `app.*` functions. `org_id` is the leading column of every index. Policies are granted `to authenticated` only; `anon` never sees tenant rows.

## Policy template (apply to EVERY tenant table)

```sql
alter table sales_invoice enable row level security;
alter table sales_invoice force row level security;

create policy si_select on sales_invoice for select to authenticated using (
  org_id = any ((select app.orgs_with_perm('Sales Invoice', 'read'))::uuid[])
  and app.company_allowed(org_id, company_id)
);
create policy si_insert on sales_invoice for insert to authenticated with check (
  org_id = any ((select app.orgs_with_perm('Sales Invoice', 'create'))::uuid[])
  and app.company_allowed(org_id, company_id) and docstatus = 0
);
create policy si_update on sales_invoice for update to authenticated using (
  org_id = any ((select app.orgs_with_perm('Sales Invoice', 'write'))::uuid[]) and docstatus = 0
) with check (docstatus = 0);
create policy si_delete on sales_invoice for delete to authenticated using (
  org_id = any ((select app.orgs_with_perm('Sales Invoice', 'delete'))::uuid[]) and docstatus = 0
);
```

Rules:
- Direct `update` is only possible while `docstatus = 0`. Submission, cancellation and amendment go through `app.submit_doc()` / `app.cancel_doc()` / `app.amend_doc()` which are `security definer` and perform their own `app.has_perm(..., 'submit'|'cancel'|'amend')` check before touching rows (so `docstatus` transitions never happen through table policies).
- Child tables get policies that delegate to the parent: `exists (select 1 from sales_invoice p where p.id = parent_id)` — RLS on the parent handles the rest.
- Ledger tables (`gl_entry`, `stock_ledger_entry`, `payment_ledger_entry`, `bin`): `select` only for members with the relevant read permission; no insert/update/delete policies — only `app.*` functions write to them.
- Global reference tables (`currency`, `country`, `uom_template`, `coa_template`): `select` for all authenticated users; writes only via migrations/service role.
- Storage buckets: `org-files` with path prefix `${org_id}/…` and policies checking `app.is_member((storage.foldername(name))[1]::uuid)`.

## Default role → doctype matrix

Seeded per org from the global `role_permission_template` table, which each doctype migration fills from its ERPNext doctype JSON `permissions` array; `app.sync_role_permissions(org_id | null)` copies missing rows into orgs (existing tenants receive new doctypes' defaults; tenant edits are never overwritten). Only roles in this list are seeded: System Manager, Accounts Manager, Accounts User, Auditor, Sales Manager, Sales User, Purchase Manager, Purchase User, Stock Manager, Stock User, Item Manager, Manufacturing Manager, Manufacturing User, Projects Manager, Projects User, Maintenance Manager, Maintenance User, Quality Manager (only for Quality Inspection if pulled in), Employee (read-only self stuff; minimal). The org owner is always System Manager.

Role Profiles (quick-assign bundles, from `setup/install.py`): Inventory, Manufacturing, Accounts, Sales, Purchase.

## Testing RLS

- `supabase/tests/rls_*.sql` (pgTAP): for every table, assert that user A in org 1 cannot `select/insert/update/delete` rows of org 2, and that a Sales User cannot update a submitted Sales Invoice.
- A generated test enumerates `pg_tables` in `public` and fails if any table has `rowsecurity = false` or no policies.
- Supabase MCP `get_advisors` (security) must return no RLS/`security definer` view warnings before a migration is merged.
