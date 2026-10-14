# How to read the ERPNext repository while porting

Local clone: `C:\Users\John\Desktop\erpnext` (branch `develop`, commit `df5ab70a`, Oct 2026 — the v16 line). Online docs: https://docs.frappe.io/erpnext/introduction. Always read the **code**; docs lag behind.

## Where things live

| What | Path |
|---|---|
| Module list | `erpnext/modules.txt` |
| Module sidebar (= the "tabs" we replicate) | `erpnext/<module>/sidebar/<module>/<module>.json` — items with `type: "Section Break"` are the collapsible groups; `child: 1` items belong to the preceding group |
| Module dashboard (number cards + charts) | `erpnext/<module>/<module>_dashboard/<name>/<name>.json`; card definitions in `erpnext/<module>/number_card/`, charts in `erpnext/<module>/dashboard_chart/` or `erpnext/setup/setup_wizard/data/dashboard_charts.py` |
| Doctype schema | `erpnext/<module>/doctype/<slug>/<slug>.json` → `fields[]` (fieldname, fieldtype, options, reqd, default, fetch_from, read_only, hidden, allow_on_submit, no_copy, depends_on), `permissions[]`, `is_submittable`, `istable`, `issingle`, `is_tree`, `autoname`, `naming_rule`, `title_field`, `states[]` |
| Doctype behaviour | `erpnext/<module>/doctype/<slug>/<slug>.py` → `validate`, `on_submit`, `on_cancel`, `on_update_after_submit`, `get_gl_entries`, `update_stock_ledger`, `set_status`, `make_*` mapper functions (`@frappe.whitelist()`), `get_dashboard_data` in `<slug>_dashboard.py` (= the Connections panel) |
| Client-side defaults/triggers | `erpnext/<module>/doctype/<slug>/<slug>.js` + `erpnext/public/js/controllers/{transaction,taxes_and_totals,buying,selling}.js` |
| List view settings (status colours, filters) | `<slug>_list.js` |
| Shared controllers | `erpnext/controllers/accounts_controller.py`, `stock_controller.py`, `selling_controller.py`, `buying_controller.py`, `status_updater.py`, `taxes_and_totals.py`, `sales_and_purchase_return.py`, `queries.py` (link-field search filters) |
| GL posting | `erpnext/accounts/general_ledger.py`, `erpnext/accounts/utils.py` (fiscal year, balances, reconciliation), `erpnext/accounts/party.py` (party accounts, due dates) |
| Stock ledger & valuation | `erpnext/stock/stock_ledger.py`, `erpnext/stock/valuation.py`, `erpnext/stock/stock_balance.py`, `erpnext/stock/utils.py`, `erpnext/stock/get_item_details.py` |
| Setup wizard defaults | `erpnext/setup/setup_wizard/operations/{install_fixtures,defaults_setup,company_setup,taxes_setup}.py`, `erpnext/setup/setup_wizard/data/*.json`, `erpnext/setup/install.py` (role profiles, single defaults), `erpnext/setup/doctype/company/company.py` (default accounts, warehouses, cost centers, departments) |
| Chart of accounts templates | `erpnext/accounts/doctype/account/chart_of_accounts/verified/standard_chart_of_accounts.py` (+ `_with_account_number.py`, country JSONs) |
| Reports | `erpnext/<module>/report/<slug>/<slug>.{json,py,js}` — `.py` `execute(filters)` returns `(columns, data, message, chart, summary)` |
| Tests (great for expected GL/SLE outputs) | `erpnext/<module>/doctype/<slug>/test_<slug>.py` |
| Hooks (scheduled jobs, doc events) | `erpnext/hooks.py` (`scheduler_events`, `doc_events`) |
| Demo data | `erpnext/setup/demo_data/` |

## Reading a doctype quickly

A helper that prints a compact schema (fieldname : type [options] {flags}) and permissions lives at `scripts/erpnext-doctype.ps1` (copy of the one used during planning). Example:

```powershell
./scripts/erpnext-doctype.ps1 -Names "Sales Invoice","Sales Invoice Item" -Brief
```

Fieldtype → our column mapping: `Data/Small Text/Text/Text Editor` → `text`; `Link` → `uuid` FK (+ denormalised display name when ERPNext stores one); `Dynamic Link` → `(type text, id uuid)`; `Select` → `text` + check; `Check` → `boolean`; `Int` → `integer`; `Float/Percent` → `numeric(21,9)`; `Currency` → `numeric(21,9)`; `Date/Time/Datetime` → native; `Table` → child table; `Table MultiSelect` → child table with one link; `Attach/Attach Image` → storage path text; `Section/Column/Tab Break, HTML, Button, Heading` → UI only (keep Tab Breaks as form tabs).

Skip fields that belong to out-of-scope features (see `docs/PLAN.md §1`) unless they are `reqd` or referenced by the posting code we port — then keep them with ERPNext defaults and hide them in the UI.

## Frappe framework concepts that ERPNext relies on (not in the ERPNext repo)

- `docstatus` 0/1/2 and submit/cancel/amend; `amended_from`; `name` generation from `naming_series` with tokens `.YYYY.`, `.MM.`, `.DD.`, `.#####`; `fetch_from` (denormalise on save); `depends_on`/`mandatory_depends_on` (eval expressions in the UI); `allow_on_submit`; `no_copy`; `set_only_once`; `Role` / `Role Permission` / `User Permission`; `Address` & `Contact` doctypes linked via `Dynamic Link` child table (`links`); `Letter Head`, `Print Format`, `Print Settings`, `Email Account`, `Email Template`; `Currency`, `Country`; `Version`/`Comment` timeline; `Assignment`; `Tag`.
- Standard permission roles seeded by Frappe itself: `System Manager`, `Administrator`, `All`, `Guest`, `Desk User`. We keep `System Manager` only.

## Module docs

Each `docs/modules/NN-<module>.md` follows the same template: scope & sidebar mapping, doctype inventory (table name, type, naming, key fields, child tables, links), document flows & mappers, posting rules, statuses, settings & defaults, reports & dashboard, UI notes, deviations from ERPNext, implementation checklist. When implementing, start from the module doc and open the ERPNext files it cites.
