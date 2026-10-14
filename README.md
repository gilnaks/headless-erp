# headless-erp

A multi-tenant SaaS re-implementation of ERPNext's default modules (Setup, Accounts, Selling, Buying, Stock, Manufacturing, Projects, Assets) built with Next.js 16, Supabase, Zustand, Untitled UI and Recharts, deployed on Netlify.

**Status:** planning complete, implementation not started.

## Start here

1. `docs/PLAN.md` — master plan and instruction file (scope, stack, architecture, phases, definition of done).
2. `docs/architecture/` — tenancy & RLS, database conventions, posting engine, client/server split, UI system, deployment & backups.
3. `docs/modules/` — one deep-dive per module, derived from the ERPNext source.
4. `docs/erpnext-reference.md` — how to navigate the ERPNext clone while porting.
5. `.cursorrules` + `.cursor/rules/` — the rules Cursor follows on every task.

## Reference

- ERPNext source: `C:\Users\John\Desktop\erpnext` (branch `develop`)
- ERPNext docs: https://docs.frappe.io/erpnext/introduction
