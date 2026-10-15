# 04 — Browser vs Postgres vs Edge Functions

The app is a Vite SPA. There is no Next.js server. Three places run code:

## Decision rules

| Put it **in Postgres** (`app.*` functions, views, triggers) when… | Put it in an **Edge Function** when… | Put it in the **browser** when… |
|---|---|---|
| It mutates ledgers, balances, stock, document numbers, statuses of other documents, or stored HTML | It needs a secret (service role, email provider, webhook signing key) | It only affects what the current user sees before saving |
| It must be atomic across several tables | It calls a third party the browser must not see | It is a live preview of totals/taxes/rates while typing (same pure lib Postgres will recompute) |
| It aggregates large data (reports, dashboards, ageing, stock balance) | | It is UI state: filters, column visibility, open panels, drafts, active company, keyboard nav |
| It must be correct even if someone calls `rpc` directly | | It is optimistic UI that the server response will confirm |
| It authorizes a write (RLS, `app.has_perm`) | | It hides a button the user could reveal; RLS still blocks the write |

Never: trust client-computed amounts; ship the service role or a provider key in the client bundle; keep query results in Zustand.

Zod parses forms so the user sees field errors. The same rule, if it must hold, is enforced again in SQL.

## Per-area assignment

| Feature | Postgres | Edge Function | Browser |
|---|---|---|---|
| Submit / cancel / amend | `app.submit_doc` etc. (all posting) | — | `submitDoc` calls `rpc`, then invalidates `['org', orgId, doctype]`; button, confirm dialog, toast |
| Save draft | `app.save_doc` (RLS). HTML columns pass through `app.sanitize_html` | — | Zod, then `rpc`; React Hook Form, dirty tracking, unsaved-changes guard |
| Taxes & totals | `app.calc_taxes_and_totals()` inside `save_doc` / `submit_doc` | — | `calcTaxesAndTotals()` on every change, preview only |
| Item details on row add | `app.get_item_details(args)` | — | debounced `useQuery`, 60s `staleTime` |
| Link field search | `public.search_link(org_id, doctype, q, ids)` security invoker | — | debounced `useQuery`, abort, keep previous data, 60s `staleTime` |
| List views | SQL with `order by`, `limit/offset`, filters, `count(*) over()` | — | `useQuery` keyed by the `nuqs` URL state; column chooser and row selection in the client |
| Dashboards | `app.card_*`, `app.chart_*`; materialized views for heavy ones | — | Recharts; query `staleTime` 60s, `gcTime` 5 min, keyed by org, company, fiscal year, range |
| Reports | One SQL function per report | — | filters in the URL; CSV built in the browser from the returned page |
| Tree views | `ltree` subtree queries | — | load nodes with `useQuery`; expand/collapse in Zustand |
| Permissions | RLS + `app.has_perm` | — | `can()` from the JWT hides buttons |
| Numbering | `app.next_name` on submit | — | shows "New …" until submitted |
| Print | — | — | `/print/[doctype]/[id]` route, `window.print()` |
| Email send | templates and `email_log` | `send-email` (provider key) | compose dialog calls the function |
| Scheduled statuses | `pg_cron` → SQL | — | — |
| Onboarding | `app.provision_organization(jsonb)` security definer | — | wizard calls `rpc` as the signed-in user, then `refreshSession()` |
| File uploads | Storage RLS by org prefix | — | browser uploads with the user JWT; signed URL from a security-invoker RPC |
| Public holidays | — | — | `date-holidays` in the Holiday List action |

## Caching (TanStack Query)

- Reference data (company settings, currencies, UOMs, role matrix): `staleTime` of several minutes. Query key includes `orgId`.
- Transactional lists and forms: `staleTime: 0` (refetch on focus) but show the cached page immediately (`placeholderData`).
- After a mutation, `queryClient.invalidateQueries({ queryKey: ['org', orgId, doctype] })`.
- Dashboards: `staleTime: 60_000`, keyed by `(orgId, companyId, fiscalYearId, range)`.
- Do not put the JWT in a query key. The Supabase client sends it. Include `orgId` (and `userId` when the row set is per user).

## Zustand stores

| Store | State | Persist |
|---|---|---|
| `session.ts` | `orgId, orgSlug, companyId, fiscalYearId, userRoles[]` | `companyId` in `localStorage` (per org). Not a cookie. |
| `ui.ts` | sidebar collapsed, theme, command palette open, density | localStorage |
| `list-filters.ts` | per-doctype saved filters, column visibility, page size | localStorage (per org) |
| `form-draft.ts` | unsaved draft payload per `(doctype, id|'new')`, dirty flag, last autosave time | sessionStorage |
| `recent.ts` | recently opened documents for the command palette and link fields | localStorage |

Rules: stores are created with `create<State>()(devtools(persist(...)))`, selectors only (`useSessionStore(s => s.companyId)`), no async fetching inside stores, no server data.
