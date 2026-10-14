# 05 — UI / UX System

Design goal: ERPNext's information architecture (module → sidebar sections → list → form with tabs → connections) rebuilt as a modern, minimal, keyboard-friendly SaaS UI. No ERPNext styling is copied; only the *flow* is preserved so ERPNext users feel at home.

## Foundation

- **Untitled UI React** scaffolded with `npx untitledui@latest init --nextjs` (brand colour: `neutral`/`zinc` base with a single accent — pick `blue` unless the user decides otherwise; change later in `styles/theme.css`). Components are added with `npx untitledui@latest add <name>` into `src/components/base/**` and `src/components/application/**`; we edit them freely but keep file names so upstream updates can be diffed.
- Tailwind CSS v4 (`@import "tailwindcss"; @import "./theme.css"; @plugin "tailwindcss-react-aria-components"; @plugin "tailwindcss-animate"`). No `tailwind.config.js`. Only tokens from `theme.css`; no raw hex in components.
- Icons: `@untitledui/icons` (line icons, 20px in nav, 16px in tables).
- Typography: Inter (next/font), tabular numerals on all numeric cells (`font-variant-numeric: tabular-nums`).
- Density: compact by default (tables 36px rows, forms 32px inputs) with a "comfortable" toggle (Zustand `ui.density`).
- Dark mode supported through Untitled UI tokens; default follows system.
- Accessibility: React Aria primitives, visible focus rings, every icon button labelled, forms navigable with Tab/Enter/Esc, lists with ↑/↓ + Enter.

## App shell

```
┌─────────┬──────────────────────────┬──────────────────────────────────────────┐
│ Icon    │ Module sidebar           │ Page                                     │
│ rail    │ (sections = ERPNext      │ Breadcrumb · Title · Primary actions     │
│ (8      │ sidebar JSON)            │ ─────────────────────────────────────── │
│ modules │  Dashboard               │ List / Form / Report / Dashboard         │
│ + org   │  Chart of Accounts       │                                          │
│ switch) │  Sales Invoice           │                                          │
│         │  ▸ Reports               │                                          │
│         │  ▸ Banking …             │                                          │
└─────────┴──────────────────────────┴──────────────────────────────────────────┘
Top bar: company switcher · global search / command palette (⌘K) · notifications · user menu
```

- `src/config/navigation.ts` is a typed transcription of each `erpnext/<module>/sidebar/<module>/<module>.json` restricted to the in-scope tabs (icons mapped to Untitled UI icons). Hidden if user lacks `read` on every target.
- Routes: `/[org]/<module>` (module home = dashboard), `/[org]/<module>/<doctype-slug>` (list), `/[org]/<module>/<doctype-slug>/new`, `/[org]/<module>/<doctype-slug>/[id]`, `/[org]/<module>/reports/<report-slug>`, `/[org]/<module>/settings`.
- Mobile: rail collapses into a bottom sheet; forms are single-column; tables become cards for the first three columns.

## Page patterns (one implementation each, in `src/components/erp/`)

### `DocList`
Toolbar (search, filter chips with ERPNext-like filter builder, sort, column picker, saved views, "+ New"), TanStack table with sticky header, status badge column, row click → form, checkbox bulk actions (Submit, Cancel, Delete, Export, Assign) when permitted, infinite paging ("Load more", 20/50/100). Sidebar stats like ERPNext's list sidebar: counts by status (SQL `app.list_counts`).

### `DocForm`
- Header: title/name, status badge, "Not Saved"/"Saved" indicator, primary action button that follows docstatus (Save → Submit → Cancel/Amend) plus overflow menu (Duplicate, Print, Email, Links, Delete, Jump to…).
- Tabs replicate the doctype's `Tab Break` fields (e.g. Sales Invoice: Details, Payments, Address & Contact, Terms, More Info, Connections). Sections and column breaks become a responsive 2-column grid.
- Fields come from the `defineDoctype()` descriptor → `FieldRenderer` (Data, Text, Select, Link, Dynamic Link, Date, Time, Datetime, Currency, Float, Int, Percent, Check, Table, Attach, Image, Color, Rating → Untitled UI inputs). Read-only after submit except `allow_on_submit` fields.
- `ChildTable`: inline-editable grid with keyboard row navigation, row drawer for the "full row" view (like ERPNext's row editor), add/duplicate/delete rows, drag reorder (`idx`), totals footer. Row add triggers `getItemDetails`.
- Right rail (xl+): Connections (linked documents grouped like ERPNext's dashboard section, with counts and "+ Create" → `mapDoc`), timeline (versions + comments), assignments/tags.
- "Create ▸" menu on submitted docs mirrors ERPNext's `make_*` options (e.g. Sales Order → Delivery Note, Sales Invoice, Material Request, Purchase Order, Payment Entry, Work Order…).
- Unsaved-changes guard, autosave of drafts to `form-draft` store every 10s, restore prompt.

### `TreeView` (CoA, Cost Centers, Warehouses, Item Groups, Customer/Supplier Groups, Territories, Departments, Tasks, BOM explode)
Expandable rows with balances/totals, inline add child, drag to re-parent (groups only), group vs ledger badges.

### `ReportView`
Filters bar (from report descriptor), results table with grouping/indent for tree reports, totals row, export CSV/XLSX, print; chart toggle (Recharts) when the ERPNext report defines a chart.

### `DashboardView`
Grid of `NumberCard`s (value, delta vs previous period, sparkline) and `DashboardChart`s (Recharts Line/Bar/Area/Donut; `Full` = 2 columns, `Half` = 1), with a date-range + company filter. Cards/charts listed per module from `erpnext/<module>/<module>_dashboard/*.json`.

### `SettingsPage`
Single-doc form rendered from the settings descriptor, grouped by ERPNext's sections, with inline help text taken from the field `description`.

### Onboarding wizard
Steps: Account → Organization (name, slug, country, currency, time zone, language) → Company (name, abbr, fiscal year start, chart of accounts template [Standard | country verified template], bank account name) → Modules to enable → Invite teammates. Calls `app.provision_organization()` once at the end; shows progress like ERPNext's "Setting up the basics / Creating your company / Applying recommended settings".

## Charts (Recharts 3)

- Always client components (`'use client'`), data passed as props from RSC.
- Use `responsive` on the chart root, Untitled UI colour tokens via CSS variables (`var(--color-utility-brand-600)` etc.), minimal grid (`strokeDasharray="3 3"`, horizontal only), custom tooltip component shared across charts, number formatting through `formatCurrency/formatNumber` helpers (company currency, compact notation above 1M).
- Chart types mapping from ERPNext: `Line` → `LineChart`, `Bar` → `BarChart` (stacked when ERPNext `stacked`), `Percentage/Donut` → `PieChart` with inner radius, `Heatmap` → skipped (not in scope).

## Micro-copy & states

- Empty states with one primary action ("Create your first Sales Invoice") and a link to the relevant ERPNext docs page.
- Error states show the Postgres exception message mapped through `src/lib/errors.ts` (e.g. `insufficient_stock` → human text with item/warehouse).
- Toasts for save/submit/cancel; destructive actions use confirm dialogs that state consequences ("This will reverse 6 GL entries and 2 stock ledger entries").
- Loading via skeletons matching the final layout; no spinners in tables.
