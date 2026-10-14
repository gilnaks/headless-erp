# 04 — Client-side vs Server-side (Supabase) Computation

## Decision rules

| Put it **in Postgres** (`app.*` functions, views, triggers) when… | Put it in **Next.js server** (RSC / Server Actions / `use cache`) when… | Put it in the **browser** (Client Components + Zustand) when… |
|---|---|---|
| It mutates ledgers, balances, stock, document numbers, statuses of other documents | It orchestrates: validate input (Zod), check permission, call one RPC, revalidate caches, redirect | It only affects what the current user sees before saving |
| It must be atomic across several tables | It renders data for a page (lists, forms, dashboards) with the user's JWT | It is a live preview of totals/taxes/rates while typing (same pure lib as server) |
| It aggregates large data (reports, dashboards, ageing, stock balance) | It composes reference data cached across requests (`'use cache'` + `cacheTag('org:<id>:items')`) | It is UI state: filters, column visibility, open panels, drafts, active company, keyboard nav |
| It must be correct regardless of client (API, import, future mobile app) | It needs secrets (service role, email provider, webhooks) | It is optimistic UI that will be confirmed by the server response |

Never: trust client-computed amounts; call Supabase with the service role from anything but server-only modules; keep server data in Zustand.

## Per-area assignment

| Feature | Postgres | Next.js server | Browser |
|---|---|---|---|
| Submit / cancel / amend | `app.submit_doc` etc. (all posting) | Server Action `submitDoc(doctype, id)` → RPC → `updateTag` | button state, confirm dialog, toast |
| Save draft | RLS-checked `insert/update` via PostgREST (header + children in one RPC `app.save_doc(doctype, payload jsonb)` to keep atomicity) | Server Action validates with Zod, maps form → payload | React Hook Form state, dirty tracking, unsaved-changes guard (Zustand `form-draft`) |
| Taxes & totals | `app.calc_taxes_and_totals()` re-check inside `save_doc`/`submit_doc` | — | `calcTaxesAndTotals()` runs on every change for the preview |
| Item details on row add (price from price list, UOM conversion, income/expense account, warehouse, tax template, stock qty) | `app.get_item_details(args)` (port of `stock/get_item_details.py`, default paths only) | Server Action wrapper, cached per `(org, item, price_list, customer/supplier, company)` for 60s | debounced call; row filled client-side |
| Link field search | `app.search_link(doctype, txt, filters)` (ilike on name/title fields + `search_fields`) | Route Handler `/api/link-search` with `use cache` 30s for masters | combobox, recent items (Zustand) |
| List views | SQL with `order by`, `limit/offset`, filters → `count(*) over()` | Server Component reads URL state (`nuqs`) → query; streams with Suspense | column chooser, saved filters, row selection, bulk actions trigger Server Actions |
| Dashboards (number cards, charts) | SQL functions per card/chart (`app.card_*`, `app.chart_*`) + hourly materialized views for heavy ones | `'use cache'` 5 min per org, revalidated on submit of relevant doctypes | Recharts render, range picker, drill-down navigation |
| Reports (GL, Trial Balance, BS, P&L, Stock Ledger, Stock Balance, AR/AP ageing, etc.) | One SQL function per report returning rows; tree reports return `(id, parent_id, indent)` | Server Component with filters in URL; CSV export via Route Handler streaming | client-side column sort/group of the returned page, print view |
| Tree views (CoA, Cost Centers, Warehouses, Item Groups, BOM tree) | `ltree` subtree queries, balances per node via one aggregate query | RSC renders expanded nodes; lazy-load children via Server Action | expand/collapse state in Zustand |
| Permissions | authoritative (RLS + `app.has_perm` in functions) | `can(action, doctype)` helper from claims for hiding UI | hide/disable buttons |
| Numbering | `app.next_name` on submit | — | shows "New Sales Invoice" until submitted |
| Print | — | `/print/[doctype]/[id]` Server Component, letter head applied | `window.print()` |
| Email send | — | Edge Function / Server Action with provider key | compose dialog |
| Scheduled statuses (Overdue, Expired, depreciation) | `pg_cron` → SQL | — | — |
| Onboarding provisioning | `app.provision_organization(jsonb)` | Server Action (service role) | wizard steps in Zustand |
| File uploads (item images, attachments) | Storage RLS by org prefix | signed upload URL via Server Action | drag & drop |

## Caching in Next.js 16 (Cache Components)

- Reference data that rarely changes (company settings, CoA list, UOMs, item groups, naming series options, role matrix): wrap reads in `'use cache'` functions with `cacheTag('org:<org_id>:<doctype>')` and `cacheLife('minutes')`; invalidate with `updateTag()` in the Server Action that changes them.
- Transactional lists and forms: **not cached** (request-time render). Use `<Suspense>` boundaries so the shell streams instantly.
- Never put the user's JWT-derived data into a cached function's closure without including org/user in the cache key (cache key = function args).
- Dashboards: `'use cache'` with `cacheLife({ stale: 60, revalidate: 300, expire: 3600 })` keyed by `(orgId, companyId, fiscalYearId, range)`.

## Zustand stores

| Store | State | Persist |
|---|---|---|
| `session.ts` | `orgId, orgSlug, companyId, fiscalYearId, userRoles[]` (hydrated from server layout props) | cookie-mirrored `companyId` only |
| `ui.ts` | sidebar collapsed, theme, command palette open, density | localStorage |
| `list-filters.ts` | per-doctype saved filters, column visibility, page size | localStorage (per org) |
| `form-draft.ts` | unsaved draft payload per `(doctype, id|'new')`, dirty flag, last autosave time | sessionStorage |
| `recent.ts` | recently opened documents for the command palette and link fields | localStorage |

Rules: stores are created with `create<State>()(devtools(persist(...)))`, selectors only (`useSessionStore(s => s.companyId)`), no async fetching inside stores, no server data.
