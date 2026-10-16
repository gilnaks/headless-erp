## Summary

<!-- What changed and why. One engine function per PR. Several masters may share a PR when the Workflow rule allows it. -->

## ERPNext source files consulted

<!-- Paths in the ERPNext / Frappe clone (develop), e.g. erpnext/setup/doctype/company/company.json, company.py, test_company.py. Write "n/a" for framework-only changes. -->

-

## Deviations from ERPNext

<!-- Behaviour intentionally different from ERPNext defaults, with the module doc section that records it. -->

## Checklist (docs/PLAN.md §8)

- [ ] Migration with tables, FKs, indexes, RLS enabled + policies, `updated_at` trigger
- [ ] `doctype_meta` + role permissions registered; `src/types/database.ts` regenerated
- [ ] Descriptor in `src/doctypes/<module>/<slug>.ts` with Zod schema
- [ ] Ledger/status/numbering changes only in `app.*` functions, covered by pgTAP
- [ ] List and form views with empty/loading/error states
- [ ] Default role matrix copied from the doctype JSON `permissions`
- [ ] Tests: pgTAP, Vitest, and Playwright where a critical flow changed
- [ ] Module doc updated if behaviour deviates from ERPNext
- [ ] `get_advisors` clean on the dev project
