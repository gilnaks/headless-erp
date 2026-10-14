# headless-erp — Master Plan

> **This file is the instruction set for every Cursor session on this project.** Read it first, then the architecture doc(s) relevant to the task, then the module doc for the module you are touching. `.cursorrules` and `.cursor/rules/*.mdc` enforce the conventions defined here.

## 1. Mission

Re-implement the **default, out-of-the-box behaviour** of eight ERPNext modules as a **multi-tenant SaaS web app**:

| Module | Scope (mirrors ERPNext's module sidebar, `erpnext/<module>/sidebar/<module>/<module>.json`) |
|---|---|
| Setup | Home, Company, Users, Organization, Access, Printing, Email |
| Accounts | Dashboard, Chart of Accounts, Sales Invoice, Purchase Invoice, Payment Entry, Journal Entry, Reports, Banking, Taxes, Budgeting, Setup |
| Selling | Dashboard, Customer, Quotation, Sales Order, Delivery Note, Reports, Items, Setup |
| Buying | Dashboard, Supplier, Material Request, Request for Quotation, Purchase Order, Purchase Receipt, Purchase Invoice, Reports, Items, Setup |
| Stock | Dashboard, Item, Warehouse, Material Request, Stock Entry, Stock Reconciliation, Purchase Receipt, Delivery Note, Reports, Tools, Serial & Batch, Setup |
| Manufacturing | Dashboard, BOM, Production Plan, Work Order, Job Card, Stock Entry, Reports, Subcontracting, Tools, Setup |
| Projects | Dashboard, Project, Task, Timesheet, Reports, Setup |
| Assets | Dashboard, Asset, Depreciation Schedule, Asset Movement, Fixed Asset Register, Reports, Value Changes, Maintenance, Setup |

**Not in scope** (unless a module doc explicitly pulls it in as a hard dependency): CRM, Support, Quality, POS, Loyalty, Subscriptions, Website/Portal, Regional/e-invoicing, Telephony, HR/Payroll, Pricing Rules/Promotional Schemes, Item Variants, Accounting Dimensions, Multi-currency beyond "company currency + document currency with a fixed rate", Deferred revenue/expense, Period Closing, Repost tools, Data Import/Rename tools.

Source of truth for behaviour: the ERPNext clone at `C:\Users\John\Desktop\erpnext` (branch `develop`, v16 line) and the docs at https://docs.frappe.io/erpnext/introduction. When ERPNext's current behaviour and the docs disagree, follow the code.

## 2. Stack (fixed — do not substitute)

| Concern | Choice | Notes |
|---|---|---|
| Framework | **Next.js 16.4+** (App Router, React 19, TypeScript strict, Turbopack) | `cacheComponents: true`, `partialPrefetching: true`. `proxy.ts` (not `middleware.ts`). `params`/`searchParams`/`cookies()`/`headers()` are async. |
| Database / Auth / Storage | **Supabase** (Postgres 15+, Supabase Auth, Storage, Edge Functions only when a Server Action cannot do the job) | Schema lives in `supabase/migrations/*.sql`, versioned in git. Types generated with `supabase gen types`. The Supabase MCP server is used from Cursor for migrations, SQL, advisors and type generation. |
| Auth in Next.js | `@supabase/ssr` | Browser client + server client. Token refresh in `proxy.ts` with `supabase.auth.getClaims()`. Never `getSession()` for authorization on the server. Never `@supabase/auth-helpers-nextjs`. |
| Client state | **Zustand** | UI/session state only (active company, sidebar, list filters, unsaved form drafts, toasts). Server data is fetched in Server Components / Server Actions; never duplicate it into a global store. |
| UI kit | **Untitled UI React** (Tailwind CSS v4, React Aria Components, `@untitledui/icons`) | Components are copied into `src/components/base/**` and `src/components/application/**` via `npx untitledui@latest add <component>`. We own the code. |
| Charts | **Recharts 3** | `responsive` prop on chart roots; wrap in a client component. |
| Validation | **Zod** | One schema per doctype, shared by client forms and Server Actions. |
| Forms | React Hook Form + Zod resolver | Thin wrapper components over Untitled UI inputs. |
| Tables | TanStack Table (headless) rendered with Untitled UI table primitives | Server-side pagination/sort/filter via Server Components + URL state (`nuqs`). |
| Testing | Vitest (unit, posting engine via pg-tap style SQL tests through Supabase CLI), Playwright (critical flows) | Posting engine correctness is tested in SQL against a local Supabase. `@playwright/test` (dev dependency, Chromium only) runs `e2e/*.spec.ts` against the built app in CI. |
| Lint/format | Biome | Untitled UI-owned folders (`components/{base,application,foundations,shared-assets}`, `hooks`, `providers`, `styles`, `utils`) are excluded so upstream diffs stay clean. |
| Package manager | npm (Node 22) | `package-lock.json` committed. |
| CI/CD | GitHub Actions → Netlify (Next.js adapter) + Supabase CLI | See `docs/architecture/06-deployment-ops.md`. |
| Public holidays | `date-holidays` (MIT) | Server-only (Holiday List "Add Local Holidays" Server Action). Replaces ERPNext's Python `holidays` package; added P1. |

## 3. Architecture in one page

```
Browser (Client Components, Zustand UI state)
   │  forms, filters, optimistic UI, live totals preview (pure TS calc = same lib as server)
   ▼
Next.js 16 on Netlify
   ├─ Server Components: read via Supabase server client (RLS enforced, user JWT)
   ├─ Server Actions: validate (Zod) → call Postgres RPC (app.* functions) → revalidateTag
   └─ proxy.ts: session refresh + tenant cookie (active org/company) + route guards
   ▼
Supabase Postgres
   ├─ schema `public`: tenant data tables (every row has org_id; RLS on every table)
   ├─ schema `app`: posting engine (submit/cancel), numbering, permission helpers, report functions
   ├─ schema `auth`: Supabase Auth
   └─ views/materialized views for reports and dashboards
```

**Guiding rule:** anything that changes ledgers, balances, statuses of linked documents or document numbers runs **inside one Postgres transaction** (an `app.*` function). The browser only computes previews.

Full detail: `docs/architecture/01-tenancy-auth-rls.md`, `02-database-conventions.md`, `03-posting-engine.md`, `04-client-vs-server.md`, `05-ui-ux.md`, `06-deployment-ops.md`.

## 4. The ERPNext concepts we replicate (and how)

| ERPNext / Frappe concept | headless-erp equivalent |
|---|---|
| Site (one DB per customer) | **Organization** (`organizations` row) + `org_id` column + RLS. One Supabase project serves all tenants. |
| Company (several per site) | `companies` table scoped to org. Every transactional table carries `company_id`. |
| DocType | A Postgres table (+ child tables) **and** a TypeScript `defineDoctype()` descriptor in `src/doctypes/<module>/<slug>.ts` that drives list/form UI, Zod schema, permissions and link mapping. |
| `name` (human key, e.g. `ACC-SINV-2026-00001`) | `name text` column, unique per `(org_id, name)`; generated by `app.next_name(org_id, company_id, series)` at **submit** for submittable docs and at insert for masters. Rows also have a `uuid` primary key `id`. |
| `docstatus` 0/1/2 | `docstatus smallint` with identical semantics (Draft / Submitted / Cancelled). Submitted rows are immutable except whitelisted "allow on submit" fields. |
| Amend | `amended_from uuid` + name suffix `-1`, `-2`. |
| Child table (`parent`, `parentfield`, `idx`) | `<parent>_item` style tables with `parent_id uuid`, `idx int`. Cascade delete only while draft. |
| Link / Dynamic Link | `uuid` FK; dynamic links use `(voucher_type text, voucher_id uuid)` pairs. |
| Tree doctypes (Account, Cost Center, Warehouse, Item Group, Customer Group, Supplier Group, Territory, Department, Company) | `parent_id` adjacency + `is_group`, with `path ltree` maintained by trigger for fast subtree queries. |
| Single doctypes (settings) | One row per org (or per company where ERPNext has company-specific defaults) in `<module>_settings` tables; seeded with ERPNext defaults. |
| Naming Series | `naming_series` table (org, company, series prefix, current). Default prefixes copied from ERPNext (`ACC-SINV-.YYYY.-`, `SAL-ORD-.YYYY.-`, `MAT-STE-.YYYY.-`, ...). |
| Roles & Role Permissions | `roles`, `role_permissions(doctype, read/write/create/submit/cancel/amend/delete)`, `org_members(user, org, roles[])`. Evaluated by `app.has_perm()` in RLS **and** in Server Actions. Default roles: System Manager, Accounts Manager/User, Sales Manager/User, Purchase Manager/User, Stock Manager/User, Item Manager, Manufacturing Manager/User, Projects Manager/User, Auditor. |
| User Permissions (restrict a user to a Company / Warehouse / Cost Center) | `user_permissions(user, org, doctype, record_id)` honoured by `app.allowed_records()` in RLS. |
| GL Entry / Stock Ledger Entry / Payment Ledger Entry / Bin | Same four tables, same columns that matter (see posting engine doc). Append-only; cancellation inserts reversing rows with `is_cancelled`. |
| Status Updater (per_delivered, per_billed, per_received, per_ordered → status) | Implemented in `app.update_prevdoc_status()` executed inside submit/cancel. Status expressions copied from `erpnext/controllers/status_updater.py`. |
| `make_*` mappers (Quotation → Sales Order → Delivery Note → Sales Invoice, etc.) | `app.map_doc(source_doctype, source_id, target_doctype)` SQL functions + TS `mapDoc()` for pre-fill; mapping tables documented per module. |
| Taxes and Totals (`controllers/taxes_and_totals.py`) | One pure TypeScript library `src/lib/calc/taxes-and-totals.ts` used both in the browser (live preview) **and** re-executed server-side (authoritative) before posting. Property-tested against ERPNext examples. |
| Workspace / Sidebar | Module sidebar JSON → our route tree in `src/app/(app)/[module]/...` and nav config in `src/config/navigation.ts`. |
| Dashboard (Number Cards + Dashboard Charts) | Same cards/charts as `erpnext/<module>/<module>_dashboard/*.json`, computed by SQL functions, rendered with Recharts. |
| Print Format / Letter Head | Server-rendered print routes (`/print/[doctype]/[id]`) with a default modern template per transaction + Letter Head selection. PDF via browser print. |
| Email Account / Email Template | Transactional outbound mail via Supabase Edge Function + Resend (or SMTP) using templates stored per org. No inbound mail. |

## 5. Default settings baseline ("what the setup wizard gives you")

When an organization completes onboarding we recreate what `erpnext/setup/setup_wizard/operations/install_fixtures.py` and `Company.on_update` produce:

- Fiscal Year (from onboarding dates), Company (abbr, currency, country, `enable_perpetual_inventory = 1`, `valuation_method = FIFO`), **Standard chart of accounts** (`standard_chart_of_accounts.py`, with `account_type`/`account_category`), default accounts wired on Company (receivable Debtors, payable Creditors, Cash, Bank, Stock In Hand, Stock Received But Not Billed, Stock Adjustment, COGS, Sales income, Round Off, Write Off, Exchange Gain/Loss, Depreciation, Accumulated Depreciation, CWIP, Asset Received But Not Billed, Gain/Loss on Asset Disposal).
- Cost Centers: `<Company>` (group) → `Main`.
- Warehouses: `All Warehouses` (group) → `Stores` (default), `Work In Progress`, `Finished Goods`, `Goods In Transit` (type Transit).
- Departments: All Departments → Accounts, Marketing, Sales, Purchase, Operations, Production, Dispatch, Customer Service, Human Resources, Management, Quality Management, Research & Development, Legal.
- Item Groups: All Item Groups → Products, Raw Material, Services, Sub Assemblies, Consumable.
- Stock Entry Types: Material Issue, Material Receipt, Material Transfer, Manufacture, Repack, Material Transfer for Manufacture, Material Consumption for Manufacture, Send to Subcontractor, (others only if subcontracting scope needs them).
- Territories: All Territories → `<Country>`, Rest Of The World. Customer Groups: All → Individual, Commercial, Non Profit, Government. Supplier Groups: All → Services, Local, Raw Material, Electrical, Hardware, Pharmaceutical, Distributor. Sales Person: Sales Team (group).
- Modes of Payment: Cash (Cash), Cheque/Check (Bank), Credit Card (Bank), Wire Transfer (Bank), Bank Draft (Bank); Cash mode linked to company's default cash account.
- Price Lists: Standard Buying, Standard Selling (company currency).
- UOMs + conversion factors from `uom_data.json` / `uom_conversion_data.json` (seed a curated subset: Nos/Unit, Box, Kg, Gram, Litre, Meter, Hour, Day, Set, Pair, Dozen…; full list optional).
- Activity Types: Planning, Research, Proposal Writing, Execution, Communication. Project Types: Internal, External, Other.
- Party Types: Customer (Receivable), Supplier (Payable). Warehouse Type: Transit.
- Settings defaults: Selling (`cust_master_name=Customer Name`, `so_required=No`, `dn_required=No`, `allow_multiple_items=1`, `sales_update_frequency=Each Transaction`), Buying (`supp_master_name=Supplier Name`, `po_required=No`, `pr_required=No`, `maintain_same_rate=1`, `allow_multiple_items=1`), Stock (`item_naming_by=Item Code`, `valuation_method=FIFO`, `stock_uom=Nos`, `auto_indent=1`, `auto_insert_price_list_rate_if_missing=1`, `allow_negative_stock=0`), Accounts (`unlink_payment_on_cancellation_of_invoice=1`, `book_asset_depreciation_entry_automatically=1`, `add_taxes_from_item_tax_template=1`, `default_ageing_range=30,60,90,120`, `over_billing_allowance=0`), Manufacturing (`backflush_raw_materials_based_on=BOM`, `capacity_planning_for_days=30`, `disable_capacity_planning=0` → we **do** disable capacity planning by default to stay "basic"), Projects (all overlap checks off).
- Default Role Profiles: Inventory, Manufacturing, Accounts, Sales, Purchase (see `erpnext/setup/install.py: DEFAULT_ROLE_PROFILES`).

The precise seed is specified in `docs/modules/00-setup.md` and implemented in `supabase/seed/` + `app.provision_organization()`.

## 6. Repository layout

```
headless-erp/
├─ .cursorrules                      # always-on rules (short)
├─ .cursor/rules/*.mdc               # scoped rules (supabase, nextjs, ui, zustand, posting engine, docs)
├─ .cursor/mcp.json                  # Supabase MCP (project-scoped, see 06-deployment-ops)
├─ docs/
│  ├─ PLAN.md                        # this file
│  ├─ erpnext-reference.md           # how to read the ERPNext repo
│  ├─ architecture/01..06-*.md
│  └─ modules/00-setup.md … 07-assets.md
├─ supabase/
│  ├─ config.toml
│  ├─ migrations/                    # 0001_extensions.sql, 0002_tenancy.sql, 0010_setup_*.sql, 0100_accounts_*.sql ...
│  ├─ functions/                     # Edge Functions (email, scheduled jobs)
│  ├─ seed/                          # reference data (CoA template JSON, UOMs, country list, currencies)
│  └─ tests/                         # pgTAP tests for posting engine
├─ src/
│  ├─ app/
│  │  ├─ (auth)/login, signup, invite/[token]
│  │  ├─ (onboarding)/setup           # org + company wizard
│  │  ├─ (app)/[org]/…                # authenticated shell; org slug in URL
│  │  │   ├─ setup/…  accounts/…  selling/…  buying/…  stock/…  manufacturing/…  projects/…  assets/…
│  │  │   └─ print/[doctype]/[id]
│  │  └─ api/… (webhooks only)
│  ├─ components/base/**             # Untitled UI primitives (owned copies)
│  ├─ components/application/**      # Untitled UI app components (tables, nav, modals)
│  ├─ components/erp/**              # our composites: DocForm, DocList, ChildTable, LinkField, StatusBadge, DocActions, NumberCard, DashboardChart
│  ├─ doctypes/<module>/<slug>.ts    # defineDoctype() descriptors (fields, children, perms, status map, links)
│  ├─ lib/
│  │  ├─ supabase/{client,server,proxy}.ts
│  │  ├─ calc/                       # pure TS: taxes-and-totals, rounding, currency, uom
│  │  ├─ actions/<module>/*.ts       # Server Actions (thin: zod → rpc → revalidate)
│  │  ├─ queries/<module>/*.ts       # typed read helpers for Server Components
│  │  └─ auth/{claims,permissions}.ts
│  ├─ stores/                        # Zustand: ui.ts, session.ts, list-filters.ts, form-draft.ts
│  ├─ config/navigation.ts           # module sidebar definitions (mirrors ERPNext sidebars)
│  └─ types/database.ts              # generated by supabase gen types
├─ netlify.toml
├─ e2e/                              # Playwright smoke specs (CI, local Supabase)
└─ .github/workflows/{ci.yml, deploy-db.yml, backup.yml}
```

## 7. Delivery phases (each phase = mergeable, deployable increment)

Work **one phase at a time**, and within a phase **one doctype at a time**: migration → RLS → seed → TS descriptor → Server Actions → list/form UI → tests → docs updated.

| Phase | Deliverable | Depends on |
|---|---|---|
| **P0 Foundation** | Scaffold (`npx untitledui@latest init --nextjs` then merge into this repo), Biome, Supabase local, auth (email+password, magic link, invites), `organizations`/`companies`/`org_members`/roles/RLS helpers, app shell (icon rail + module sidebar + command palette), `defineDoctype()` + generic `DocList`/`DocForm`/`ChildTable`/`LinkField`, numbering, audit columns, `app.has_perm`, CI, Netlify preview deploys. | — |
| **P1 Setup** | Onboarding wizard (org → company → fiscal year → CoA → defaults), Company, Users & invites, Organization (Branch, Department, Designation, Holiday List), Access (Roles, Role Permissions matrix, User Permissions), Printing (Letter Head, Print Settings, default print formats), Email (Email Account/outbound config, Email Templates). Provisioning seed from §5. | P0 |
| **P2 Masters** | Item, Item Group, UOM, Brand, Warehouse, Customer, Customer Group, Territory, Supplier, Supplier Group, Address, Contact, Price List + Item Price, Payment Terms, Terms & Conditions, Tax templates (Sales/Purchase/Item Tax Template, Tax Category, Tax Rule), Account (CoA tree UI), Cost Center, Fiscal Year, Mode of Payment, Currency Exchange. | P1 |
| **P3 Accounting core** | GL posting engine, Journal Entry, Payment Entry (receive/pay/internal transfer, allocation against invoices), Payment Ledger, General Ledger / Trial Balance / Balance Sheet / P&L reports, Accounts Dashboard. | P2 |
| **P4 Stock core** | Stock Ledger engine (FIFO + Moving Average, perpetual inventory GL), Bin, Stock Entry (all standard purposes), Stock Reconciliation (opening stock), Material Request, Stock Ledger / Stock Balance / Projected Qty / Ageing reports, Stock Dashboard, Serial No / Batch (basic: item flags, bundle on inward/outward, reports). | P3 |
| **P5 Selling** | Quotation → Sales Order → Delivery Note → Sales Invoice (with `update_stock` option), returns (credit note / sales return), status updater, Selling reports + dashboard, Selling Settings. | P4 |
| **P6 Buying** | Material Request → RFQ → Supplier Quotation → Purchase Order → Purchase Receipt → Purchase Invoice, returns (debit note / purchase return), Stock Received But Not Billed flow, Buying reports + dashboard, Buying Settings, Supplier Scorecard (read-only basic). | P5 |
| **P7 Accounts extended** | Banking (Bank, Bank Account, Bank Transaction import CSV, Bank Reconciliation, Bank Clearance), Budgeting (Budget, Monthly Distribution, Budget Variance, cost-center budget validation on GL), Tax Withholding Category (basic), Accounts Setup pages, AR/AP ageing reports. | P6 |
| **P8 Manufacturing** | Workstation, Operation, Routing, BOM (tree, cost rollup), Production Plan (from SO/MR → WO/MR), Work Order (material transfer + manufacture stock entries, backflush by BOM), Job Card (basic time logs), Subcontracting (SC Order/Receipt only, simplest flow), BOM Update Tool, reports + dashboard. | P6 |
| **P9 Projects** | Project Type, Project Template, Project (tasks, % complete, costing from timesheets & purchase), Task (tree, dependencies, Gantt-lite), Timesheet (billable → Sales Invoice), Activity Type/Cost, reports + dashboard. | P5 |
| **P10 Assets** | Asset Category, Location, Asset (purchase via PR/PI with `is_fixed_asset`, CWIP, finance books = single default), Depreciation Schedule (Straight Line, WDV, Double Declining), automatic depreciation JE job, Asset Movement, Asset Value Adjustment, Asset Capitalization (basic), Maintenance (team, schedule, log, repair), Fixed Asset Register + reports + dashboard. | P7 |
| **P11 Hardening** | Security review (RLS tests per table, permission matrix tests), performance (indexes, `use cache` for reference data, report materialization), backups verified, docs, demo data generator. | all |

## 8. Definition of Done for a doctype

1. Migration with table(s), FKs, indexes (`(org_id, name)`, `(org_id, company_id, docstatus, posting_date)`), RLS enabled + policies, `updated_at` trigger.
2. Settings/defaults seeded for new orgs when ERPNext seeds them.
3. `src/doctypes/<module>/<slug>.ts` descriptor with Zod schema; `supabase gen types` regenerated.
4. Server Actions for save/submit/cancel/amend/delete/map; posting handled in `app.*` SQL with tests.
5. List view (filters, sort, pagination, bulk actions where ERPNext has them) and Form view (tabs mirroring ERPNext's tab breaks, child tables, link fields with quick-create, status badge, connections panel).
6. Dashboard/report queries if the module sidebar lists them.
7. Permission checks: default role matrix copied from the doctype JSON `permissions` array.
8. Module doc updated (`docs/modules/*.md`) if behaviour deviates from ERPNext.

## 9. How to use the ERPNext repo while implementing

See `docs/erpnext-reference.md`. Short version: the doctype JSON (`erpnext/<module>/doctype/<slug>/<slug>.json`) is the schema; the `.py` beside it is the behaviour (`validate`, `on_submit`, `on_cancel`, `make_gl_entries`, `make_*` mappers); `controllers/*.py` hold shared behaviour; `status_updater.py` holds status rules; `setup_wizard/` holds defaults.

## 10. Non-negotiables

- Every tenant table has `org_id` **and** RLS. No exceptions, including lookup tables (seed them per org, or mark them `is_global` with read-only policies).
- Ledgers are append-only. Cancellation reverses; it never deletes.
- Financial math uses `numeric` in Postgres and `decimal.js`-free integer-safe helpers in TS (`src/lib/calc/number.ts`, precision from company currency + "float precision" setting, default 2/3/6 like ERPNext).
- Server Actions re-validate everything; client previews are never trusted.
- Modern, minimal UI: Untitled UI tokens, no custom colours outside `theme.css`, dense data tables, keyboard-first forms, consistent empty/loading/error states.
- Commit small. One doctype or one engine function per PR.
