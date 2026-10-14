# 02 — Database & Doctype Conventions

## Naming

| ERPNext | Postgres | TypeScript |
|---|---|---|
| DocType `Sales Invoice` | table `sales_invoice` | `doctype: 'Sales Invoice'`, slug `sales-invoice`, file `src/doctypes/accounts/sales-invoice.ts` |
| Child `Sales Invoice Item` | `sales_invoice_item` | child key `items` (ERPNext `parentfield`) |
| field `posting_date` | `posting_date` (same snake_case as ERPNext) | `postingDate` only at the UI boundary if needed; prefer keeping snake_case in generated types |
| Link to `Customer` | `customer_id uuid` (+ denormalised `customer_name text` where ERPNext stores it) | |
| Dynamic Link `party_type`/`party` | `party_type text`, `party_id uuid` | |
| `name` (human id) | `name text` unique per org | shown as the document title |

Keep ERPNext fieldnames wherever a field is carried over; it keeps the ERPNext repo greppable while porting.

## Base columns

Every tenant table:

```sql
id          uuid primary key default gen_random_uuid(),
org_id      uuid not null references organizations(id) on delete cascade,
created_at  timestamptz not null default now(),
created_by  uuid default auth.uid(),
updated_at  timestamptz not null default now(),
updated_by  uuid
```

Master doctypes add: `name text not null`, `disabled boolean default false`, `unique (org_id, name)`.

Company-scoped masters add `company_id uuid not null references companies(id)`.

Submittable transactional doctypes add:

```sql
company_id     uuid not null references companies(id),
name           text,                        -- null while draft (shown as "New Sales Invoice"), assigned on submit
naming_series  text not null,               -- e.g. 'ACC-SINV-.YYYY.-'
docstatus      smallint not null default 0 check (docstatus in (0,1,2)),
status         text not null default 'Draft',
amended_from   uuid references <same table>(id),
posting_date   date not null, posting_time time,
submitted_at   timestamptz, submitted_by uuid, cancelled_at timestamptz, cancelled_by uuid,
remarks text
unique (org_id, name) where name is not null
```

Child tables:

```sql
id uuid pk, org_id uuid not null, parent_id uuid not null references <parent>(id) on delete cascade,
idx int not null, …fields…
unique (parent_id, idx) deferrable initially deferred
```

Tree doctypes add `parent_id uuid`, `is_group boolean`, `lft/rgt` are **not** used; instead `path extensions.ltree not null` maintained by the generic triggers from `0004_framework_tree_and_role_templates.sql`: `before insert or update … app.tree_maintain_path('<DocType>')` (parent must exist in the same org and be a group, no cycles, a group with children cannot become a leaf, `path` is always recomputed so direct writes are ignored) and `after update … app.tree_update_descendants()` (re-paths the subtree on re-parent, as definer so rows hidden by user permissions move too). Subtree query: `where path <@ (select path from account where id = $1)`; index `using gist (path)`.

**Cross-tenant links:** every table gets `unique (org_id, id)`, and links to tenant tables are composite FKs `foreign key (org_id, <x>_id) references <t> (org_id, id)` so a row can never point at another org's record, regardless of RLS.

**Default permissions:** each doctype migration upserts its rows into the global `role_permission_template` (from the ERPNext doctype JSON `permissions`, permlevel 0) and ends with `select app.sync_role_permissions();`, which copies missing standard roles (`role_template`) and permission rows into every org without overwriting tenant edits. Provisioning calls it for the new org.

Settings ("Single") doctypes: table `<module>_settings` with `org_id` primary key (or `(org_id, company_id)` when ERPNext stores company-specific values), one row inserted by provisioning with ERPNext defaults.

## Types

- Money: `numeric(21,9)` in DB; precision for display/rounding from `companies.currency_precision` (default 2) and system float precision (default 3 for qty/rate, 9 for conversion factors) — same defaults as ERPNext.
- Quantities / rates: `numeric(21,9)`.
- Dates: `date` for posting dates (ERPNext semantics), `timestamptz` for audit. `posting_datetime generated always as (posting_date + coalesce(posting_time,'00:00'))` on ledgers for ordering.
- Booleans instead of ERPNext `Check` ints.
- Enums: `text` + `check` constraint with the exact ERPNext option labels (`'To Deliver and Bill'`, etc.) so status strings match the docs.
- JSON only for genuinely unstructured data (print format layout, dashboard filters).

## Document lifecycle (replicates Frappe)

```
Draft (0) ── save/update freely ──► Submit ──► Submitted (1) ──► Cancel ──► Cancelled (2) ──► Amend ──► new Draft (amended_from = old)
Delete allowed only in Draft.      │
                                   └─ "allow_on_submit" fields may still change (whitelist per doctype)
```

Generic SQL entry points:

**Built (P0):**

- `app.save_doc(doctype text, payload jsonb) → {id, name}` (`0008_framework_doc_engine.sql`, exposed as `public.save_doc` RPC) — **security invoker**: the table's own RLS insert/update policies (`has_perm`, `company_allowed`, user permissions) authorize the write, so it never widens what PostgREST would allow. Insert when `payload.id` is absent (requires `payload.org_id`), else update. Only real, non-generated columns present in the payload are written (allow-list from `information_schema`); system columns (`id, org_id, created_*, updated_*, docstatus, path, amended_from, submitted_*, cancelled_*`, plus `name` on submittables) are always ignored. Submitted rows only accept changes to `doctype_meta.allow_on_submit` fields (`update_after_submit`), cancelled rows are read-only (`cancelled_readonly`). Child rows (`doctype_meta.is_child`, `parent_doctype`, new column `child_field` = payload key) are replaced in the same transaction: rows with a known `id` are updated in place (stable ids for `so_detail`-style links), missing rows deleted, new rows inserted, `idx` renumbered from 1. Zero rows affected → `permission_denied` (42501).
- `app.delete_doc(doctype, id)` (`public.delete_doc` RPC) — security invoker; drafts/masters only (`delete_submitted` otherwise), RLS decides.
- `app.next_name(org_id, company_id, series, posting_date)` (`0007_framework_naming.sql`) — port of Frappe `parse_naming_series`/`getseries`: tokens `YYYY, YY, MM, DD, WW, ABBR, #…`; templates without `#` get `.#####`. **Deviation from the original sketch:** counters live in `naming_series(org_id, prefix, current)` keyed by the *resolved* prefix (e.g. `ACC-SINV-2026-`), exactly like Frappe's `tabSeries`, rather than by `(company_id, series, period_key)`; a new year therefore starts a new counter, and `ABBR` makes counters per company. Locked with `pg_advisory_xact_lock(hashtextextended(org:prefix))`; security definer, not executable by API roles (called only by engine functions). Members read `naming_series`; System Manager may update it ("Update Series Counter").
- Database errors are raised as `code: message` (`P0001`); Server Actions map `code` to a form field through the descriptor's `errorFields`.
- **Document-level validation** (rules that read the header and its child rows together, e.g. Holiday List date range, duplicate dates, re-indexing and totals) runs from `create constraint trigger … deferrable initially deferred` triggers on the header and the child table that call one idempotent `app.<doctype>_refresh(id)` (security definer). `save_doc` writes the header first and the rows after, so a row trigger would see a half-saved document; the deferred check runs once at commit and a raised error rolls back the whole save. pgTAP tests run `set constraints all immediate;` to see the error at the statement. Field-level checks stay in plain `before` triggers.

**Deferred to the first submittable doctype (P3 Journal Entry)**, specified here so the design stays fixed:

- `app.submit_doc(doctype text, id uuid)` → checks perm, locks row `for update`, validates `docstatus=0`, assigns `name` (`app.next_name`), sets `docstatus=1`, then dispatches to the doctype-specific `app.on_submit__<table>(id)` function if it exists, then `app.update_status(doctype,id)`.
- `app.cancel_doc(doctype, id)` → checks perm and linked submitted documents (`app.linked_docs()` using the FK registry), sets `docstatus=2`, dispatches `app.on_cancel__<table>(id)` (which reverses ledgers), updates prev-doc status.
- `app.amend_doc(doctype, id)` → deep-copies the row and child rows into a new draft with `amended_from`, clears no-copy fields (from `doctype_meta.no_copy_fields`).
Doctype registry table `doctype_meta(doctype, table_name, module, is_submittable, is_tree, is_child, parent_doctype, child_field, title_field, naming_series_default, no_copy_fields text[], allow_on_submit text[])` seeded by migration; `defineDoctype()` in TS must match it (a CI script compares them).

## Link integrity & "Connections"

- Real FKs everywhere (`on delete restrict` for links, `cascade` for child rows).
- `app.linked_docs(doctype, id)` reads `information_schema` once (cached in `doctype_links`) to list documents pointing at a record — this powers the form "Connections" panel and the cancel-guard, equivalent to Frappe's `get_linked_docs`.

## Audit

- `updated_at/updated_by` triggers on all tables.
- `doc_version(id, org_id, doctype, record_id, user_id, at, diff jsonb)` written by a generic trigger on master and transactional headers (not ledgers, not child tables) — gives the ERPNext "Version"/timeline.
- `doc_comment(id, org_id, doctype, record_id, user_id, content, at)` for the form timeline.

## Indexing baseline

```sql
(org_id, name)                                   -- lookups
(org_id, company_id, docstatus, posting_date desc)  -- lists
(org_id, <party>_id, docstatus)                  -- party pages
gl_entry:  (org_id, company_id, account_id, posting_date), (org_id, voucher_type, voucher_id), (org_id, party_type, party_id, against_voucher_id)
stock_ledger_entry: (org_id, item_id, warehouse_id, posting_datetime, creation_order), (org_id, voucher_type, voucher_id)
bin: unique (org_id, item_id, warehouse_id)
```

## Migrations workflow

1. `supabase migration new <nnnn>_<module>_<doctype>` (numbering ranges: 0000-0099 framework, 0100 setup, 0200 stock masters, 0300 accounts, 0400 selling, 0500 buying, 0600 stock txns, 0700 manufacturing, 0800 projects, 0900 assets, 1000+ reports/perf).
2. Each migration is idempotent-safe (`create table if not exists`, `drop policy if exists`), ends with RLS enablement and policies, and includes the `doctype_meta` + default `role_permissions` upserts for that doctype.
3. Run locally (`supabase db reset`), run pgTAP, regenerate `src/types/database.ts`, commit both.
4. Applied to the hosted project only by CI (`deploy-db.yml`) or, when working interactively against the **dev** project, by `supabase db push --linked` (keeps the `NNNN` versions in sync with git; preferred over the MCP `apply_migration`, which records timestamp versions) — never DDL against prod. A new framework migration numbered below an already-applied module migration (e.g. `0005` after `0100`) needs `--include-all`.
5. Without Docker, run pgTAP against the linked dev project with `npm run db:test:linked` (`scripts/pgtap-remote.ps1`: each file runs in its own transaction and is rolled back), advisors with `supabase db advisors --linked`, types with `npm run db:types:linked`.

## Scheduled jobs

ERPNext scheduler events become `pg_cron` jobs (enabled in `0114`): an `app.<job>()` function (`security definer`, execute revoked from API roles, loops over every organization and isolates each row in a `begin … exception` block so one bad row does not stop the run) scheduled by name in the migration that creates it, `select cron.schedule('<job-name>', '<cron>', 'select app.<job>()')` (re-running replaces the job). pgTAP calls the function directly as `postgres` and asserts on the test organization's rows only. First job: `auto-create-fiscal-year` (daily 00:15 UTC).

## Seeds

`supabase/seed/*.json` + `supabase/seed.sql` (local demo org). Reference catalogs (countries, currencies, standard CoA template, UOM list, UOM conversions) are loaded into **global** tables once; `app.provision_organization()` copies what each org needs.

**Per-organization presets** (designations, the root department, …) use the seed-trigger pattern: an idempotent `app.seed_<thing>(org uuid)` (`security definer`, `on conflict do nothing`), an `after insert on public.organizations` (or `public.companies`) trigger that calls it, and a `select app.seed_<thing>(o.id) from public.organizations o` backfill at the end of the migration. Execute is revoked from `public, anon, authenticated`.

Reference data ships as a **generated migration**, not `seed.sql` (seeds never reach prod; migrations do, through CI). Vendored source files live in `supabase/seed/reference/` with their upstream commit SHAs in `SOURCES.json`; a Node script with no dependencies (`scripts/gen-reference-data.mjs`) turns them into an idempotent `insert … on conflict do update` migration (`0009_framework_reference_data.sql`). To update: refresh the source file, bump the SHA, regenerate, and add the regenerated SQL as a **new** migration if `0009` is already applied anywhere. Global tables have no `org_id`; RLS is forced with a `select … to authenticated using (true)` policy and writes revoked from API roles.
