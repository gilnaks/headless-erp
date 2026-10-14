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

Tree doctypes add `parent_id uuid`, `is_group boolean`, `lft/rgt` are **not** used; instead `path ltree` maintained by trigger `app.tree_maintain_path()`; subtree query: `where path <@ (select path from account where id = $1)`.

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

Generic SQL entry points (`supabase/migrations/0003_doc_framework.sql`):

- `app.submit_doc(doctype text, id uuid)` → checks perm, locks row `for update`, validates `docstatus=0`, assigns `name` (`app.next_name`), sets `docstatus=1`, then dispatches to the doctype-specific `app.on_submit__<table>(id)` function if it exists, then `app.update_status(doctype,id)`.
- `app.cancel_doc(doctype, id)` → checks perm and linked submitted documents (`app.linked_docs()` using the FK registry), sets `docstatus=2`, dispatches `app.on_cancel__<table>(id)` (which reverses ledgers), updates prev-doc status.
- `app.amend_doc(doctype, id)` → deep-copies the row and child rows into a new draft with `amended_from`, clears no-copy fields (from `doctype_meta.no_copy_fields`).
- `app.next_name(org_id, company_id, series, posting_date)` → parses `.YYYY.`, `.MM.`, `.####` tokens, increments `naming_series.current` under `pg_advisory_xact_lock(hashtext(org||series||year))`.

Doctype registry table `doctype_meta(doctype, table_name, module, is_submittable, is_tree, is_child, parent_doctype, title_field, naming_series_default, no_copy_fields text[], allow_on_submit text[])` seeded by migration; `defineDoctype()` in TS must match it (a CI script compares them).

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
4. Applied to the hosted project only by CI (`deploy-db.yml`) or by the Supabase MCP `apply_migration` when working interactively against the **dev** project — never `execute_sql` DDL against prod.

## Seeds

`supabase/seed/*.json` + `supabase/seed.sql` (local demo org). Reference catalogs (countries, currencies, standard CoA template, UOM list, UOM conversions) are loaded into **global** tables once; `app.provision_organization()` copies what each org needs.
