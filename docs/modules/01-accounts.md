# 01 — Accounts module

Port of ERPNext v16 (`develop`) **default** accounting: chart of accounts and cost centers, tax masters, the GL / Payment Ledger engine as used by Journal Entry, Payment Entry, Sales Invoice and Purchase Invoice, the core financial reports, banking, budgeting and the Accounts Settings single.

Read with: `docs/PLAN.md` (§5 settings baseline, §7 phases P2/P3/P5/P6/P7), `docs/architecture/02-database-conventions.md` (doc engine, naming, trees), `docs/architecture/03-posting-engine.md` (ledger tables, `app.make_gl_entries`, matrix), `docs/architecture/04-client-vs-server.md` (calc pipeline, reports as SQL), `docs/architecture/05-ui-ux.md` (DocList/DocForm/TreeView/ReportView/DashboardView), `docs/modules/00-setup.md` (Company, Fiscal Year, provisioning, standard chart).

This doc **does not repeat** what 00-setup owns: the `companies` table and its Accounts tab columns (00-setup §2.1), Fiscal Year (§2.23, built in `0114_accounts_fiscal_year.sql`), Address/Contact (§2.19–2.20), provisioning stages and the standard chart tree (§3.1–3.2), role remapping (§2.7). It **picks up** the items 00-setup defers to Accounts: provisioning steps **B3, B4, B6, B7, B9, B10, B13** and fixtures **A11, A13, A15**, the `accounts_settings` row seeded in **A4**, `validate_default_accounts` / `validate_advance_account_currency` on Company, `validate_currency` at the first submittable doctype, the Home P&L chart (`app.report_profit_and_loss`) and the "Complete Accounting Onboarding" step.

ERPNext sources read (repo-relative to `C:\Users\John\Desktop\erpnext`):

- Masters: `erpnext/accounts/doctype/account/account.{json,py}`, `account_category/`, `cost_center/`, `cost_center_allocation/`, `mode_of_payment/`, `payment_term/`, `payment_terms_template/`, `payment_schedule/`, `erpnext/setup/doctype/currency_exchange/`, `accounts_settings/accounts_settings.json`, `party_account/`, `financial_report_template/`.
- Taxes: `sales_taxes_and_charges_template/`, `purchase_taxes_and_charges_template/`, `sales_taxes_and_charges/`, `purchase_taxes_and_charges/`, `item_tax_template/`, `tax_category/`, `tax_rule/tax_rule.py`, `tax_withholding_category/`, `erpnext/accounts/services/taxes.py`, `erpnext/stock/get_item_details.py` (`get_item_tax_map`).
- Transactions: `journal_entry/journal_entry.py`, `journal_entry/services/{gl_composer,reference_validator}.py`, `journal_entry/mapper.py`, `payment_entry/payment_entry.py`, `payment_entry/services/gl_composer.py`, `sales_invoice/sales_invoice.{json,py}`, `sales_invoice/services/{gl_composer,status}.py`, `sales_invoice/mapper.py`, `sales_invoice/sales_invoice_list.js`, `sales_invoice/sales_invoice_dashboard.py`, `purchase_invoice/purchase_invoice.{json,py}`, `purchase_invoice/services/{gl_composer,expense_account}.py`, `purchase_invoice/purchase_invoice_{list.js,dashboard.py}`.
- Engine & shared: `erpnext/accounts/general_ledger.py`, `gl_entry/gl_entry.py`, `erpnext/accounts/utils.py`, `erpnext/accounts/party.py`, `erpnext/controllers/accounts_controller.py`, `erpnext/controllers/taxes_and_totals.py`, `erpnext/controllers/sales_and_purchase_return.py`, `erpnext/accounts/services/{advances,payment_schedule}.py`, `erpnext/selling/doctype/customer/customer.py` (credit limit), `erpnext/controllers/budget_controller.py`, `budget/budget.py`, `erpnext/hooks.py` (scheduler).
- Banking: `bank/`, `bank_account/`, `bank_transaction/bank_transaction.py`, `bank_reconciliation_tool/bank_reconciliation_tool.py`, `bank_clearance/bank_clearance.py`.
- Reports & dashboard: `erpnext/accounts/report/{general_ledger,trial_balance,trial_balance_for_party,balance_sheet,profit_and_loss_statement,cash_flow,consolidated_financial_statement,profitability_analysis,accounts_receivable,accounts_payable,budget_variance_report}/`, `erpnext/accounts/report/financial_statements.py`, `erpnext/public/js/financial_statements.js`, `erpnext/accounts/accounts_dashboard/accounts/accounts.json`, `erpnext/accounts/number_card/*`, `erpnext/accounts/dashboard_chart/*`.
- Tests used for worked examples: `sales_invoice/test_sales_invoice.py` (+ `test_records.json`), `purchase_invoice/test_purchase_invoice.py`, `payment_entry/test_payment_entry.py`, `journal_entry/test_journal_entry.py`.

---

## 1. Scope & sidebar mapping

Module id `accounts`, label **Accounting** (main `src/config/navigation.ts`). Routes are `/[org]/accounts/<slug>`; each row is one descriptor in `src/doctypes/accounts/<slug>.ts` unless marked page/report.

| Sidebar group › item (ERPNext workspace) | Route / target | Kind | Phase | Status |
|---|---|---|---|---|
| Home | `/[org]/accounts` | workspace | P3 | new |
| Dashboard | `/[org]/accounts/dashboard` | DashboardView (§7.1) | P3 | new |
| Chart of Accounts | `accounts/account` | TreeView + DocForm (Account) | P2 | new |
| Sales Invoice | `accounts/sales-invoice` | doctype (submittable) | P5 | new |
| Purchase Invoice | `accounts/purchase-invoice` | doctype (submittable) | P6 | new |
| Payment Entry | `accounts/payment-entry` | doctype (submittable) | P3 | new |
| Journal Entry | `accounts/journal-entry` | doctype (submittable) | P3 | new |
| Reports › General Ledger, Trial Balance, Trial Balance for Party, Profit and Loss Statement, Balance Sheet, Cash Flow | `accounts/report/<slug>` | ReportView (§7.2) | P3 | new |
| Reports › Consolidated Financial Statement, Profitability Analysis | `accounts/report/<slug>` | ReportView | P3 nav / **stretch** | new |
| Reports › Accounts Receivable, Accounts Payable | `accounts/report/<slug>` | ReportView | P7 | new |
| Banking › Banking (ERPNext URL `/banking`) | `accounts/bank-reconciliation` | page (Bank Reconciliation Tool) | P7 | new |
| Banking › Bank Account | `accounts/bank-account` | doctype | P7 | new |
| Banking › Bank Clearance | `accounts/bank-clearance` | single-tool page | P7 | new |
| *(not in nav)* Bank, Bank Account Type, Bank Account Subtype, Bank Transaction | `accounts/bank`, `accounts/bank-account-type`, `accounts/bank-account-subtype`, `accounts/bank-transaction` | doctypes (Connections / links) | P7 | new |
| Taxes › Sales Taxes and Charges Template, Purchase Taxes and Charges Template, Item Tax Template, Tax Rule | `accounts/<slug>` | doctypes | P2 | new |
| *(not in nav)* Tax Category | `accounts/tax-category` | doctype (link target) | P2 | new |
| Taxes › Tax Withholding Category | `accounts/tax-withholding-category` | doctype (basic) | P7 | new |
| Budgeting › Budget, Cost Center Allocation, Monthly Distribution | `accounts/<slug>` | doctypes | P7 | new |
| Budgeting › Budget Variance Report | `accounts/report/budget-variance-report` | ReportView | P7 | new |
| Setup › Company | `setup/company` | (00-setup) | P1 | **exists** |
| Setup › Fiscal Year | `accounts/fiscal-year` | (00-setup §2.23) | P1 | **exists** |
| Setup › Chart of Cost Centers | `accounts/cost-center` | TreeView + DocForm | P2 | new |
| Setup › Mode of Payment, Payment Term, Payment Terms Template, Currency Exchange | `accounts/<slug>` | doctypes | P2 | new |
| Setup › Account Category | `accounts/account-category` | doctype | P2 | |
| Setup › Financial Report Template | — | not built (§9) | — | deferred |
| Setup › Accounts Settings | `accounts/settings` | single (DocForm) | P3 | new (row exists since A4) |
| *(tool, not in nav)* Payment Reconciliation | `accounts/payment-reconciliation` | page | P3 basic | new |

Out of scope (PLAN / `.cursorrules`): Accounting Dimension, Deferred Revenue/Expense, Period Closing Voucher, Accounting Period, Repost Accounting Ledger / Repost Payment Ledger, Subscription, POS Invoice / POS Profile / POS Closing, Loyalty Program, Payment Request / Payment Order / Payment Gateway, Dunning, Invoice Discounting, Exchange Rate Revaluation, Process Statement of Accounts, Opening Invoice Creation Tool, Bank Transaction Rule / Plaid, Journal Entry Template, Share Transfer, Shipping Rule, Promotional Scheme / Pricing Rule, e-invoicing / regional, multi-currency beyond *document currency + conversion rate* (party, bank and every ledger account stay in company currency, §9).

---

## 2. Doctype inventory

Conventions for every table below (from 02-database-conventions, not repeated per table): `id uuid pk`, `org_id`, `name text` (unique per org), audit columns, RLS template from 01-tenancy (`app.has_perm` + `app.company_allowed` for company-scoped rows), FK columns are `<field>_id` (ERPNext `customer` → `customer_id`), money/qty `numeric(21,9)`, `Check` → `boolean`, `Select` → `text` + `check`. Submittables add `naming_series`, `docstatus`, `amended_from`; children add `parent_id`, `idx`. Trees use `parent_id` + `is_group` + `path ltree` (no `lft/rgt`). "Perms" lists ERPNext JSON roles as `r w c s x d` (read, write, create, submit, cancel, delete); we seed them into `role_permissions` as-is unless noted.

### 2.1 Account → `account`

- **Kind:** tree master, company-scoped. `nsm_parent_field = parent_account`, `search_fields = account_number`. Migration `0212_accounts_account.sql`.
- **Naming:** `get_autoname_with_number(account_number, account_name, company)` → `"<account_number> - <account_name> - <ABBR>"` or `"<account_name> - <ABBR>"` (`erpnext/accounts/utils.py`). Renames via `update_account_number` keep this format.
- **Perms:** Accounts User rwcd, Accounts Manager rwcd, Auditor r, Sales User r, Purchase User r. System Manager read (the coverage default; the JSON does not grant System Manager).

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| account_name | text | ✔ | | |
| account_number | text | | | unique per company (`validate_account_number`: "Account Number {0} already used in account {1}") |
| is_group | boolean | | false | |
| company | company_id uuid | ✔ | parent's company | read-only after insert |
| root_type | text check `Asset\|Liability\|Income\|Expense\|Equity` | ✔ (derived) | inherited from parent | read-only; required on roots ("Root Type is mandatory") |
| report_type | text check `Balance Sheet\|Profit and Loss` | ✔ (derived) | Asset/Liability/Equity → Balance Sheet, else Profit and Loss | read-only |
| account_currency | text → currency | | company currency | only company currency selectable (§9) |
| parent_account | parent_id uuid → account | ✔ (non-root) | | must be a group of the same company |
| account_type | text check (32 options, below) | | null | |
| tax_rate | numeric | | 0 | used when the account is picked as a tax row (`get_tax_rate`) |
| freeze_account | text check `No\|Yes` | | `No` | only users holding `companies.role_allowed_for_frozen_entries` may set it ("You are not authorized to set Frozen value") |
| balance_must_be | text check `''\|Debit\|Credit` | | '' | blocked if current balance contradicts it |
| include_in_gross | boolean | | false | |
| account_category | account_category_id uuid | | from CoA template | |
| disabled | boolean | | false | |
| path | ltree | ✔ | trigger | tree maintenance |

`account_type` options (verbatim): Accumulated Depreciation, Asset Received But Not Billed, Bank, Cash, Chargeable, Capital Work in Progress, Cost of Goods Sold, Current Asset, Current Liability, Depreciation, Direct Expense, Direct Income, Equity, Expense Account, Expenses Included In Asset Valuation, Expenses Included In Valuation, Fixed Asset, Income Account, Indirect Expense, Indirect Income, Liability, Payable, Receivable, Round Off, Round Off for Opening, Stock, Stock Adjustment, Stock Received But Not Billed, Stock Delivered But Not Billed, Service Received But Not Billed, Tax, Temporary.

- **Validations ported (`account.py`):** `validate_parent` (exists, not itself, is group, same company); `validate_parent_child_account_type` ("Only Parent can be of type {0}" for Direct/Indirect Income/Expense, Current Asset/Liability); `validate_root_details` ("Root cannot be edited.", roots must be groups); `set_root_and_report_type` (inherit; changing a group's root type cascades to descendants); `validate_group_or_ledger` / `convert_group_to_ledger` / `convert_ledger_to_group` ("Account with existing transaction cannot be converted to ledger", "Account with child nodes cannot be set as ledger", "Cannot covert to Group because Account Type is selected." — ERPNext typo kept); default-account guard: an account referenced by any company default (`get_company_default_account_fields`: default bank/cash/receivable/payable/expense/income, SRBNB, SDBNB, stock adjustment, write off, bank charges, default discount, exchange gain/loss ×3, round off, accumulated depreciation, depreciation expense, disposal, deferred ×2) cannot be disabled or turned into a group; `validate_frozen_accounts_modifier`; `validate_balance_must_be_debit_or_credit`; `validate_account_currency` (cannot change once GL exists in another currency); receivable/payable `account_type` change on an account with GL only posts a warning comment; changing an account of type Stock with SLEs is blocked.
- **Whitelisted actions → RPCs:** `app.convert_account_group_ledger(id, to_group bool)`, `app.update_account_number(id, account_name, account_number)` (renames the row and recomputes descendants' display names; ERPNext's `_ensure_idle_system` guard is not needed), `app.merge_account(old_id, new_id)` (requires equal `is_group`, `root_type`, `company`, `account_currency`; repoints `gl_entry`/`payment_ledger_entry`/child links in one transaction, then deletes the old row). `on_trash`: "Account with existing transaction can not be deleted" (any `gl_entry`); children block deletion.
- **Child-company sync:** ERPNext creates the same account in child companies when created on a parent (`allow_account_creation_against_child_company`). Kept: `companies.allow_account_creation_against_child_company` exists (0100); P2 implements the parent→child propagation only for the insert path.
- **Tree UI:** TreeView with columns name, account_type, balance (when `accounts_settings.show_balance_in_coa`), `Dr/Cr` suffix; filters company, root_type, disabled. Connections: General Ledger report (`account` filter), Budget.
- **Built (0212, display-name grant 0213):** `app.create_charts` and `app.set_default_accounts` run from `companies_seed_accounts`, an after-insert trigger on `companies` (B3, B4, B9), and once for companies that already exist. `app.account_display_name` is executable by signed-in users because the row trigger calls it (0213). An empty balance rule or freeze value is stored as the column default (0214). A company that already has accounts is left alone. Eleven company foreign keys point at `account` (receivable, payable, cash, bank, expense, income, round off, write off, inventory, stock adjustment, and stock received but not billed), each with an index on `(org_id, column)`. `account (org_id, account_category_id)` is indexed too. The other default-account columns are filled and stay plain uuid. `update_account_number`, group/ledger conversion, `merge_account`, frozen-account and balance-must-be checks, and the ledger guards wait for the ledger. The optional wizard bank account (B13) still waits.

### 2.2 Account Category → `account_category`

- **Migration:** `0210_accounts_account_category.sql`.
- **Kind:** org-level master (not company-scoped). **Naming:** `field:account_category_name`. **Perms:** Accounts User rwcd, Accounts Manager rwcd, Auditor r. System Manager read (the coverage default; the JSON does not grant System Manager).
- Fields: `account_category_name` text ✔ unique; `description` text; `root_type` text check (same five) — informational, used by Financial Report Templates in ERPNext.
- Seeded with every distinct `account_category` in the vendored charts (00-setup §3.2: Trade Receivables, Cash and Cash Equivalents, Other Receivables, … Reserves and Surplus), not only the organization's chart. The seed stores the name only, so `root_type` stays null. Needed because the standard chart assigns one to almost every account. No transactional effect in our scope. The account foreign key is `account.account_category_id` (0212).

### 2.3 Cost Center → `cost_center`

- **Kind:** tree master, company-scoped. `nsm_parent_field = parent_cost_center`. Root is the node whose `cost_center_name = company_name`. **Naming:** `get_autoname_with_number(cost_center_number, cost_center_name, company)`. Migration `0215_accounts_cost_center.sql`.
- **Perms:** Accounts Manager rwcd, Auditor r, Accounts User r, Sales User r, Purchase User r. System Manager read (the coverage default; the JSON does not grant System Manager).

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| cost_center_name | text | ✔ | | |
| cost_center_number | text | | | |
| parent_cost_center | parent_id uuid | ✔ (non-root) | | must be group, same company ("{0} is not a group node. Please select a group node as parent cost center") |
| company | company_id | ✔ | | "Company cannot be changed for an existing Cost Center" |
| is_group | boolean | | false | group→ledger blocked by children / GL; ledger→group blocked by GL, by being an allocation main or allocation child |
| disabled | boolean | | false | |
| path | ltree | ✔ | trigger | |

- Validations: `validate_mandatory` ("Please enter parent cost center" / "Root cannot have a parent cost center"), `validate_parent_cost_center`, `validate_changes`. Actions: convert group/ledger, update number (same RPC shape as Account).
- **Built (0215):** `app.seed_cost_centers` runs from `companies_seed_cost_centers`, an after-insert trigger on `companies` (B6), and once for companies that already exist. A company that already has cost centers is left alone. The root is a group named after the company; `Main` is the ledger under it. `cost_center_id`, `round_off_cost_center_id`, and `depreciation_cost_center_id` point at Main, each with an index on `(org_id, column)`. Group/ledger conversion and number rename wait.

### 2.4 Cost Center Allocation → `cost_center_allocation` + child `cost_center_allocation_percentage` (P7)

- **Kind:** submittable. **Naming:** `CC-ALLOC-.#####`. **Perms:** System Manager, Accounts Manager, Accounts User: rwcsxd.
- Header: `main_cost_center_id` ✔ (ledger, not itself a child of another active allocation), `company_id` ✔ (fetched), `valid_from` date ✔ default Today. Child `allocation_percentages`: `cost_center_id` ✔, `percentage` ✔.
- Validations: "Total percentage against cost centers should be 100"; `validate_from_date_based_on_existing_gle` (valid_from cannot be before a GL posted to the main cost center after the allocation start); `validate_backdated_allocation`; main cost center cannot be a child of another allocation and vice versa (`validate_main_cost_center`, `validate_child_cost_centers`).
- **Effect:** `app.make_gl_entries` step "distribute cost center allocation": a P&L row whose `cost_center` is an allocation main cost center with an active allocation (`valid_from <= posting_date`, latest wins) is split into one row per child cost center by percentage, last row absorbing rounding (`general_ledger.process_gl_map` → `distribute_gl_based_on_cost_center_allocation`).

### 2.5 Mode of Payment → `mode_of_payment` + child `mode_of_payment_account`

- **Kind:** org-level master. **Naming:** `field:mode_of_payment`. **Perms:** Accounts Manager rwc, Accounts User r (we add Sales/Purchase User r for link lookups).
- Header: `mode_of_payment` text ✔ unique; `enabled` boolean default true; `type` text check `Cash|Bank|General|Phone` (no default, not required — as ERPNext).
- Child `accounts`: `company_id` ✔, `default_account_id` (Bank/Cash ledger of that company). Validations: "Account {0} does not match with Company {1} in Mode of Account: {2}", "Same Company is entered more than once".
- **Fixtures (A11):** Cheque (`Check` when country = United States) Bank; Cash Cash; Credit Card Bank; Wire Transfer Bank; Bank Draft Bank. **B10:** `Cash` → `(company, default_cash_account)`.
- **Built (0218):** `app.seed_modes_of_payment` runs from `organizations_seed_modes_of_payment`, an after-insert trigger on `organizations` (A11), and once for organizations that already exist. `app.set_mode_of_payment_account` runs from `companies_seed_mode_of_payment`, an after-insert trigger on `companies` (B10), and once for companies that already exist. Cash is linked to `default_cash_account_id` only when that company has no Cash row yet. Deleting that account removes the company row (`0219`, `0220`). System Manager can read. Accounts Manager can create and edit. A repeated company raises `mode_of_payment_company`. An account from another company raises `mode_of_payment_account`. POS profile checks are not built. The account picker is not limited to Bank, Cash, or Receivable.

### 2.6 Payment Term → `payment_term`; Payment Terms Template → `payment_terms_template` + child `payment_terms_template_detail`

- **Payment Term** (org-level, naming `field:payment_term_name`; perms System Manager / Accounts Manager / Accounts User rwcd):

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| payment_term_name | text | ✔ | | unique |
| invoice_portion | numeric (Percent) | | | |
| mode_of_payment | mode_of_payment_id | | | |
| due_date_based_on | text check `Day(s) after invoice date\|Day(s) after the end of the invoice month\|Month(s) after the end of the invoice month` | | | |
| credit_days | int | | 0 | |
| credit_months | int | | 0 | |
| discount_type | text check `Percentage\|Amount` | | `Percentage` | |
| discount | numeric | | | early-payment discount (P7, §9) |
| discount_validity_based_on | text check (same three) | | `Day(s) after invoice date` | |
| discount_validity | int | | | |
| description | text | | | |

- **Payment Terms Template** (naming `field:template_name`; perms System Manager / Accounts User / Accounts Manager rwcd, read for Purchase/Sales Manager/User, Manufacturing Manager): `template_name` ✔ unique, `allocate_payment_based_on_payment_terms` boolean default false, child `terms` ✔ (rows copy the term fields above + `payment_term_id`, `invoice_portion` ✔, `due_date_based_on` ✔, `credit_days` default 0, `credit_months` default 0).
- Validations: "Combined invoice portion must equal 100%"; "Row {0}: Payment Term is mandatory" when `allocate_payment_based_on_payment_terms`; duplicate term rows rejected.
- Links in: `customer.payment_terms_id`, `customer_group`, `supplier`, `supplier_group`, `companies.payment_terms_id` (FK added here), SO/PO/SI/PI `payment_terms_template_id`.
- **Built (0221, 0222, 0223):** Payment Term and Payment Terms Template are organization masters. The name is the trimmed term or template name. A template save whose portions do not add to 100 raises `payment_terms_portion`. With allocate on, a row without a term raises `payment_term_required`. The same term twice raises `payment_term_duplicate`. System Manager, Accounts Manager, and Accounts User can create and delete both. Purchase, Sales, and Manufacturing managers can read a template. `companies.payment_terms_id` points at the template, and the company selling and buying terms point at Terms and Conditions. Deleting the target nulls that link and leaves `org_id` set. A term that a template row still uses cannot be deleted. Deleting the organization removes its templates first (`0223`), so those rows do not block the terms. Customer, supplier, and invoice links wait for those tables.

### 2.7 Payment Schedule → `payment_schedule` (child of SO, PO, SI, PI; Quotation/SQ in 02/03)

One shared child doctype, one table per parent per 02-db conventions (`sales_invoice_payment_schedule`, …) generated from one TS child descriptor. Fields: `payment_term_id`, `description`, `due_date` date ✔, `invoice_portion`, `payment_amount` ✔, `mode_of_payment_id`, `paid_amount`, `discounted_amount`, `outstanding`, `discount_date`, `discount_type`, `discount`, `base_payment_amount`, `base_outstanding`, `base_paid_amount`, `due_date_based_on`, `credit_days`, `credit_months`, `discount_validity_based_on`, `discount_validity`. Behaviour in §3.9.

### 2.8 Currency Exchange → `currency_exchange`

- **Kind:** org-level master (ERPNext module Setup; owned here). **Naming:** `"<yyyy-MM-dd>-<FROM>-<TO>-<Selling-Buying|Selling|Buying>"`. **Perms:** Accounts Manager rwcd, Accounts User r, Sales User r, Purchase User r.
- Fields: `date` ✔ (default Today), `from_currency` ✔, `to_currency` ✔, `exchange_rate` numeric ✔, `for_buying` boolean default true, `for_selling` boolean default true.
- Validations: "From Currency and To Currency cannot be same", exchange rate > 0, "Currency Exchange must be applicable for Buying or for Selling."
- `app.get_exchange_rate(from, to, date, args)` (port of `erpnext.setup.utils.get_exchange_rate`, default path): same currency → 1; latest `currency_exchange` row with `date <= transaction_date` filtered by `for_selling`/`for_buying` per caller; if `accounts_settings.allow_stale = false`, only rows within `stale_days`; else **no network fallback** (ERPNext calls `frankfurter.dev`; we return 0 and the form asks for a rate, §9).

### 2.9 Party Account (child of Customer, Customer Group, Supplier, Supplier Group) → `party_account`

Owned by 02-selling/03-buying for the parent tables; behaviour here. Fields: `company_id` ✔, `account_id` (Receivable for customers, Payable for suppliers), `advance_account_id` (hidden; separate-advance-account mode is off, §9). Validations (`party.validate_party_accounts`): "There can only be 1 Account per Company in {0} {1}", "Row {0}: Account {1} must be a {2} account", party currency vs existing GL (`validate_party_gle_currency`).

### 2.10 Accounts Settings → `accounts_settings` (single, one row per org; seeded A4)

Full field list in §6. **Perms:** Accounts Manager rw; Sales User r, Purchase User r (we add Accounts User r).

### 2.11 Sales / Purchase Taxes and Charges Template → `sales_taxes_and_charges_template` / `purchase_taxes_and_charges_template` + children

- **Kind:** company-scoped master. **Naming:** `"<title> - <ABBR>"` (`autoname`). Title field `title`.
- **Perms:** Sales template — Accounts Manager rwcd, Sales Master Manager rwcd, Sales User r (others read-only: Accounts User, Stock, Purchase, Manufacturing, Maintenance, Delivery roles — we keep Accounts User/Stock User/Purchase User r). Purchase template — Purchase Master Manager rwcd, Purchase Manager r, Purchase User r, Accounts Manager/User r (**we add Accounts Manager rwcd** for parity with Sales; §9).
- Header: `title` ✔, `is_default` boolean false, `disabled` boolean false, `company_id` ✔, `tax_category_id`, child `taxes`.
- **Sales Taxes and Charges** child (also used by Quotation/SO/DN/SI): `charge_type` ✔ `Actual|On Net Total|On Previous Row Amount|On Previous Row Total|On Item Quantity`, `row_id` int, `account_head_id` ✔, `description` ✔, `included_in_print_rate` boolean false, `included_in_paid_amount` boolean false, `cost_center_id` default company cost center, `rate`, `account_currency`, `tax_amount`, `total`, `tax_amount_after_discount_amount`, `base_tax_amount`, `base_total`, `base_tax_amount_after_discount_amount`, `net_amount`, `base_net_amount`, `project_id`, `dont_recompute_tax` (hidden), `set_by_item_tax_template` (hidden).
- **Purchase Taxes and Charges** child (SQ/PO/PR/PI): adds `category` ✔ default `Total` (`Valuation and Total|Valuation|Total`), `add_deduct_tax` ✔ default `Add` (`Add|Deduct`), `charge_type` default `On Net Total`, `allocate_full_amount_to_stock_items` boolean default true (shown when `charge_type = Actual` and category includes Valuation: the whole amount goes to the valuation of stock/asset items only; unchecked → spread over all items and the non-stock share is not capitalised — `test_full_actual_charge_capitalized_on_stock_items_only`).
- Validations (`valdiate_taxes_and_charges_template` — ERPNext typo): setting `is_default` clears other defaults of the company; "Disabled template must not be default template"; one enabled template per `tax_category` per company ("A template with tax category {0} already exists. Only one template is allowed with each tax category"); per row `validate_taxes_and_charges` ("Can refer row only if the charge type is 'On Previous Row Amount' or 'Previous Row Total'", "Cannot select charge type as 'On Previous Row Amount' or 'On Previous Row Total' for first row", "Please specify a valid Row ID for row {0} in table {1}", "Cannot refer row number greater than or equal to current row number for this Charge type"; `Actual` rows get `rate = null`), `validate_account_head` (ledger of the company), `validate_cost_center`, `validate_inclusive_tax` ("Charge of type 'Actual' in row {0} cannot be included in Item Rate or Paid Amount", "To include tax in row {0} in Item rate, taxes in rows {1} must also be included").
- **Provisioning (B7):** `app.create_default_tax_templates(company_id)` from `country_wise_tax.json` as specified in 00-setup Stage B7.

### 2.12 Item Tax Template → `item_tax_template` + child `item_tax_template_detail`

- Company-scoped; naming `"<title> - <ABBR>"`. Perms: System Manager rwcd, Accounts Manager rwcd, Accounts User r (+ read for selling/buying/stock roles).
- Header `title` ✔, `company_id` ✔, `disabled` false, child `taxes` ✔: `tax_type_id` → account ✔, `tax_rate` numeric, `not_applicable` boolean false (forces rate 0 and excludes the row: `NOT_APPLICABLE_TAX`).
- Validations: "Item Tax Row {0}: Account must belong to Company - {1}"; account type must be one of Tax, Chargeable, Income Account, Expense Account, Expenses Included In Valuation ("Item Tax Row {0} must have account of type Tax or Income or Expense or Chargeable"); "{0} entered twice in Item Tax".
- Used through `item_tax` child rows on Item / Item Group (04-stock owns the tables: `item_tax_template_id`, `tax_category_id`, `valid_from`, `minimum_net_rate`, `maximum_net_rate`). `get_item_tax_map(doc, template)` = `{account_head: rate}` from the document's tax rows (not set by template) overlaid with the template's rows for the doc company.

### 2.13 Tax Category → `tax_category`

Org-level; naming `field:title`; `title` ✔ unique, `disabled` false. Perms System Manager / Accounts Manager rwcd, Accounts User r (+ read for selling/buying/stock). Links in: Customer, Supplier, Address (`tax_category`), templates, Tax Rule, Item Tax rows. `get_address_tax_category` uses `accounts_settings.determine_address_tax_category_from` (`Billing Address`).

### 2.14 Tax Rule → `tax_rule`

- Company-scoped (company optional in ERPNext; required by us because templates are per company). **Naming:** `ACC-TAX-RULE-.YYYY.-.#####`. Perms: Accounts Manager rwcd.
- Fields: `tax_type` `Sales|Purchase` default `Sales`; `use_for_shopping_cart` boolean default true (kept, no effect); `sales_tax_template_id`; `purchase_tax_template_id`; `customer_id`; `customer_group_id`; `supplier_id`; `supplier_group_id`; `item_id`; `item_group_id`; `billing_city/county/state/zipcode/country`; `shipping_city/county/state/zipcode/country`; `tax_category_id`; `from_date`; `to_date`; `priority` int default 1; `company_id`.
- Validations: clears the other side's fields by `tax_type`; customer clears customer_group (and supplier clears supplier_group); "Tax Template is mandatory."; `validate_from_to_dates`; conflicting rule (same filter values, overlapping dates, same priority) → "Tax Rule Conflicts with {0}".
- `app.get_tax_template(posting_date, args jsonb)` (port of `tax_rule.get_tax_template`): candidate rules where every filter column is empty or equals the arg (customer/supplier group matches any ancestor), dates contain `posting_date`; pick max `no_of_keys_matched`, then max `priority`; disabled template → null. Called by `app.set_taxes(party, party_type, posting_date, company, …)` from party.py (`set_taxes`), which adds billing/shipping address parts.

### 2.15 Tax Withholding Category → `tax_withholding_category` + `tax_withholding_rate` + `tax_withholding_account` (P7, basic)

- Org-level; naming = prompt (`name` = user input). Perms: System Manager, Accounts Manager, Accounts User rwcd.
- Header: `category_name`, `tax_deduction_basis` ✔ default `Net Total` (`Gross Total|Net Total`), `tax_on_excess_amount` false, `round_off_tax_amount` false, `disable_cumulative_threshold` false, `disable_transaction_threshold` false. Child `rates` ✔: `from_date` ✔, `to_date` ✔, `tax_withholding_rate` ✔, `single_threshold`, `cumulative_threshold` (`tax_withholding_group` dropped). Child `accounts` ✔: `company_id` ✔, `account_id` ✔.
- Basic behaviour in §3.10. Links: `supplier.tax_withholding_category_id`, PI `tax_withholding_category_id` + `apply_tds`.

### 2.16 Journal Entry → `journal_entry` + child `journal_entry_account` (P3)

- **Kind:** submittable, company-scoped. **Naming series:** `ACC-JV-.YYYY.-` (only option). Title `title` = `pay_to_recd_from or accounts[0].account`. **Perms:** Accounts User rwcsxd, Accounts Manager rwcsxd, Auditor r.
- **List:** columns title, voucher_type (indicator: submitted rows show the voucher type in blue — `journal_entry_list.js`), posting_date, total_debit, company; standard filters voucher_type, company; search voucher_type, posting_date, due_date, cheque_no.

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| voucher_type | text check | ✔ | `Journal Entry` | enabled options §3.6; hidden ones blocked by check |
| naming_series | text | ✔ | `ACC-JV-.YYYY.-` | |
| company | company_id | ✔ | user default | |
| posting_date | date | ✔ | Today | inside an FY; not ≤ `accounts_frozen_till_date` unless role |
| accounts | child | ✔ | | "Accounts table cannot be blank." |
| cheque_no / cheque_date | text / date | Bank Entry ✔ | | "Reference No & Reference Date is required for {0}"; "Reference No is mandatory if you entered Reference Date" |
| user_remark (`remark`) | text | | auto | `create_remarks` builds "Reference #… dated …" + reference/bill remarks |
| total_debit / total_credit / difference | numeric ro | | | `set_total_debit_credit` |
| multi_currency | boolean | | false | hidden, fixed false (§9) |
| is_opening | text check `No\|Yes` | | `No` | forced `Yes` for `Opening Entry` |
| bill_no / bill_date / due_date | text / date / date | | | due_date copied to party GL rows |
| write_off_based_on | text check `Accounts Receivable\|Accounts Payable` | | `Accounts Receivable` | Write Off Entry helper |
| write_off_amount | numeric | | | |
| pay_to_recd_from | text | | | |
| mode_of_payment_id | uuid | | | |
| letter_head_id / select_print_heading | | | | |
| reversal_of | journal_entry_id ro | | | set by "Reverse Journal Entry" |
| stock_entry_id | uuid ro | | | 04-stock link |
| clearance_date | date | | | Bank Clearance (allow_on_submit); cleared on validate/amend |
| custom_remark | boolean | | false | keep user remark verbatim |
| finance_book, inter_company_journal_entry_reference, payment_order, auto_repeat, from_template, tax_withholding_*, apply_tds, process_deferred_accounting, periodic_entry_difference_account, for_all_stock_asset_accounts, stock_asset_account, total_amount_currency, total_amount | — | | | **not built** (out-of-scope features) |

`journal_entry_account` child: `account_id` ✔, `account_type` (ro cache), `bank_account_id`, `party_type` (text check `Customer|Supplier`), `party_id` (uuid; FK via party link table per 02-db dynamic-link rule or two nullable FKs `customer_id`/`supplier_id` + generated `party_id` — implementation choice recorded in the migration), `cost_center_id` (default company cost center), `project_id`, `account_currency` ro, `exchange_rate` (fixed 1), `debit_in_account_currency`, `debit` ro, `credit_in_account_currency`, `credit` ro, `reference_type` (`Sales Invoice|Purchase Invoice|Journal Entry|Sales Order|Purchase Order`; Expense Claim/Asset/Loan/Payroll/Employee Advance/Fees/Invoice Discounting dropped), `reference_name` (`reference_id`), `reference_due_date`, `reference_detail_no`, `is_advance` `No|Yes`, `against_account` ro text, `user_remark`, `advance_voucher_type/no` (ro, set by engine).

Validations: see §3.6.

### 2.17 Payment Entry → `payment_entry` + `payment_entry_reference` + `payment_entry_deduction` + `advance_taxes_and_charges` (P3)

- **Kind:** submittable. **Naming series:** `ACC-PAY-.YYYY.-`. Title `title` (= party_name, or paid_from→paid_to for Internal Transfer). **Perms:** Accounts User rwcsxd, Accounts Manager rwcsxd. Status `Draft|Submitted|Cancelled`.
- **List:** columns title, payment_type, posting_date, paid_from, paid_to, status; standard filters payment_type, posting_date, party_type, party, reference_no; party_type filter limited to party types with an account type.

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| naming_series | text | ✔ | `ACC-PAY-.YYYY.-` | |
| payment_type | text check `Receive\|Pay\|Internal Transfer` | ✔ | `Receive` | |
| posting_date | date | ✔ | Today | |
| company | company_id | ✔ | | |
| mode_of_payment_id | uuid | | | sets the bank/cash account (`get_bank_cash_account`) |
| party_type | text check `Customer\|Supplier` | ✔ unless Internal Transfer | | |
| party (party_id) / party_name | uuid / text | ✔ unless IT | | `ensure_supplier_is_not_blocked` (supplier `on_hold` hold_type All/Payments) |
| contact_person_id / contact_email | | | | |
| party_balance | numeric ro | | | |
| paid_from | paid_from_account_id | ✔ | Receive: party account; else bank/cash | |
| paid_from_account_currency / paid_from_account_type / paid_from_account_balance | ro | | | |
| paid_to | paid_to_account_id | ✔ | Pay: party account; else bank/cash | "paid_from and paid_to must differ" for IT |
| paid_to_account_currency / paid_to_account_type / paid_to_account_balance | ro | | | |
| paid_amount | numeric | ✔ | outstanding | |
| source_exchange_rate / target_exchange_rate | numeric | ✔ | 1 | fixed 1 (company currency accounts) |
| base_paid_amount / received_amount / base_received_amount | numeric | ✔ (received) | = paid_amount | |
| references | child | | from get_outstanding | |
| total_allocated_amount / base_total_allocated_amount / unallocated_amount / difference_amount | numeric ro | | | §3.7 |
| deductions | child | | | |
| taxes / total_taxes_and_charges / base_total_taxes_and_charges | child / numeric | | | Advance Taxes and Charges (basic, §3.7) |
| reference_no / reference_date | text / date | ✔ when paid_from/paid_to is a Bank account | | "Reference No and Reference Date is mandatory for Bank transaction" |
| clearance_date | date | | | Bank Clearance (allow_on_submit) |
| project_id / cost_center_id | uuid | | from source doc | |
| bank_account_id / party_bank_account_id / bank / bank_account_no | | | default company Bank Account (`is_company_account`, `is_default`) | |
| remarks / custom_remarks | text / boolean | | auto | `set_remarks`: "Amount {currency} {amount} {received from\|paid to} {party}\nTransaction reference no {ref} dated {date}" + "Amount … against Sales Invoice …" lines |
| is_opening | text check | | `No` | |
| status | text | | `Draft` | |
| book_advance_payments_in_separate_party_account, apply_tds, tax_withholding_category, payment_order, … | — | | | not built (§9) |

`payment_entry_reference`: `reference_doctype` ✔ (`Sales Invoice|Purchase Invoice|Journal Entry|Sales Order|Purchase Order|Payment Entry` — Dunning/Employee Advance dropped), `reference_name` ✔ (`reference_id`), `due_date`, `bill_no`, `payment_term_id`, `payment_term_outstanding`, `account_type`, `payment_type`, `total_amount` ro, `outstanding_amount` ro, `allocated_amount`, `exchange_rate` (1), `exchange_gain_loss` (0), `account_id`, `advance_voucher_type`. `payment_entry_deduction`: `account_id` ✔, `cost_center_id` ✔, `amount` ✔ (company currency; negative = credit), `is_exchange_gain_loss` boolean (always false for us), `description`.

### 2.18 Sales Invoice → `sales_invoice` + children (P5; owned here, flows in 02-selling)

- **Kind:** submittable. **Naming series:** `ACC-SINV-.YYYY.-` and `ACC-SINV-RET-.YYYY.-` (returns default to the RET series). Title `customer_name`. **Perms:** Accounts Manager rwcsxd, Accounts User rwcs (**no cancel in ERPNext**, kept). 02-selling may add Sales User r.
- **List:** columns title, status, posting_date, due_date, grand_total (right column), customer; standard filters customer, company, posting_date, status; search posting_date, due_date, customer, base_grand_total, outstanding_amount. Saved list filters (v16 `list_filter`): Credit Notes (`is_return = 1`), Drafts, Overdue, This Month, Unpaid. Bulk actions: Delivery Note, Payment (Payment Entry).
- **Indicator colours** (`sales_invoice_list.js`): Draft red, Unpaid orange, Paid green, Return gray, Credit Note Issued gray (shown as green "Settled with Credit Note" when `outstanding_amount = 0`), Overdue red, Partly Paid yellow, Internal Transfer darkgrey, Cancelled red.
- **Connections** (`sales_invoice_dashboard.py`): Payment → Payment Entry, Journal Entry (Payment Request, Invoice Discounting, Dunning dropped); Reference → Timesheet, Delivery Note, Sales Order; Returns → Sales Invoice (`return_against`). Subscription/Auto Repeat and Internal Transfers dropped.

Header fields (ERPNext names; `→` = FK). Grouped like the ERPNext tabs; read-only computed fields marked ro.

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| naming_series | text | ✔ | `ACC-SINV-.YYYY.-` | |
| customer → customer_id / customer_name / tax_id | | ✔ | | |
| company | company_id | ✔ | | |
| posting_date / posting_time / set_posting_time | date / time / bool | ✔ | Today / now / false | |
| due_date | date | ✔ on submit | `get_due_date` | no_copy; "Due Date cannot be before Posting Date" |
| is_return / return_against → sales_invoice_id | bool / uuid | | false | no_copy |
| update_outstanding_for_self | bool | | false (JSON has no default) | only when return_against; forced true when the return exceeds the original's outstanding; no_copy (§3.4) |
| update_billed_amount_in_sales_order | bool | | false | returns |
| update_billed_amount_in_delivery_note | bool | | true | returns |
| is_debit_note | bool | | false | hidden when is_return |
| po_no / po_date | text / date | | | |
| project_id / cost_center_id | uuid | | | cost_center allow_on_submit |
| customer_address_id, address_display, contact_person_id, contact_display, contact_mobile, contact_email, shipping_address_name_id, shipping_address, dispatch_address_name_id, company_address_id, company_address_display, territory_id | | | from party | 00-setup §2.19–2.20 |
| currency / conversion_rate | text / numeric | ✔ | party billing currency or company / 1 | |
| selling_price_list_id / price_list_currency / plc_conversion_rate / ignore_pricing_rule | | ✔ (price list) | Standard Selling | |
| set_warehouse_id / update_stock | uuid / bool | | null / false | update_stock hidden when any row has `dn_detail` |
| items | child | ✔ | | |
| timesheets / total_billing_hours / total_billing_amount | child / numeric | | | from 06-projects |
| total_qty, base_total, base_net_total, total, net_total, total_net_weight | numeric ro | | | §3.11 |
| tax_category_id / taxes_and_charges_id / taxes | | | Tax Rule → default template | |
| base_total_taxes_and_charges / total_taxes_and_charges | ro | | | |
| apply_discount_on | text check `Grand Total\|Net Total` | | `Grand Total` | |
| additional_discount_percentage / discount_amount / base_discount_amount | numeric | | | |
| base_grand_total, base_rounding_adjustment, base_rounded_total, base_in_words, grand_total, rounding_adjustment, rounded_total, in_words | ro | | | |
| disable_rounded_total | bool | | false (Global Defaults) | |
| total_advance / outstanding_amount | ro | | | |
| allocate_advances_automatically / only_include_allocated_payments / advances | bool / bool / child | | false / false | §3.8 |
| payment_terms_template_id / payment_schedule | uuid / child | | party → group → company | hidden when is_return |
| ignore_default_payment_terms_template | bool | | false | |
| write_off_amount, base_write_off_amount, write_off_outstanding_amount_automatically, write_off_account_id, write_off_cost_center_id | | | | hidden; POS-only in v16 (§9) |
| tc_name_id / terms | | | company default selling terms | |
| letter_head_id, group_same_items, select_print_heading_id, language | | | | |
| debit_to → account | uuid | ✔ | `get_party_account('Customer')` | "Please ensure Debit To account is a Receivable account" (Balance Sheet + Receivable) |
| party_account_currency | text ro | | company currency | |
| is_opening | text check | | `No` | hidden (§9) |
| against_income_account | text ro | | | comma list of income accounts |
| remarks | text | | "No Remarks" | |
| sales_partner_id / amount_eligible_for_commission / commission_rate / total_commission / sales_team | | | | 02-selling |
| status | text | | `Draft` | §5 |
| additional_discount_account_id, is_cash_or_non_trade_discount, use_company_roundoff_cost_center | | | null / false / false | hidden; discount accounting off |
| is_pos, pos_profile, payments, paid_amount, change_amount, loyalty_*, inter_company_*, represents_company, is_internal_customer, is_consolidated, is_discounted, auto_repeat, subscription, dimensions | — | | | not built |

`sales_invoice_item`: `item_id`, `item_name` ✔, `description`, `item_group_id`, `brand_id`, `image`, `qty`, `stock_uom_id`, `uom_id` ✔, `conversion_factor` ✔, `stock_qty`, `price_list_rate`, `base_price_list_rate`, `margin_type`, `margin_rate_or_amount`, `rate_with_margin`, `base_rate_with_margin`, `discount_percentage`, `discount_amount`, `distributed_discount_amount`, `rate` ✔, `amount`, `base_rate`, `base_amount`, `net_rate`, `net_amount`, `base_net_rate`, `base_net_amount`, `stock_uom_rate`, `item_tax_template_id`, `item_tax_rate` (jsonb), `income_account_id` ✔, `expense_account_id`, `discount_account_id` (hidden), `cost_center_id` ✔ (default company cost center), `project_id`, `warehouse_id`, `target_warehouse` (dropped), `batch_id`/`serial_and_batch_bundle_id`/`serial_no` (04-stock), `actual_qty`, `delivered_qty`, `incoming_rate`, `sales_order_id`, `so_detail`, `delivery_note_id`, `dn_detail`, `purchase_order_id` (drop-ship, dropped), `asset_id` (07/10 assets), `weight_per_unit`, `total_weight`, `weight_uom`, `is_free_item` (no pricing rules → always false), `grant_commission`, `allow_zero_valuation_rate`, `page_break`.

Other children: `sales_taxes_and_charges` (§2.11), `item_wise_tax_detail` (v16 child: `item_row`, `tax_row`, `rate`, `amount`, `taxable_amount`; replaces the old `item_wise_tax_detail` JSON on tax rows; written by the calc pipeline on save), `sales_invoice_advance` (`reference_type`, `reference_name`/`reference_id`, `remarks`, `reference_row`, `advance_amount`, `allocated_amount`, `exchange_gain_loss` 0, `ref_exchange_rate` 1, `difference_posting_date`), `sales_invoice_timesheet` (`time_sheet_id`, `timesheet_detail`, `activity_type_id`, `description`, `from_time`, `to_time`, `billing_hours`, `billing_amount`, `project_name`), `sales_invoice_payment_schedule` (§2.7), `sales_team` (02), `packed_item` (02/04).

Validations on validate / submit / cancel: §3.1–3.4.

### 2.19 Purchase Invoice → `purchase_invoice` + children (P6; flows in 03-buying)

- **Kind:** submittable. **Naming series:** `ACC-PINV-.YYYY.-`, `ACC-PINV-RET-.YYYY.-`. Title `supplier_name`. **Perms:** Accounts User rwcsx, Accounts Manager rwcsxd, Purchase User r, Auditor r.
- **List:** columns title, status, posting_date, due_date, bill_no, grand_total, supplier; standard filters supplier, company, posting_date, bill_no, status; search posting_date, supplier, bill_no, base_grand_total, outstanding_amount. Indicators (`purchase_invoice_list.js`): Debit Note Issued gray; `on_hold` with outstanding > 0 → "On Hold" darkgrey (no release date) / "Temporarily on Hold" darkgrey (future release date); Unpaid orange, Paid green, Return gray, Overdue red, Partly Paid yellow, Internal Transfer darkgrey. Bulk action: Purchase Receipt.
- **Connections** (`purchase_invoice_dashboard.py`): Payment → Payment Entry, Journal Entry; Reference → Purchase Order, Purchase Receipt, Asset, Landed Cost Voucher; Returns → Purchase Invoice.

Header = Sales Invoice header with supplier-side names, plus/minus:

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| supplier → supplier_id / supplier_name / tax_id | | ✔ | | blocked supplier (hold_type All/Invoices) rejects save |
| bill_no / bill_date | text / date | | | `check_supplier_invoice_uniqueness` (default off) → "Supplier Invoice No exists in Purchase Invoice {0}" within the FY; remarks "Against Supplier Invoice {0} dated {1}" |
| due_date | date | | `get_due_date(bill_date or posting_date)` | "Due Date cannot be before Supplier Invoice Date" |
| is_paid / mode_of_payment_id / cash_bank_account_id / paid_amount / base_paid_amount | | | false | "Cash or Bank Account is mandatory for making payment entry" |
| on_hold / release_date / hold_comment | bool / date / text | | false | allow_on_submit; "Purchase Invoice can be held after submitting.", "Return Purchase Invoice cannot be held.", "Release date must be in the future", "Purchase Invoice without any outstanding amount cannot be held." |
| update_billed_amount_in_purchase_order / _in_purchase_receipt | bool | | false / true | returns |
| buying_price_list_id, price_list_currency, plc_conversion_rate | | | Standard Buying | |
| supplier_warehouse_id, set_warehouse_id, rejected_warehouse_id, update_stock | | | false | |
| taxes_and_charges_added / taxes_and_charges_deducted (+ base_) | ro | | | |
| write_off_amount, base_write_off_amount, write_off_account_id, write_off_cost_center_id | | | | **visible** (PI write-off is not POS-gated); "Please enter Write Off Account", "Please enter a valid Write Off Account" (P&L ledger of the company), "Please enter a valid Write Off Cost Center" |
| credit_to → account | uuid | ✔ | `get_party_account('Supplier')` | must be Balance Sheet + Payable ("Please ensure {0} account is a Balance Sheet account…" / "…{1} is a Payable account…") |
| per_received | numeric ro | | | |
| tax_withholding_category_id / apply_tds | | | supplier's / false | P7 basic |

`purchase_invoice_item` = SI item fields with: `received_qty`, `qty` ✔, `rejected_qty`, `expense_account_id` (required unless derived, §4.3), `item_tax_amount` (hidden; valuation tax share), `valuation_rate`, `landed_cost_voucher_amount`, `purchase_order_id`/`po_detail`, `purchase_receipt_id`/`pr_detail`, `is_fixed_asset`, `asset_location`, `asset_category_id` (10-assets), `rejected_warehouse_id`, `from_warehouse_id` (dropped: internal transfer), `deferred_*` dropped. Children `purchase_taxes_and_charges`, `item_wise_tax_detail`, `purchase_invoice_advance` (same shape as SI Advance), `purchase_invoice_payment_schedule`.

### 2.20 Bank → `bank`; Bank Account Type / Subtype; Bank Account → `bank_account` (P7)

- **Bank** (org-level): naming `field:bank_name`; `bank_name` ✔ unique, `swift_number` unique, `website`; child `bank_transaction_mapping` (CSV column map: `bank_transaction_field`, `file_field`) — reused by our CSV import (§3.12). Perms: System Manager rwcd; Accounts Manager / Accounts User have select-only rows in ERPNext → we grant Accounts Manager rwcd, Accounts User r (§9).
- **Bank Account Type** / **Bank Account Subtype**: single `account_type` / `account_subtype` text unique; perms System/Accounts Manager/Accounts User rwcd.
- **Bank Account**: naming `"<account_name> - <bank>"`. Perms Accounts Manager rwcd, Accounts User rwcd (+ read for Sales/Purchase roles).

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| account_name | text | ✔ | | |
| account → account_id | uuid | ✔ if company account | | ledger of type Bank/Cash; "'{0}' account is already used by {1}. Use another account." |
| bank → bank_id | uuid | ✔ | | |
| account_type_id / account_subtype_id | uuid | | | |
| is_company_account | bool | | false | "Company is mandatory for company account", "Company Account is mandatory" |
| company_id | uuid | | | |
| party_type / party_id | | | | party bank accounts |
| is_default | bool | | false | setting it clears the other default for the same (party, is_company_account, company) |
| iban, bank_account_no, branch_code | text | | | |
| is_credit_card | bool | | false | |
| disabled | bool | | false | |
| last_integration_date, statement_password, address/contact HTML | — | | | not built |

### 2.21 Bank Transaction → `bank_transaction` + child `bank_transaction_payments` (P7)

- **Kind:** submittable. **Naming series:** `ACC-BTN-.YYYY.-`. Title `bank_account`. Perms: System Manager, Accounts Manager rwcsxd; Accounts User rwcsd (no cancel).
- Fields: `date`, `status` (`''|Pending|Settled|Unreconciled|Reconciled|Cancelled`, default `Pending`), `bank_account_id`, `company_id` (fetched), `currency` ("Transaction currency: {0} cannot be different from Bank Account({1}) currency: {2}"), `deposit`, `withdrawal`, `description`, `reference_number`, `transaction_id` (unique per bank account for dedupe on import), `transaction_type`, `allocated_amount` ro, `unallocated_amount` ro, `party_type`, `party_id`, `bank_party_name`, `bank_party_account_number`, `bank_party_iban`, `included_fee`, `excluded_fee`. Child `payment_entries`: `payment_document` ✔ (`Payment Entry|Journal Entry|Sales Invoice|Purchase Invoice|Bank Transaction`), `payment_entry` ✔ (id), `allocated_amount` ✔, `reconciliation_type` (`Matched|Voucher Created`).
- `allocated_amount = Σ child.allocated_amount`; `unallocated_amount = |withdrawal − deposit| − allocated_amount`; status on submit/update: unallocated > 0 → `Unreconciled`, ≤ 0 → `Reconciled`; cancel → `Cancelled` and clears linked vouchers' `clearance_date`. "{0} {1} is allocated twice in this Bank Transaction". Allocation (`allocate_payment_entries`, §3.12) sets the voucher's `clearance_date` to the transaction date when fully allocated.

### 2.22 Bank Clearance (single tool) → page, no table (P7)

ERPNext single `Bank Clearance` (`account` ✔, `bank_account`, `from_date` ✔, `to_date` ✔, `include_reconciled_entries` false, `include_pos_transactions` false (dropped), grid `payment_entries`: `payment_document`, `payment_entry`, `against_account`, `amount` ("1,000.00 Dr"), `posting_date`, `cheque_number`, `cheque_date`, `clearance_date`). We implement it as a client page over `app.get_payment_entries_for_bank_clearance(account_id, from, to, include_reconciled)` (PE + JE rows hitting the account, `clearance_date is null` unless include_reconciled) and `app.update_clearance_date(rows jsonb)`: rows without a document are rejected ("Payment document required for row(s): {0}"), clearance before cheque date rejected ("Clearance date must be after cheque date for row(s): {0}"), nothing to update → "Clearance Date not mentioned"; writes `clearance_date` on PE / JE and a timeline comment "Clearance date changed from {0} to {1} via Bank Clearance Tool". Perms: Accounts User.

### 2.23 Budget → `budget` + child `budget_distribution`; Monthly Distribution → `monthly_distribution` + child `monthly_distribution_percentage` (P7)

- **Budget** (v16 shape: **one account per budget**, multi-year): submittable; naming `BUDGET-.########`; perms Accounts Manager rwcsxd.

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| budget_against | text check `Cost Center\|Project` | ✔ | `Cost Center` | other side nulled (`set_null_value`); "{0} is mandatory" |
| company_id | uuid | ✔ | | |
| cost_center_id / project_id | uuid | one ✔ | | |
| account_id | uuid | ✔ | | ledger, same company, `report_type = Profit and Loss` ("Budget cannot be assigned against Group Account {0}", "Account {0} does not belong to company {1}", "Budget cannot be assigned against {0}, as its Root Type is not of Income or Expense") |
| budget_amount | numeric | ✔ | | > 0 ("Budget Amount can not be {0}.") |
| from_fiscal_year_id / to_fiscal_year_id | uuid | ✔ | | "From Fiscal Year cannot be greater than To Fiscal Year"; FY must apply to the company; `budget_start_date`/`budget_end_date` derived |
| distribute_equally | bool | | true | |
| distribution_frequency | text check `Monthly\|Quarterly\|Half-Yearly\|Yearly` | ✔ | `Monthly` | |
| budget_distribution | child (`start_date`, `end_date`, `amount` ✔, `percent` ✔) | | regenerated | totals must equal budget_amount / 100% |
| applicable_on_material_request / _purchase_order / _booking_actual_expenses | bool | | false / false / false → **forced true** when all off (`validate_applicable_for`) | MR requires PO + actual; PO requires actual |
| action_if_annual_budget_exceeded(_on_mr/_on_po) | text check `Stop\|Warn\|Ignore` | | `Stop` | |
| action_if_accumulated_monthly_budget_exceeded(_on_mr/_on_po) | text check | | `Warn` | |
| applicable_on_cumulative_expense + two actions | | | false / null | not built |
| revision_of | uuid | | | `revise_budget` action (copy + amend) |

  Validations: duplicate ("Another Budget record '{0}' already exists against {1} '{2}' and account '{3}' with overlapping fiscal years."), `validate_existing_expenses` ("Spending for Account {0} ({1}) between {2} and {3} has already exceeded the new allocated budget. Spent: {4}, Budget: {5}").
- **Monthly Distribution**: naming `field:distribution_id`; `distribution_id` ✔ unique, `fiscal_year_id`, child `percentages` (`month` text, `percentage_allocation` numeric; 12 rows seeded `January…December` at 8.333 each by `get_months`); "Percentage Allocation should be equal to 100%". Perms Accounts Manager rwcd. In v16 it is no longer linked from Budget (distribution is inline); it is still used by Budget Variance Report filters and Sales Person/Territory targets (02-selling).

### 2.24 Ledger tables (P3) — defined in 03-posting-engine

`gl_entry`, `payment_ledger_entry` as in 03-posting-engine §Ledger tables, including these columns required by the v16 recipes in §4 (added to 03-posting-engine): `gl_entry.fiscal_year_id` (exists), `transaction_currency`, `transaction_exchange_rate`, `debit_in_transaction_currency`, `credit_in_transaction_currency` (kept for parity, equal to company values), `advance_voucher_type`, `advance_voucher_id` (orders a PE advance was booked for), `is_system_generated`; `payment_ledger_entry.voucher_no text`, `against_voucher_no text`, `advance_voucher_type/id`, `amount_in_account_currency` (exists). No `finance_book`, accounting dimensions or `reporting_currency` columns.

### 2.25 Payment Reconciliation (tool page, P3 basic)

Non-persisted tool (ERPNext single `Payment Reconciliation` with `invoices`, `payments`, `allocation` grids). Filters: `company` ✔, `party_type` ✔, `party` ✔, `receivable_payable_account` ✔ (party account), `from_invoice_date`, `to_invoice_date`, `from_payment_date`, `to_payment_date`, `minimum_invoice_amount`, `maximum_invoice_amount`, `minimum_payment_amount`, `maximum_payment_amount`, `invoice_limit` 50, `payment_limit` 50, `cost_center`. Behaviour in §3.8.

---

## 3. Document flows & mappers

All mappers are `app.map_doc(source_doctype, source_id, target_doctype)` (PLAN §4) returning a draft payload (not saved); the form opens pre-filled and runs the calc pipeline (§3.11). Server Actions save through `app.save_doc` and submit through `app.submit_doc`.

```
Sales Order ─┬─► Sales Invoice ◄── Delivery Note        Timesheet ──► Sales Invoice
             │        │  ├─► Delivery Note (when not update_stock)
             │        │  ├─► Sales Invoice (return / credit note)
             │        │  └─► Payment Entry ◄──┐
Purchase Order ─► Purchase Invoice ◄── Purchase Receipt│
                      │  ├─► Purchase Invoice (return / debit note)
                      │  └─► Payment Entry ──┘     Journal Entry ─► Journal Entry (reverse)
Sales/Purchase Order ─► Payment Entry (advance)      Bank Transaction ─► Payment Entry / Journal Entry
```

### 3.1 Into Sales Invoice

| Source (owner) | ERPNext mapper | What is copied | Notes |
|---|---|---|---|
| Sales Order (02-selling) | `selling/doctype/sales_order/sales_order.py: make_sales_invoice` | header party/address/currency/price list/taxes/terms/payment terms (when `automatically_fetch_payment_terms`), items with `qty = qty − billed (amount-based: (amount − billed_amt)/rate)`, `sales_order`, `so_detail`, `cost_center`, `income_account` | skips fully billed rows; `ignore_pricing_rule` copied |
| Delivery Note (02-selling / 04-stock) | `stock/doctype/delivery_note/delivery_note.py: make_sales_invoice` | as above + `delivery_note`, `dn_detail`, `qty = qty − billed − returned` | `update_stock` stays 0 and is hidden (rows carry `dn_detail`) |
| Timesheet (06-projects) | `projects/doctype/timesheet/timesheet.py: make_sales_invoice` | one `timesheets` row per billable time log; one item (`item_code` arg) with `qty = billing_hours`, `rate = billing_amount / hours` | P9 |

Defaults on new SI (`set_missing_values` + `party.get_party_details`): `debit_to = get_party_account('Customer', customer, company)` (§3.5), `due_date = get_due_date(posting_date, 'Customer', customer, company, payment_terms_template)`, `currency` = customer `default_currency` or company currency, `selling_price_list` = customer → customer group → Selling Settings default (`Standard Selling`), `taxes_and_charges` = Tax Rule match → template for the address tax category → company `is_default` template (`TaxService.set_taxes`), `payment_terms_template` = customer → customer group → company (`get_payment_terms_template`), `tc_name` = company `default_selling_terms`, `letter_head` = company default, `cost_center` from company only when set on items.

Validate (`sales_invoice.py: validate`, in order, skipping POS/loyalty/deferred/inter-company): `validate_date_with_fiscal_year`; `validate_against_voucher_outstanding` (returns, §3.4); taxes/totals (§3.11); `base_grand_total ≥ 0` unless return ("Grand Total cannot be negative" family); `validate_return` (§3.4); payment schedule (§3.9); `PartyValidator` (party frozen/disabled: "{0} {1} is frozen"/"{0} {1} is disabled"); advance rows must reference PE/JE; `so_dn_required` (Selling Settings `so_required`/`dn_required`, customer override fields); `validate_proj_cust`; `validate_with_previous_doc` (SO/DN customer, company, project, currency; item code, UOM, conversion factor must match); `maintain_same_sales_rate` (Selling Settings, default off); `validate_debit_to_acc`; `validate_debit_note_with_update_stock`; `clear_unallocated_advances`; `validate_item_cost_centers` (company match); `validate_income_account` (ledger, company, not a group); with `update_stock`: warehouse required for stock items, cannot update stock against DN-linked rows; `set_against_income_account`; returns cannot be created directly for timesheet invoices; `validate_delivery_note_rows_billed_by_invoice`; `validate_closed_delivery_notes`; `validate_multiple_billing` (over-billing vs SO/DN with `over_billing_allowance`, bypass role `role_allowed_to_over_bill`); `allow_write_off_only_on_pos` (clears `write_off_amount`/`write_off_account` on non-POS); `validate_write_off_account` default from company; credit limit pre-check (§3.5).

On submit: `validate_approving_authority` (00-setup §2.10 Authorization Rule); `check_prev_docstatus` (linked SO/DN must be submitted); status updater on SO/DN (03-posting-engine §Status Updater; returns bypass it unless `update_billed_amount_in_sales_order`); billing status in DN; `update_stock` → SLE (04-stock); GL + PLE (§4.3); credit limit (§3.5) and overdue-billing threshold (off: `enable_overdue_billing_threshold = 0`); advances reconciliation (§3.8); timesheets billed (06-projects); `update_company_current_month_sales` (00-setup company caches). On cancel: §4.6.

Out of SI: `make_delivery_note` (`sales_invoice/mapper.py`, rows not yet delivered: `qty − delivered_qty`), `make_sales_return` (§3.4), Payment Entry (§3.3). Dropped: inter-company PI, Invoice Discounting, Dunning, Maintenance Schedule.

### 3.2 Into Purchase Invoice

| Source (owner) | ERPNext mapper | Copied |
|---|---|---|
| Purchase Order (03-buying) | `buying/doctype/purchase_order/purchase_order.py: make_purchase_invoice` | party, currency, price list, taxes, terms; items `qty = qty − billed`, `purchase_order`, `po_detail`, `expense_account` |
| Purchase Receipt (03-buying / 04-stock) | `stock/doctype/purchase_receipt/purchase_receipt.py: make_purchase_invoice` | as above + `purchase_receipt`, `pr_detail`, `qty = received − billed − returned`; `rejected_qty` billed only when Buying Settings `bill_for_rejected_quantity_in_purchase_invoice` |

Defaults: `credit_to = get_party_account('Supplier')`; `due_date = get_due_date(posting_date, 'Supplier', supplier, company, template, bill_date)` (supplier → supplier group template); `buying_price_list` = Buying Settings default (`Standard Buying`).

Validate adds (`purchase_invoice.py: validate`): `is_opening` default `No`; `validate_posting_date_with_po`; `po_required`/`pr_required` (Buying Settings, default No; "Purchase Order Required for item {0}" / "Purchase Receipt Required for item {0}"); `validate_supplier_invoice`; `validate_cash` when `is_paid`; `validate_release_date`; `validate_credit_to_acc`; `check_purchase_order_on_hold_or_close`; `validate_with_previous_doc`; UOM whole-number checks; **expense account derivation** (`services/expense_account.py`, §4.4); `validate_write_off_account` / `_cost_center`; multiple-billing check vs PR/PO (amount-based unless Buying Settings `set_landed_cost_based_on_purchase_invoice_rate`); `validate_purchase_receipt_if_update_stock` (cannot update stock for rows linked to a PR: "Stock Update Not Allowed"); `validate_exchange_rate_with_purchase_receipt` (n/a in single currency); hold checks; TDS (§3.10).

On submit: authority check, prev-docstatus, status updater on PO/PR, `update_against_document_in_jv` (advances), billing status in PR, `update_stock` → SLE, GL + PLE (§4.4), project `total_purchase_cost` (Buying Settings `project_update_frequency = Each Transaction`). `update_outstanding = No` when `is_paid` or `write_off_account` (outstanding then recomputed via PLE).

Out of PI: Payment Entry (§3.3), `make_debit_note` (return, §3.4). Dropped: inter-company SI, Landed Cost Voucher creation (04-stock owns LCV).

### 3.3 Invoice / Order → Payment Entry (`app.get_payment_entry(dt, id, party_amount?, bank_account?, bank_amount?)`)

Port of `payment_entry.py: get_payment_entry` (default path):

1. Permission `Payment Entry: create`; SO/PO with `per_billed ≥ 100 + over_billing_allowance` → "Can only make payment against unbilled {0}".
2. `party_type` = Customer for SI/SO, Supplier for PI/PO; `party_account` = SI `debit_to`, PI `credit_to`, orders `get_party_account(...)`.
3. `payment_type` = `Receive` for SO, for SI with `outstanding > 0`, for PI with `outstanding < 0` (debit note refund); else `Pay` (so a credit note → `Pay`).
4. `grand_total` = `base_rounded_total or base_grand_total` (party account in company currency); `outstanding_amount` = invoice `outstanding_amount`, orders `grand_total − advance_paid`.
5. Bank/cash account = `get_default_bank_cash_account(company, 'Bank', mode_of_payment, bank_account)` then `'Cash'`: the Mode of Payment account for the company, else `companies.default_bank_account_id` / `default_cash_account_id`, else the **only** Bank (Cash) ledger of the company if exactly one exists, else empty; fallback the party's default Bank Account's ledger.
6. `paid_amount = received_amount = |outstanding|` (same currency path).
7. Early payment discount (`apply_early_payment_discount`, payment-term `discount` with `discount_date ≥ reference_date`) — **P7** (§9).
8. New PE: `company`, `cost_center = doc.cost_center`, `posting_date = today`, `reference_date`, `mode_of_payment`, party + contact, `paid_from = party_account if Receive else bank`, `paid_to = party_account if Pay else bank`, account currencies/types, `project` = doc project or first item project, company default Bank Account (`is_company_account and is_default`), party bank account.
9. References: PI on hold → message "{0} is on hold until {1}" and no reference; templates with `allocate_payment_based_on_payment_terms` → one row per unpaid schedule row (`payment_term`, `payment_term_outstanding`); else one row `{reference_doctype, reference_name, bill_no, due_date, total_amount = grand_total, outstanding_amount, allocated_amount = outstanding_amount}`.
10. `setup_party_account_field`, `set_missing_values`, `set_missing_ref_details`, `set_exchange_rate` (1), `set_amounts` (§3.7). Payment Requests are not allocated (out of scope).

The same RPC backs the "Create ▸ Payment" button on SI/PI/SO/PO and the list bulk action "Payment".

### 3.4 Returns (credit / debit notes) — `controllers/sales_and_purchase_return.py`

`app.make_return_doc(doctype, source_id)` (`make_sales_return` on SI, `make_debit_note` on PI, also used by 02/03/04 for DN/PR):

- Header: `is_return = 1`, `return_against = source`, naming series → `…-RET-…`, `ignore_pricing_rule = 1`, `set_warehouse` cleared, SI `is_debit_note = 0`, `select_print_heading` = `Credit Note` (SI) / `Debit Note` (PI) when those headings exist (fixture A15), advances cleared and `allocate_advances_automatically = 0`, `update_outstanding_for_self` left at 0 (no JSON default, no_copy), SI `update_billed_amount_in_delivery_note = 1`, PI `paid_amount` negated and `payment_terms_template` + `payment_schedule` cleared, `discount_amount` negated, `Actual` tax rows' `tax_amount` negated.
- Items: `qty = −(source qty − already returned qty)` (and `stock_qty`, `received_qty`/`rejected_qty` for PI), `so_detail`/`dn_detail`/`po_detail`/`pr_detail` kept, item links to source row (`sales_invoice_item`/`purchase_invoice_item`).
- Calc pipeline re-run (negative totals).

`validate_return` on save: return against a submitted doc of the same party ("Party Mismatch" style messages), `posting_date`/time after the original ("Posting timestamp must be after {0}"), same `conversion_rate`, SI with `update_stock` only if the original updated stock, each returned item exists in the original with `|returned| ≤ original − already returned` (`validate_returned_items` / `validate_quantity`), negative quantities only.

`validate_against_voucher_outstanding` (accounts_controller): when `update_outstanding_for_self = 0` and `|return grand total| >` original outstanding, it **forces** `update_outstanding_for_self = 1` with a message; when 1, it informs that the credit note keeps its own outstanding.

Effect on ledgers (§4.3/§4.4): by default (`update_outstanding_for_self = 0`) the PLE is booked `against_voucher = return_against`, the original's outstanding drops immediately, and the original shows **Credit Note Issued**. When the return amount exceeds the original's outstanding (typically an invoice already paid), the flag is forced to 1 and the credit note becomes a **standalone** negative-outstanding voucher (PLE against itself), settled through Payment Reconciliation or a refund Payment Entry referencing the credit note. A return without `return_against` is always standalone (`test_credit_note`).

### 3.5 Party accounts, due dates, credit limit (`erpnext/accounts/party.py`, `customer.py`)

- `app.get_party_account(party_type, party_id, company_id)`: `party_account` row of the party for the company → row of its Customer/Supplier Group → `companies.default_receivable_account_id` / `default_payable_account_id`; if the party already has GL in a different account currency, the account of that GL wins (`get_party_gle_account`). Errors when nothing resolves: "Please set default {0} in Company {1}" style (`raise_missing_debit_credit_account_error`).
- `app.get_due_date(posting_date, party_type, party_id, company_id, bill_date, template)`: template = given → party `payment_terms` → group `payment_terms` → company `payment_terms`; `get_due_date_from_template` walks terms: `Day(s) after invoice date` → `max(due, base + credit_days)`; `Day(s) after the end of the invoice month` → `max(due, last_day(base) + credit_days)`; `Month(s) after the end of the invoice month` → `max(due, last_day(base + credit_months))`; never before `posting_date`. `validate_due_date`: "Due Date cannot be before {Posting Date|Supplier Invoice Date}"; due date later than the template allows → "Due Date cannot be after {0}" unless the user has `accounts_settings.credit_controller`, which gets "Note: Due Date exceeds allowed {customer|supplier} credit days by {1} day(s)".
- Credit limit (`customer.check_credit_limit`), run on SI submit (and SO/DN in 02-selling, JE debit to customers): limit = `customer_credit_limit` row for the company → customer group row (unless its `bypass_credit_limit_check`) → `companies.credit_limit`; 0 = no check. Outstanding = Σ(debit − credit) of non-cancelled GL for the customer and company + open SO value `base_grand_total × (100 − per_billed)/100` (unless bypass on the customer row) + the current amount. Over the limit → "Credit limit has been crossed for customer {0} ({1}/{2})"; users with `accounts_settings.credit_controller` get a warning instead of an error; others see the list of users holding that role ("Please contact any of the following users to extend the credit limits for {0}: {1}"). Default `credit_controller` is null → nobody can override.

### 3.6 Journal Entry

Voucher types (`journal_entry.json` options, verbatim) and our handling:

| voucher_type | Enabled | Behaviour |
|---|---|---|
| Journal Entry | ✔ | free rows |
| Bank Entry | ✔ | on select with empty rows: first row = default **Bank** account (`get_default_bank_cash_account(company, 'Bank')`); `cheque_no`/`cheque_date` required on submit |
| Cash Entry | ✔ | first row = default **Cash** account |
| Credit Card Entry | ✔ | free rows |
| Debit Note / Credit Note | ✔ | party rows may reference invoices without the outstanding check (`_validate_invoices` skipped) |
| Contra Entry | ✔ | bank ↔ cash |
| Excise Entry | ✔ | kept as plain label |
| Write Off Entry | ✔ | helper "Get Outstanding Invoices" (`get_outstanding_invoices`): for `write_off_based_on = Accounts Receivable` one Cr row per SI with `0 < outstanding ≤ write_off_amount` (party, `reference_type = Sales Invoice`), plus one blank Dr balancing row for the user to set to the write-off account; Payable mirrors with PI |
| Opening Entry | ✔ | forces `is_opening = Yes` (§3.13) |
| Depreciation Entry | system | created by 10-assets jobs only |
| Exchange Gain Or Loss | system | never created (single currency) |
| Inter Company Journal Entry, Asset Disposal, Periodic Accounting Entry, Exchange Rate Revaluation, Deferred Revenue, Deferred Expense | ✘ | rejected by check constraint |

Validations (`journal_entry.py: validate` + `services/reference_validator.py`): opening entries cannot be posted after a Period Closing (n/a); `clearance_date` reset; every row's account belongs to the company (`validate_account_head`); `validate_party` ("Row {0}: Party Type and Party is required for Receivable / Payable account {1}", "Row {0}: Account {1} and Party Type {2} have different account types"); supplier hold; `validate_entries_for_advance` (Customer credit / Supplier debit rows without an invoice reference: alert "Row {0}: Please check 'Is Advance' against Account {1} if this is an advance entry."; order references must be advances; "Row {0}: Advance against Customer must be credit" / "…Supplier must be debit"); `set_amounts_in_company_currency` (rate 1); "Row {0}: Both Debit and Credit values cannot be zero"; "You cannot credit and debit same account at the same time"; against-JE rows (`validate_against_jv`: "You can not enter current voucher in 'Against Journal Entry' column", "Journal Entry {0} does not have account {1} or already matched against other voucher", "Against Journal Entry {0} does not have any unmatched {1} entry", asset accounts may reference only when credited and liabilities only when debited); stock accounts may not be used directly when perpetual inventory is on (`validate_stock_accounts`: "Account: {0} can only be updated via Stock Transactions"); reference validator: SO rows cannot be debit / PO rows cannot be credit ("Row {0}: Debit entry can not be linked with a {1}"), "Row {0}: Invalid reference {1}", invoice party/account must match ("Row {0}: Party / Account does not match with {1} / {2} in {3} {4}"), order party match, order submitted / not fully billed / not closed, "Advance paid against {0} {1} cannot be greater than Grand Total {2}", invoice submitted and "Payment against {0} {1} cannot be greater than Outstanding Amount {2}", PI on hold blocked; `set_against_account` (comma list of opposite parties/accounts); `create_remarks`; "Accounts table cannot be blank."; warning when posting to company advance accounts. `before_submit`: "Total Debit must be equal to Total Credit. The difference is {0}". On submit: cheque info, GL (§4.1), credit limit for customers debited (§3.5).

Helpers: **Make Difference Entry** (`get_balance(difference_account)`: puts `difference` on the last empty row or a new row with the company cost center), **Reverse Journal Entry** (`mapper.make_reverse_journal_entry`: swaps debit↔credit per row keeping references, sets `reversal_of`, copies cheque info for Bank Entry; refuses a reversal of a reversal and a second reversal), **Create ▸ Payment** is not offered on JE. JE created from Bank Transaction: §3.12.

### 3.7 Payment Entry

Payment types and account derivation (`setup_party_account_field` + `set_missing_values`):

| payment_type | party | paid_from | paid_to | references allowed |
|---|---|---|---|---|
| Receive | Customer (or Supplier refund) | party account (`get_party_account`) | bank/cash (MoP → company default) | Customer: Sales Invoice, Sales Order, Journal Entry, Payment Entry; Supplier: Purchase Invoice (negative/debit notes), Purchase Order, Journal Entry, Payment Entry |
| Pay | Supplier (or Customer refund) | bank/cash | party account | same lists |
| Internal Transfer | none (party/references cleared) | bank/cash | bank/cash (must differ) | none |

`validate` order (ported verbatim, skipping multi-currency and separate-advance-account steps): `setup_party_account_field`; `set_missing_values` ("Party Type and Party is mandatory for {0} account" when not IT, party name, contact, party account, account currencies/types/balances); `set_missing_ref_details` (refresh `total_amount`, `outstanding_amount`, `due_date`, `account` of each reference from the latest data); `validate_payment_type`; Internal Transfer account check; party exists; `set_exchange_rate`; `validate_mandatory` (paid_amount, received_amount); `validate_reference_documents` ("Reference Doctype must be one of {0}", party and party account of each reference must equal the PE's ("{0} {1} is associated with {2}, but Party Account is {3}"), reference must be submitted ("{0} {1} must be submitted"), PI on hold blocked); `set_amounts`; `validate_amounts`; `apply_taxes`; `clear_unallocated_reference_document_rows` (rows with `allocated_amount = 0` dropped); `set_title`; `set_remarks`; `validate_duplicate_entry` ("Row #{0}: Duplicate entry in References {1} {2}"); `validate_payment_type_with_outstanding` ("Cannot receive from customer against negative outstanding" / "Cannot pay to Supplier without any negative outstanding"); `validate_allocated_amount` ("Row #{0}: Allocated Amount cannot be greater than outstanding amount.", with precision tolerance — `test_allocation_equal_to_outstanding_at_precision_is_allowed`); `validate_paid_invoices` (invoices already paid since selection); `set_status`. Bank accounts → `reference_no`/`reference_date` required.

Amounts (`set_amounts`):

- `total_allocated_amount = |Σ allocated_amount|`, base = same (rate 1).
- `unallocated_amount` (only with a party): Receive and `base_total_allocated < base_paid + deductions` → `base_paid + deductions − base_total_allocated − included_taxes`; Pay and `base_total_allocated < base_received − deductions` → `base_received − deductions − base_total_allocated − included_taxes`.
- `difference_amount` = Receive: `(base_total_allocated + unallocated) − base_received + included_taxes`; Pay: `base_paid − (base_total_allocated + unallocated) − included_taxes`; IT: `base_paid − base_received − included_taxes`; minus Σ deductions. **Submit requires 0** ("Difference Amount must be zero").
- `set_exchange_gain_loss` (single-currency meaning): `base_paid − base_received − other deductions`; when non-zero and both accounts share a currency it auto-adds (or updates) a deduction row on `companies.bank_charges_account_id` with the company cost center (`test_bank_charges_deduction`: IT 1000 → 990 adds Bank Charges 10). Missing default → "Please set {0} in Company {1} to account for Exchange Gain / Loss" (error on submit).
- Write-off / discount difference: the user adds a deduction row (e.g. Write Off 5 when 95 settles 100 — `test_payment_entry_write_off_difference`); toolbar "Set Exchange Gain / Loss" is renamed **Write Off Difference** and posts `difference_amount` to `companies.write_off_account_id`.
- Advance Taxes and Charges (`taxes` child, basic): `charge_type` `Actual|On Paid Amount|On Previous Row Amount|On Previous Row Total`, `add_deduct_tax`, `included_in_paid_amount`, `account_head`, `rate`, `tax_amount`; computed like §3.11 on `paid_amount`. Used rarely; kept to match the form.

Allocation helper "Get Outstanding Invoices / Orders" (`get_outstanding_reference_documents`): for the party and party account, PLE-based outstanding vouchers (invoices, JEs with party rows, credit notes, negative outstanding for refunds) ordered by due date then posting date, filtered by date/amount range and optional cost center; orders (SO/PO) with `advance_paid < grand_total`; "Allocate Payment Amount" fills `allocated_amount` oldest first up to `paid_amount` (Receive) / `received_amount` (Pay).

On submit: "Difference Amount must be zero"; `update_payment_schedule` (reduce `paid_amount`/`outstanding` on the referenced invoice's schedule rows, by `payment_term` when set, else oldest first); GL + PLE (§4.2); outstanding + status refresh of every reference; SO/PO `advance_paid` + `advance_payment_status` refresh (`set_total_advance_paid`). On cancel: reverse GL/PLE, re-open schedule rows, refresh references, delink from invoices' `advances` rows and from Bank Transactions (`remove_from_bank_transaction`).

### 3.8 Advances, reconciliation and unlinking

Path implemented: `companies.book_advance_payments_in_separate_party_account = false` (default; separate advance accounts out of scope).

- An **advance** is a PE party row with no invoice reference (`unallocated_amount`) or with an order reference (SO/PO → GL/PLE `against_voucher = the PE itself`, `advance_voucher_type/id = order`), or a JE party row with `is_advance = Yes`.
- **Pull into invoice:** "Get Advances Received/Paid" (`set_advances` → `get_advance_entries`): PE/JE advances of the party on the invoice's party account, including order-linked ones for the invoice's `sales_order`/`purchase_order` items, plus unallocated ones unless `only_include_allocated_payments`. Each becomes an `advances` row with `allocated_amount = min(remaining invoice total, advance amount)`. `allocate_advances_automatically = 1` does this on save. "Advance amount cannot be greater than {0} {1}" when Σ allocated exceeds the invoice total. Warning when a PE linked to the invoice's order is not pulled ("Payment Entry {0} is linked against Order {1}, check if it should be pulled as advance in this invoice.").
- **On invoice submit** (`update_against_document_in_jv` → `reconcile_against_document`): for each advance row with `allocated_amount`: PE → its reference rows are updated/split (a new reference row to the invoice for the allocated part, the remainder stays unallocated); JE → the JE row is split (allocated part gets `reference_type/name` = invoice). **GL is not re-posted**; the voucher's PLE rows are rebuilt from its GL map and outstanding of the newly linked invoice is refreshed. PLE posting date follows `companies.reconciliation_takes_effect_on` (`Oldest Of Invoice Or Advance` default).
- **Payment Reconciliation tool** (basic, P3): loads unreconciled invoices (positive PLE outstanding) and payments/credit notes/JEs (negative outstanding) for the party+account, the user allocates (auto "Allocate" pairs oldest first), "Reconcile" runs the same `app.reconcile_against_document(entries jsonb)` for PE/JE rows. Credit/debit notes (return invoices) are reconciled by `reconcile_dr_cr_note`: a **system-generated JE** (`voucher_type = Credit Note` for SI, `Debit Note` for PI, `is_system_generated = true`, posting date today) with two rows on the party account for the allocated amount — for an SI credit note: Cr Debtors `reference = invoice` (reduces its outstanding) and Dr Debtors `reference = credit note` (consumes the note's negative outstanding); PI debit notes mirror it — both with party and the company cost center, remarks "{amount} against {invoice}" / "{amount} from {note}". "{0} has been modified after you pulled it. Please pull it again." when the note's outstanding changed. Cancelling the invoice or the note cancels these JEs (`cancel_system_generated_credit_debit_notes`). Unreconcile (`Unreconcile Payment`) is out (§9).
- **Unlink on invoice cancel** (`accounts_settings.unlink_payment_on_cancellation_of_invoice`, ERPNext default `1`, PLAN §5 keeps it): cancelling an SI/PI removes its references from submitted PEs/JEs (`unlink_ref_doc_from_payment_entries`: PE reference rows deleted → amounts become unallocated, `update_outstanding` re-run; JE rows lose `reference_type/name`), delinks PLE. With the setting 0 the cancel fails with the linked-document error. Return invoices linked to a PE with a negative allocation and more than one reference block cancel: "Please cancel and amend the Payment Entry {0} to unallocate the amount of this Return Invoice before cancelling it." (`check_if_return_invoice_linked_with_payment_entry`).
- **Unlink on order cancel** (`unlink_advance_payment_on_cancelation_of_order = 1`): SO/PO cancel delinks their advances (02/03 call `app.unlink_ref_doc_from_payment_entries`).

### 3.9 Payment Schedule & due date (`accounts/services/payment_schedule.py`)

`validate_invoice_documents_schedule`: returns, `is_paid` PI and opening invoices clear `payment_terms_template` and `payment_schedule`; then:

1. `validate_payment_schedule_dates`: "Row {0}: Due Date in the Payment Terms table cannot be before Posting Date"; "Rows with duplicate due dates in other rows were found: {0}".
2. `set_due_date`: header `due_date = max(schedule.due_date)` when a schedule exists.
3. `set_payment_schedule`: totals to schedule = `rounded_total or grand_total` − `write_off_amount` − `total_advance` (company-currency path). No rows yet: order terms when `automatically_fetch_payment_terms` (default 0) and the linked SO/PO has terms; else template rows (`get_payment_term_details`: `payment_amount = invoice_portion × total / 100`, `due_date` per term rule, `discount_date` when the term has a discount, never before posting date); else one row `{due_date, invoice_portion 100, payment_amount = total}`. Existing rows with `invoice_portion` are re-amounted on every save; rows without portion keep their amount.
4. `validate_payment_schedule_amount`: |Σ payment_amount − total| ≤ 0.1 else "Total Payment Amount in Payment Schedule must be equal to Grand / Rounded Total".
5. `validate_due_date` (§3.5).

### 3.10 Tax Withholding (basic, P7)

Scope: Purchase Invoice only (supplier TDS). When `apply_tds` and the PI has a `tax_withholding_category`: rate row valid on `posting_date`; base = `net_total` (`tax_deduction_basis = Net Total`) or `grand_total` (Gross Total); threshold check: single-transaction base ≥ `single_threshold` or FY cumulative base of the supplier's submitted PIs (+ this one) ≥ `cumulative_threshold`; when crossed the first time the tax is computed on the cumulative base (`tax_on_excess_amount` → only the excess); a `Purchase Taxes and Charges` row `{category: Total, add_deduct_tax: Deduct, charge_type: Actual, account_head: category account for the company, tax_amount}` is added/updated before the calc pipeline; `round_off_tax_amount` rounds to whole units. Deviation: v16's `tax_withholding_entries` ledger, groups, lower deduction certificates, sales-side TCS and JE/PE withholding are not built (§9).

### 3.11 Taxes & totals pipeline (`src/lib/calc/taxes-and-totals.ts` ⇄ SQL `app.calc_taxes_and_totals(doc jsonb)`)

Exact order of `controllers/taxes_and_totals.py: calculate_taxes_and_totals.calculate()` for SI/PI (and SO/DN/PO/PR via 02–04). `flt(x, p)` = round to precision `p` (§9 rounding note). Precisions: currency fields `companies.currency_precision` (default 2 → from Currency `number_format` in ERPNext), rates 2/3, `conversion_factor` 9.

```
_calculate():
  1 validate_conversion_rate: currency == company currency → conversion_rate = 1
  2 calculate_item_values (skipped once discount_amount_applied):
      round item floats; calculate_item_rate:
        price_list_rate = 0 → margin/discount cleared
        rate_with_margin = price_list_rate + margin (Percentage: plr × m/100 ; Amount: m)
        discount_percentage > 0 → discount_amount = rate_with_margin × dp / 100
        calculated_rate = rate_with_margin − discount_amount
        rate = 0 → rate = calculated_rate; rate ≠ calculated → if rate > plr: margin_type Amount = rate − plr, discount cleared
                                                             else discount_amount = plr − rate, discount_percentage = 0, margin cleared
      net_rate = rate
      amount = rate × qty   (return with qty 0 → −rate; debit note with qty 0 → rate; PI billed qty adds rejected_qty when billing rejected)
      net_amount = amount; base_* = flt(x × conversion_rate); item_tax_amount = 0
  3 validate_item_tax_template (pick the template valid for net_rate/tax_category/date from item + item group taxes)
  4 update_item_tax_map: item_tax_rate = get_item_tax_map(doc, item_tax_template)
  5 initialize_taxes: per row validate_taxes_and_charges / validate_inclusive_tax;
      reset tax_amount (except Actual), total, tax_amount_after_discount_amount, net_amount, *_for_current_item
  6 determine_exclusive_rate (only if any included_in_print_rate):
      per item: per tax row slope/intercept (On Net Total: rate/100; Previous Row Amount: rate/100 × prev slope;
      Previous Row Total: rate/100 × prev cumulative slope; On Item Quantity: intercept = rate per qty; Deduct negates)
      net_amount = (amount − Σ intercept × qty) / (1 + Σ slope)  (kept unrounded for tax calc), net_rate = net_amount / qty
  7 calculate_net_total: total, base_total, net_total, base_net_total, total_qty = Σ items
  8 calculate_taxes: actual_tax_dict = {idx: tax_amount} for Actual rows
      for each item, for each tax row:
        rate = item_tax_map[account_head] if present (NOT_APPLICABLE → 0 and no row) else tax.rate
        Actual:              tax = item.net_amount × actual / net_total (last item absorbs remainder)
        On Net Total:        tax = rate/100 × net_amount  (inclusive: × unrounded net)
        On Previous Row Amt: tax = rate/100 × taxes[row_id].tax_amount_for_current_item
        On Previous Row Tot: tax = rate/100 × taxes[row_id].grand_total_for_current_item
        On Item Quantity:    tax = rate × qty
        (round_row_wise_tax = 1 → round per item; default 0)
        tax.tax_amount += tax (non-Actual); tax.tax_amount_after_discount_amount += tax
        effective = 0 if category == Valuation; × −1 if Deduct (buying doctypes)
        grand_total_for_current_item = (i == 0 ? item.net_amount : prev.grand_total_for_current_item) + effective
        item-wise detail row {item, tax, rate, amount (error-diffused base), taxable_amount}
      if apply_discount_on == Grand Total and a discount exists: cumulative totals first pass;
        grand_total_for_distributing_discount = taxes[-1].total (first pass) / grand_total_diff (second pass)
      per row: round tax_amount, tax_amount_after_discount_amount, net_amount; base_* ; total = prev.total (or net_total) + effective
      adjust_rounding_in_item_wise_tax_details: last detail row absorbs ≤ 0.5 (≤ 1 for 0-precision currencies), else error
        "Item Wise Tax Details do not match with Taxes and Charges at the following rows:"
  9 adjust_grand_total_for_inclusive_tax: diff = total + Σ non-inclusive effective tax − taxes[-1].total (− discount);
      |diff| ≤ 5 / 10^precision → grand_total_diff = diff
 10 calculate_totals:
      grand_total = taxes ? taxes[-1].total + grand_total_diff : net_total
      total_taxes_and_charges = grand_total − net_total − grand_total_diff
      selling: base_grand_total = total_taxes ? flt(grand_total × rate) : base_net_total
      buying: taxes_and_charges_added / _deducted (category Total or Valuation and Total), base_grand_total likewise
      set_rounded_total: disable_rounded_total → 0; else rounded_total = round_based_on_smallest_currency_fraction(grand_total),
        rounding_adjustment = rounded_total − grand_total; base_ mirrors
calculate():
  _calculate()
  set_discount_amount: additional_discount_percentage → discount_amount = (grand_total | net_total per apply_discount_on) × pct / 100;
    returns add prior returns' discount; "Additional Discount Amount ({0}) cannot exceed the total before such discount ({1})"
  apply_discount_amount (discount_amount ≠ 0): base_discount_amount; total_for_discount =
      Net Total → net_total ; Grand Total → grand_total_for_distributing_discount − Σ Actual/On Item Quantity tax (and rows based on them);
    per item: distributed = discount × net_amount / total_for_discount; net_amount −= distributed (running rounding fix);
    distributed_discount_amount; net_rate; then discount_amount_applied = true and _calculate() again
  (re-run once if an item tax template was swapped)
  calculate_total_advance (SI/PI): total_advance = Σ advances.allocated_amount; > invoice total → error
  calculate_outstanding_amount:
    return with return_against and not update_outstanding_for_self → outstanding = 0
    else outstanding = (rounded_total or grand_total) − total_advance − write_off_amount − paid_amount   (PI is_paid uses paid_amount)
```

`round_based_on_smallest_currency_fraction(value, currency, precision)` (Frappe): with `currency.smallest_currency_fraction_value` = f > 0 → round to the nearest multiple of f (remainder > f/2 rounds up); f = 0 → round to a whole unit. 00-setup seeds currencies with ERPNext's values (USD 0.01 → `rounding_adjustment` 0 in `test_rounded_total_with_cash_discount`-style cases; currencies with no fraction value round to integers, e.g. INR in `test_sales_invoice_calculation_base_currency`: 1627.05 → rounded 1627.00, adjustment −0.05).

Fixtures (`src/lib/calc/__fixtures__/erpnext-cases.json`) must include at least:

| Case (ERPNext test) | Input | Expected |
|---|---|---|
| `test_sales_invoice_calculation_base_currency` (`test_records.json` SI[2]) | 10 × 50 + 5 × 150; taxes: Actual 100; On Net Total 10%; On Net Total 12%; Prev Row Amount (row 3) 2%; Prev Row Amount (row 3) 1%; Prev Row Total (row 5) 2%; On Net Total 12.5%; Prev Row Total (row 7) −10% | net_total 1250; tax/total: 100/1350, 125/1475, 140/1615, 2.80/1617.80, 1.40/1619.20, 32.38/1651.58, 156.25/1807.83, −180.78/1627.05; grand_total 1627.05 |
| `test_sales_invoice_discount_amount` (SI[3] + Service Tax 10% Prev Row Amount row 8, discount_amount 104.94 on Grand Total) | inclusive prices 62.5 × 10, 190.66 × 5 | net_total 1163.45, total 1578.30, grand_total 1500.00, rounding 0; Discount row −180.33 / after discount −168.54 / total 1516.85 |
| `test_rounding_adjustment` | 1 × 24900, two inclusive On Net Total 14% rows | net_total 19453.12, total_taxes 5446.88, grand_total 24900, rounding_adjustment 0 |
| `test_rounded_total_with_cash_discount` | 1 × 14960.66, no taxes, `is_cash_or_non_trade_discount`, discount 1 | grand_total 14959.66, rounded_total 14960, rounding_adjustment 0.34 |
| `test_gl_entries_without_perpetual_inventory` (PI test_records[0]) | PI 1250 net with the same 8-row tax set (Discount row Deduct) | Creditors Cr 1512.00 (see §4.8) |

`test_rounding_adjustment` proves Frappe rounds half-to-even by default (19453.125 → 19453.12); see §9 Deviation 20 and 03-posting-engine "Rounding".

### 3.12 Banking flows (P7)

- **Bank Transaction import (CSV):** page action on Bank Account / Bank Reconciliation Tool: upload CSV → map columns (pre-filled from `bank.bank_transaction_mapping`) to `date`, `deposit`, `withdrawal`, `description`, `reference_number`, `transaction_id`, `transaction_type`, `bank_party_name`, `bank_party_account_number`, `bank_party_iban`, `currency` → preview → insert + submit Bank Transactions (status `Unreconciled`), skipping rows whose `(bank_account, transaction_id)` exists. Replaces ERPNext's `Bank Statement Import` (Data Import based).
- **Bank Reconciliation Tool** page (`bank_reconciliation_tool.py`): filters `company`, `bank_account`, `bank_statement_from_date`, `bank_statement_to_date`, `bank_statement_closing_balance`; header numbers: opening balance = `get_account_balance(bank_account, from − 1)` = GL balance − uncleared debits + uncleared credits; closing balance (user) vs cleared balance → difference. Grid: unreconciled transactions (`get_bank_transactions`: submitted, `unallocated_amount > 0`, date range). Per transaction: **Match** (`get_linked_payments` → `check_matching` queries: PE/JE/SI-payment/PI vouchers hitting the bank ledger with `clearance_date is null`, ranked by reference_no match, party match, amount match, date proximity within `transfer_match_days` (3)), **Create Voucher** (`create_payment_entry_bts` with party/MoP/project; `create_journal_entry_bts` Bank Entry with second account; internal transfer between two company bank accounts), **Update** (reference number / party). `reconcile_vouchers` appends `payment_entries` rows then `allocate_payment_entries`:
  - remaining = transaction `unallocated_amount`; per voucher allocable = voucher bank GL amount − already allocated on other transactions; 0 → clear and drop row; ≤ remaining → allocate fully and set the voucher `clearance_date` = latest transaction date; > remaining → allocate remaining, no clearance; < 0 → "Voucher {0} is over-allocated by {1}".
  - "Bank Transaction {0} is already fully reconciled".
  - Unreconcile (`unreconcile_transaction`) clears allocations and clearance dates. Auto-reconcile, party matching (`enable_party_matching`, `enable_fuzzy_matching`) and Bank Transaction Rules are out.
- **Bank Clearance** (§2.22): manual clearance dates without statements.

### 3.13 Opening balances via Journal Entry

Opening Invoice Creation Tool is out of scope (03-posting-engine matrix). Openings are entered as JE `voucher_type = Opening Entry` (`is_opening = Yes`), posted on the day before the first fiscal year in use:

- Balance-sheet accounts only — `gl_entry.py`: "{0} {1}: 'Profit and Loss' type account {2} not allowed in Opening Entry".
- Party balances: one row per open invoice/party on Debtors/Creditors with party (and `reference_due_date` for ageing), no invoice reference → each becomes an unallocated party balance usable in Payment Reconciliation / Payment Entry allocation (PLE against the JE itself).
- Offsetting account: `Temporary Opening - ABBR` (standard chart `account_type = Temporary`); stock opening is 04-stock's Stock Reconciliation (`purpose = Opening Stock`) against the same account. After all openings `Temporary Opening` must net to 0; the remainder is moved to `Opening Balance Equity` by a normal JE (help text on the Opening Entry form).
- Rounding differences on opening vouchers use `companies.round_off_for_opening_id` (ERPNext `round_off_for_opening`, account type `Round Off for Opening`), not `round_off_account` (§4.0).
- Reports: Trial Balance shows `is_opening = Yes` rows in the Opening columns regardless of date (`accounts_settings.ignore_is_opening_check_for_reporting = 0`).

---

## 4. Posting rules

Every recipe below is a SQL function `app.<table>_gl_map(id) returns jsonb` (port of the v16 `services/gl_composer.py` of each doctype) called from `app.on_submit__<table>(id)`, which then calls `app.make_gl_entries(map, opts)`. Cancel calls `app.reverse_gl_entries(voucher_type, id)`. TypeScript never writes ledgers (`.cursorrules` §2). All amounts are company currency (`debit = debit_in_account_currency`, `transaction_*` = same).

### 4.0 Engine details beyond 03-posting-engine (`erpnext/accounts/general_ledger.py`, `gl_entry.py`, `utils.py`)

`app.make_gl_entries(entries, {cancel, merge, update_outstanding, adv_adj})`, in ERPNext's order:

1. **Budget** (non-legacy `BudgetValidation`, `use_legacy_budget_controller = 0`): §4.7.
2. `validate_accounting_period` — n/a (Accounting Period out of scope); `validate_disabled_accounts` ("Cannot create accounting entries against disabled accounts: {0}").
3. `process_gl_map`: (a) cost center allocation split (§2.4); (b) `merge_similar_entries` when `merge` — merge key = `account, cost_center, party_type, party, voucher_detail_no, against_voucher_type, against_voucher, project, voucher_no, advance_voucher_type, advance_voucher_no` (+ dimensions, finance book: n/a); debits and credits are netted per key; rows that net to zero are dropped; (c) `toggle_debit_credit_if_negative` — negative debit becomes credit and vice versa (per amount column).
4. Fewer than two rows → "Incorrect number of General Ledger Entries found. You might have selected a wrong Account in the transaction."
5. `create_payment_ledger_entry` (before GL insert): for each row on an account of type Receivable/Payable with a party: `amount = debit − credit` (Receivable) or `credit − debit` (Payable); `against_voucher_type/id` = the row's `against_voucher` or **the voucher itself** when empty; `due_date` = row due date; `advance_voucher_*` copied (Advance Payment Ledger Entry is folded into PLE columns, §9). Then `update_voucher_outstanding` for every distinct against-voucher unless `update_outstanding = 'No'`.
6. `process_debit_credit_difference`: `diff = Σdebit − Σcredit` rounded to currency precision; allowance = `5 / 10^precision` for Journal Entry and Payment Entry, `0.5` otherwise; `|diff| > allowance` → "Debit and Credit not equal for {voucher_type} #{voucher_no}. Difference is {diff}."; else if `|diff| ≥ 1 / 10^precision` → append a **round-off row**: account `companies.round_off_account_id`, falling back to `companies.default_expense_account_id` (`get_round_off_account_and_cost_center`); cost center = the voucher's header `cost_center` when the doctype has one and it is set (and the invoice field `use_company_roundoff_cost_center = 0`), else `companies.round_off_cost_center_id`; neither found → "Please mention 'Round Off Account' in Company: {1}" / "'Round Off Cost Center'"; opening vouchers use `round_off_for_opening`; existing round-off row of the same voucher is adjusted instead of adding another.
7. `check_freezing_date`: `posting_date ≤ companies.accounts_frozen_till_date` → "You are not authorized to add or update entries before {0}" unless the user holds `role_allowed_for_frozen_entries`.
8. `validate_against_pcv` — n/a. Insert each `gl_entry` with `gl_entry.py` validations: mandatory fields (`account, voucher_type, voucher_no, company, posting_date`), "{0} {1}: Customer is required against Receivable account {2}" / Supplier for Payable, "{0} {1}: Either debit or credit amount is required for {2}", "{0} {1}: Cost Center is required for 'Profit and Loss' account {2}." (we default the company cost center earlier, as ERPNext does in `get_gl_dict`), P&L in opening entry rejected, "{0} {1}: Account {2} is inactive" (group/disabled), "…does not belong to Company {3}" for account and cost center, party frozen/disabled, "{0} {1}: Accounting Entry for {2} can only be made in currency: {3}", fiscal year (`fiscal_year_id` from `app.get_fiscal_year(posting_date, company)` — 00-setup §2.23), `validate_balance_type` ("Balance for Account {0} must always be {1}"), frozen account ("Account {0} is frozen" / "Not authorized to edit frozen Account {0}"), and for non-party JE references `update_outstanding_amt` ("Against Journal Entry {0} is already adjusted against some other voucher", "Outstanding for {0} cannot be less than zero ({1})").

`app.reverse_gl_entries(voucher_type, id)` (`make_reverse_gl_entries`, immutable ledger off): (1) PLE: insert negated copies flagged `delinked = true` and set `delinked = true` on the originals (ERPNext `delink_original_entry`); refresh outstanding of every against-voucher; (2) set `is_cancelled = true` on the original GL rows; (3) insert swapped rows (`debit ↔ credit`, `remarks = "On cancellation of " || voucher_no`, `is_cancelled = true`, same posting date). Reports filter `is_cancelled = false`. Budget is re-checked on reversal only for the "actual expense" side (no-op in practice).

`app.refresh_outstanding(voucher_type, id, account_id, party_type, party_id)` (`update_voucher_outstanding`): for SO/PO → `set_total_advance_paid` (Σ PLE with `advance_voucher` = order) and `advance_payment_status` (`Not Requested|Requested|Partially Paid|Fully Paid`, 02/03); for SI/PI/JE party rows → `outstanding_amount = Σ amount_in_account_currency` of non-delinked PLE against it (PI stores the Payable sign as positive), then `app.set_invoice_status(voucher_type, id)` (§5). Outstanding is never computed from GL.

### 4.1 Journal Entry

`JournalEntryGLComposer.compose`: one GL row per account row with `debit` or `credit` (merge only when `accounts_settings.merge_similar_account_heads`, default 0): `account, party_type, party, due_date (header), against = against_account, debit/credit (+ in_account_currency), against_voucher_type/against_voucher = reference_type/reference_name, voucher_detail_no = reference_detail_no, cost_center, project, remarks = user_remark + header remark`. Rows referencing an order (`reference_type in (Sales Order, Purchase Order)`) post `against_voucher = the JE itself` and `advance_voucher_type/id = the order`. `update_outstanding = 'Yes'`.

Validation of the referenced invoice's outstanding happens before posting (§3.6); after posting, `refresh_outstanding` of each invoice reference drops it (`test_payment`: JE crediting Debtors 400 against an SI with outstanding 562 leaves 162; cancelling restores 562). Cancel → reversal + unlink of the JE from invoices' advance rows (`unlink_advance_entry_reference`).

### 4.2 Payment Entry

`PaymentEntryGLComposer`, posted with `make_gl_entries(gl_entries, cancel, adv_adj)` and the default `merge_entries = True` (party rows differ by `against_voucher`, so they stay separate):

| Row | Receive | Pay | Internal Transfer |
|---|---|---|---|
| Party, one per reference with `allocated_amount` | **Cr** `paid_from` (Debtors) `allocated_amount`, `against_voucher = reference` (SI/PI/JE); for SO/PO references `against_voucher = PE`, `advance_voucher = order`; negative allocation (credit note / refund) flips the side | **Dr** `paid_to` (Creditors) likewise | — |
| Party, unallocated | Cr party account `unallocated_amount`, no against voucher (→ PLE against the PE: advance) | Dr party account | — |
| Bank / cash | Dr `paid_to` `base_received_amount` | Cr `paid_from` `base_paid_amount` | Cr `paid_from` `base_paid_amount`; Dr `paid_to` `base_received_amount` |
| Deductions | Dr `account` `amount` (negative → Cr), row `cost_center` | same | same |
| Taxes (`taxes` child) | Cr/Dr `account_head` per `add_deduct_tax`; `included_in_paid_amount` reduces the bank row | mirrored | — |

Party rows carry `party_type, party, cost_center (header), project, due_date (reference due date), remarks`. Bank rows carry `against = party`. PLE: one negative row per invoice reference (Receivable `amount = debit − credit < 0`), one row against the PE for unallocated/order amounts.

### 4.3 Sales Invoice (`sales_invoice/services/gl_composer.py`)

Order of composition (POS, loyalty, inter-company, deferred, fixed-asset disposal and SDBNB blocks skipped — §9):

1. **Customer** — Dr `debit_to`, party Customer, `due_date`, amount = `base_rounded_total` if `rounding_adjustment` and not `disable_rounded_total` else `base_grand_total`; `against = against_income_account`; `against_voucher` = the SI, **except** a return with `return_against` and `update_outstanding_for_self = 0` → `return_against`; header `cost_center`, `project`. Returns produce negative amounts → toggled to Cr.
2. **Taxes** — per tax row with `base_tax_amount_after_discount_amount ≠ 0`: Cr `account_head`, row `cost_center`, `against = customer`. (With Selling Settings `enable_discount_accounting` it would use `base_tax_amount` — default 0, not exposed.)
3. **Items** — per item with `base_net_amount ≠ 0`: Cr `income_account`, item `cost_center` and `project`, `against = customer`. With `update_stock` and perpetual inventory: stock controller rows per item — Cr warehouse inventory account (`default_inventory_account` / warehouse account) and Dr item `expense_account` (default `Cost of Goods Sold`) at `stock_value_difference` from the SLE (04-stock).
4. **Precision loss** — `base_net_total − flt(net_total × conversion_rate)` (non-zero only with foreign document currency) → Cr/Dr `round_off_account` (round-off cost center).
5. **Write off** — `make_write_off_gl_entry` runs only when `is_pos` ("write off entries, applicable if only pos") → never for us.
6. **Rounding adjustment** — `base_rounding_adjustment ≠ 0` and not `disable_rounded_total` → Cr `round_off_account` `base_rounding_adjustment` (negative toggles to Dr), cost center = SI `cost_center` when `use_company_roundoff_cost_center = 0` and set, else `round_off_cost_center`; opening SI → `round_off_for_opening` (error if missing).

`make_gl_entries(gl, update_outstanding = 'Yes', merge_entries = False)`; afterwards if `update_outstanding = 'No'` (only POS/write-off/loyalty) → explicit `refresh_outstanding(return_against or self)`. Exchange gain/loss JE: n/a.

### 4.4 Purchase Invoice (`purchase_invoice/services/{gl_composer,expense_account}.py`)

**Expense account per item** (`ExpenseAccountService.set_expense_account`), with perpetual inventory (`companies.enable_perpetual_inventory`, true by default, B2):

| Item | Condition | `expense_account` |
|---|---|---|
| stock item | `update_stock` and warehouse | warehouse inventory account (`Stock In Hand`) |
| stock item | not `update_stock`, row has a Purchase Receipt (PR booked SRBNB) | `stock_received_but_not_billed` ("Row {0}: Expense Head changed to {1} because expense is booked against this account in Purchase Receipt {2}") |
| stock item | not `update_stock`, no PR | `stock_received_but_not_billed` ("Row {0}: Expense Head changed to {1} as no Purchase Receipt is created against Item {2}. This is normally handled by creating a Purchase Receipt…") |
| fixed asset item | PR booked ARBNB | `asset_received_but_not_billed` |
| fixed asset item | no PR | asset category CWIP account when CWIP enabled, else the category fixed asset account (10-assets) |
| non-stock item / perpetual off / opening | — | user/default `expense_account` (item default → item group → company `default_expense_account`); missing → "Expense account is mandatory for item {0}" |

Composition order:

1. **Supplier** — Cr `credit_to`, party Supplier, `due_date`, `base_rounded_total` (or `base_grand_total`), `against_voucher` = self (or `return_against` for returns with `update_outstanding_for_self = 0`), header cost center, project.
2. **Items** — `update_stock` + perpetual stock/asset item: Dr `expense_account` (inventory) `warehouse_debit_amount` = SLE `stock_value_difference` (= `valuation_rate × stock_qty`, valuation includes valuation taxes and LCV); differences between `base_net_amount + item_tax_amount` and the stock value go to `stock_adjustment_account` / `default_expense_account` (variance rows); LCV amounts credited to the LCV expense accounts (04-stock). Otherwise: Dr `expense_account` `base_net_amount` (SRBNB for PR-linked stock rows — clears the PR's Cr SRBNB), item cost center/project.
3. **Valuation taxes with a PR** — for PR-linked stock rows the PR already capitalised valuation taxes: Dr SRBNB `item_tax_amount` and Cr the valuation tax account (pro-rata split of `negative_expense_to_be_booked`).
4. **Precision loss** — Cr/Dr round off (foreign document currency only).
5. **Taxes** — category `Total` / `Valuation and Total`: Dr (`Add`) / Cr (`Deduct`) `account_head` `base_tax_amount_after_discount_amount`, row cost center. Category `Valuation` with `update_stock`: Cr `account_head` for the capitalised amount (the debit is inside the stock row). TDS rows (§3.10) are `Deduct` Total rows → Cr TDS payable.
6. **is_paid** — Dr `credit_to` (party, against self) / Cr `cash_bank_account` `base_paid_amount`.
7. **Write off** — `write_off_amount` with `write_off_account`: Dr `credit_to` (party) / Cr `write_off_account` `base_write_off_amount`, cost center = PI `cost_center` or `write_off_cost_center`.
8. **Rounding adjustment** — Dr `round_off_account` `base_rounding_adjustment` (negative → Cr).

`make_gl_entries(gl, update_outstanding = 'No' if is_paid or write_off_account else 'Yes', merge_entries = False)`, then `update_supplier_outstanding` when 'No'.

### 4.5 Outstanding & status refresh

| Event | Refreshed vouchers |
|---|---|
| SI/PI submit/cancel | itself, or `return_against` for linked returns; advances' source PE/JE (reconciled) |
| PE submit/cancel | every reference (SI/PI/JE → outstanding+status; SO/PO → advance_paid+status) |
| JE submit/cancel | every `reference_name` row |
| Payment Reconciliation / advance allocation | newly linked invoices + the PE/JE |
| Invoice cancel with `unlink_payment_on_cancellation_of_invoice` | the PEs/JEs that referenced it (now unallocated) |
| Daily job `app.mark_overdue_invoices()` | SI/PI with status `Unpaid%`/`Partly Paid%` (§5.2) |

### 4.6 Cancellation

`app.cancel_doc` (02-db) → `app.on_cancel__<table>`:

- **SI:** `check_if_return_invoice_linked_with_payment_entry`; accounts_controller `on_cancel`: remove from Bank Transactions, cancel system-generated Credit Note JEs (§3.8), unlink payments (setting = 1); status updater on SO/DN (reverse), billing status in DN; `update_stock` → reverse SLE (04-stock); `reverse_gl_entries`; `status = Cancelled`; unlink timesheets (06).
- **PI:** same pattern; PO hold/close check; project purchase cost reversed.
- **PE:** reverse GL/PLE; payment schedule `paid_amount` reduced; references refreshed; delinked from `advances` rows of invoices (`delink_advance_entries`); SO/PO advance refresh.
- **JE:** reverse GL/PLE; unlink from invoices' advances; reversal JE link kept (`reversal_of`).
- **Bank Transaction:** clears linked vouchers' `clearance_date`.

`linked_docs` guard (02-db `app.cancel_doc`) ignores `gl_entry`, `payment_ledger_entry`, `stock_ledger_entry` and the system Credit/Debit Note JEs (ERPNext `ignore_linked_doctypes`). Amend (`app.amend_doc`) clears `clearance_date` and no-copy fields (`due_date`, `is_return`, `return_against`, `update_outstanding_for_self`, `status`, `outstanding_amount`, `advances` allocations).

### 4.7 Budget check (`controllers/budget_controller.py`, P7)

Runs inside `app.make_gl_entries` for the GL map (and from 03-buying for MR/PO submit): for each GL row on an expense/income account the key `(budget_against, cost_center|project, account)` is matched against submitted budgets whose FY range covers the posting date (cost center/project ancestors included via `path`). For each match: `actual_expense` = Σ(debit − credit) of non-cancelled GL for the key in the fiscal year; `current` = Σ(debit − credit) of this map's rows for the key; `accumulated_monthly_budget` = budget distribution up to the posting month. Checks: annual `actual + current > budget_amount` → action `action_if_annual_budget_exceeded` ("Annual Budget for Account {0} against {1}: {2} is {3}. It will be exceeded by {4}"); monthly `actual + current > accumulated_monthly_budget` → `action_if_accumulated_monthly_budget_exceeded` ("Accumulated Monthly Budget for Account {0} against {1}: {2} is {3}. It will be exceeded by {4}"). `Stop` raises (`BudgetError`, title "Budget Exceeded"), `Warn` returns a warning to the Server Action toast, `Ignore` nothing; users holding `companies.exception_budget_approver_role` always get `Warn`. PO/MR checks use ordered/requested amounts (`get_ordered_amount`, `get_requested_amount`) when the budget is applicable to them.

### 4.8 Worked examples (from ERPNext tests; company `_Test Company`, currency precision 2)

| # | Source test | Document | GL (Dr / Cr) | PLE / outstanding |
|---|---|---|---|---|
| 1 | `test_sales_invoice_gl_entry_without_perpetual_inventory` (SI test_records[1]) | SI 1 × 500, VAT 16 % + Service Tax 10 % On Net Total | Dr Debtors 630.00 · Cr Sales 500.00 · Cr VAT 80.00 · Cr Service Tax 50.00 | +630 against SI → status Unpaid (due ≥ today) |
| 2 | `test_gl_entries_without_perpetual_inventory` (PI test_records[0]) | PI net 1250 with Shipping 100, Excise 140, Education Cess 2.8, S&H Cess 1.4, CST 29.88, VAT 156.25, Discount (Deduct) 168.03 → grand 1512.30, rounded 1512 | Dr Cost of Goods Sold 1250 · Dr Shipping 100 · Dr Excise 140 · Dr Ed. Cess 2.80 · Dr S&H Cess 1.40 · Dr CST 29.88 · Dr VAT 156.25 · Cr Discount 168.03 · Cr Payable 1512.00 · Cr Round Off 0.30 (rounding adjustment −0.30 toggled) | +1512 (Payable sign) |
| 3 | `test_gl_entries_with_perpetual_inventory_against_pr` | PI 10 × 50 linked to a PR, taxes Shipping 100 + VAT 120 (Total) | Dr SRBNB 500 · Dr Shipping 100 · Dr VAT 120 · Cr Creditors 720 | +720 |
| 4 | `test_purchase_invoice_update_stock_gl_entry_with_perpetual_inventory` | PI `update_stock`, 5 × 50 | Dr Stock In Hand 250 · Cr Creditors 250 | +250 |
| 5 | `test_purchase_invoice_for_is_paid_and_update_stock…` | same, `is_paid` from Cash | Dr Stock In Hand 250 · Cr Creditors 250 · Dr Creditors 250 · Cr Cash 250 | +250 −250 → 0, Paid |
| 6 | `test_payment_entry_write_off_difference` | SI 100; PE Receive 95 + deduction Write Off 5 | Dr Cash 95 · Dr Write Off 5 · Cr Debtors 100 (against SI) | −100 against SI → 0, Paid |
| 7 | `test_unallocated_amount_on_overpaid_purchase_payment` | PI 250; PE Pay 450 | Dr Creditors 250 (against PI) · Dr Creditors 200 (unallocated, against PE) · Cr Cash 450 | PI 0 (Paid); PE −200 advance |
| 8 | `test_payment_entry_against_order` | SO 1000; PE Receive 1000 referencing SO | Dr Cash 1000 · Cr Debtors 1000 (`against_voucher = PE`, advance for SO) | SO `advance_paid` 1000; cancel → 0 |
| 9 | `test_bank_charges_deduction` | PE Internal Transfer Bank 1000 → Cash 990 | Cr Bank 1000 · Dr Cash 990 · Dr Bank Charges 10 (auto deduction) | — |
| 10 | `test_payment` (SI + JE test_records[0]) | JE Cr Debtors 400 (party, `reference = SI`) / Dr Bank 400 | as entered | SI outstanding 562 → 162; JE cancel → 562 |
| 11 | `test_credit_note` | SI return qty −5 × 500 (standalone, `update_outstanding_for_self = 1`) then PE Pay 2500 referencing it | SI: Dr Sales 2500 · Cr Debtors 2500 (against itself). PE: Dr Debtors 2500 (against credit note) · Cr Bank 2500 | credit note −2500 → 0 |
| 12 | `test_payment_entry_unlink_against_invoice` | cancel SI paid by a PE with `unlink_payment_on_cancellation_of_invoice = 0` | — | `LinkExistsError`; with 1 the PE becomes unallocated |

Each row becomes a pgTAP case in `supabase/tests/3x_accounts_posting.test.sql` (same numbers, our account names).

---

## 5. Statuses

Status is a stored `text` column set only by SQL (`app.set_status(<table>, id)` called from `app.save_doc` / `app.submit_doc` / `app.cancel_doc` / `app.refresh_outstanding` / the overdue job). The client never writes it. Indicator colours map to Untitled UI badge colours (05-ui-ux): orange → `warning`, red → `error`, green → `success`, gray/darkgrey → `gray`, yellow → `warning` light, blue → `brand`.

### 5.1 Sales Invoice (`sales_invoice/services/status.py: StatusService`)

`status` options: `Draft, Return, Credit Note Issued, Submitted, Paid, Partly Paid, Unpaid, Unpaid and Discounted, Partly Paid and Discounted, Overdue and Discounted, Overdue, Cancelled, Internal Transfer`.

New documents keep `Draft` (amended copies reset to `Draft`). For `docstatus = 2` → `Cancelled`; `docstatus = 0` → `Draft`; `docstatus = 1` → first match of `_get_payment_status`, with `outstanding = round(outstanding_amount)` and `total = rounded_total`, or `grand_total` when `disable_rounded_total` (base_ variants when party account currency ≠ document currency, i.e. never for us):

1. `is_internal_transfer()` → `Internal Transfer` (inter-company: never for us).
2. `is_overdue(doc, total)` → `Overdue` (rule below).
3. `0 < outstanding < total` → `Partly Paid`.
4. `outstanding > 0` and `due_date ≥ today` → `Unpaid`.
5. not a return and a submitted return exists with `return_against = this` → `Credit Note Issued`.
6. `is_return = 1` → `Return`.
7. `outstanding ≤ 0` → `Paid`.
8. otherwise `Submitted`.

Then, for `Unpaid / Partly Paid / Overdue` with `is_discounted` and a Disbursed Invoice Discounting → suffix ` and Discounted` (Invoice Discounting is out of scope: the suffix variants stay in the check constraint for parity but are never produced).

**Overdue rule** (`is_overdue`): `outstanding ≤ 0` → no. `is_pos` or no `payment_schedule` rows → `due_date < today`. Otherwise `payable = Σ payment_amount of schedule rows with due_date < today`; overdue when `total − outstanding < payable` (paid so far is less than what has fallen due). Partial payments therefore keep an invoice `Partly Paid` until a schedule instalment falls due unpaid.

List indicator (`set_indicator`, used in Connections and the form header when it differs from status): outstanding < 0 → "Credit Note Issued" gray; outstanding > 0 and due ≥ today → "Unpaid" orange; outstanding > 0 and due < today → "Overdue" red; return → "Return" gray; else "Paid" green. `sales_invoice_list.js` colours: Draft red, Unpaid orange, Unpaid and Discounted orange, Overdue red, Overdue and Discounted red, Paid green, Partly Paid yellow, Partly Paid and Discounted yellow, Return gray, Credit Note Issued gray, Internal Transfer darkgrey, Submitted blue, Cancelled red; "Settled with Credit Note" green is not a status value (indicator only).

### 5.2 Purchase Invoice (`purchase_invoice.py: set_status`)

Options: `Draft, Return, Debit Note Issued, Submitted, Paid, Partly Paid, Unpaid, Overdue, Cancelled, Internal Transfer`. Same order as SI with `Debit Note Issued` in place of `Credit Note Issued`, no discounting suffix. `on_hold` is not a status: the list shows "On Hold" / "Temporarily on Hold" indicators (§2.19) while `status` stays Unpaid/Overdue.

### 5.3 Overdue job

`erpnext/hooks.py` scheduler `daily_long`: `erpnext.controllers.accounts_controller.update_invoice_status`. Ported as `app.mark_overdue_invoices()` scheduled with pg_cron daily at **00:30 UTC** (03-posting-engine; tenant time zones are not applied — see §9). Per doctype (SI, PI), one set-based `update`:

```sql
update <invoice> i set status = case when i.status like '%Discounted' then 'Overdue and Discounted' else 'Overdue' end
where i.docstatus = 1 and i.outstanding_amount > 0
  and (i.status like 'Unpaid%' or i.status like 'Partly Paid%')
  and ( (<SI only> i.is_pos and i.due_date < current_date)
        or (case when i.disable_rounded_total then i.grand_total else i.rounded_total end) - i.outstanding_amount
           < (select coalesce(sum(ps.payment_amount), 0) from payment_schedule ps
              where ps.parent_id = i.id and ps.due_date < current_date) );
```

It runs as `security definer` across all orgs (the only cross-tenant writer besides provisioning; 01-tenancy), touches `status` only (no `modified` bump, matching ERPNext's raw `qb.update`), and is idempotent. Invoices without schedule rows: ERPNext's job only catches them via the schedule sub-query, which is null → never overdue by the job; the status recompute on the next refresh (`is_overdue` uses `due_date`) catches them. Because every SI/PI we create gets a schedule (§3.9, one row for the due date when no template), the job covers all non-POS invoices.

### 5.4 Other doctypes

| Doctype | Status values | Rule |
|---|---|---|
| Payment Entry | `Draft, Submitted, Cancelled` | docstatus only (`set_status`) |
| Journal Entry | — (no status field) | list shows docstatus badge; `voucher_type` column |
| Bank Transaction | `'', Pending, Settled, Unreconciled, Reconciled, Cancelled` | draft `Pending`; submitted: `unallocated_amount > 0` → `Unreconciled`, else `Reconciled`; cancel → `Cancelled`. `Settled` is not set by default code (kept for parity) |
| Budget | — | docstatus; v16 adds `revision_of` for revised budgets (§2.23) |
| Payment Reconciliation | — | tool |
| SO / PO `advance_payment_status` | `Not Requested, Requested, Partially Paid, Fully Paid` | `set_total_advance_paid`: advance_paid 0 → Not Requested (Requested needs Payment Request: out), `0 < paid < grand_total` → Partially Paid, `≥` → Fully Paid (02-selling / 03-buying own the column) |

---

## 6. Settings & defaults

### 6.1 Accounts Settings (`accounts_settings/accounts_settings.json`)

Single per org (`accounts_settings` row, seeded in 00-setup A4 with the ERPNext JSON defaults; PLAN §5 overrides marked ★). **Exposed** = shown on `accounts/settings` (P3). **Fixed** = column kept with the default (read by ported code) but hidden; changing it is unsupported. **Dropped** = no column (feature out of scope); code paths behave as the default.

| Field | Type | ERPNext default | Ours | Notes |
|---|---|---|---|---|
| `unlink_payment_on_cancellation_of_invoice` | Check | 1 | exposed, 1 ★ | §3.8 / §4.6 |
| `unlink_advance_payment_on_cancelation_of_order` | Check | 1 | exposed, 1 | SO/PO cancel unlinks advances |
| `delete_linked_ledger_entries` | Check | 0 | fixed 0 | deleting submitted-then-cancelled docs is not allowed (02-db) |
| `enable_immutable_ledger` | Check | 0 | fixed 0 | reversal semantics of 03 |
| `check_supplier_invoice_uniqueness` | Check | 0 | exposed | PI `bill_no` unique per supplier + FY when on ("Supplier Invoice No exists in Purchase Invoice {0}") |
| `automatically_fetch_payment_terms` | Check | 0 | exposed | §3.9 |
| `enable_common_party_accounting` | Check | 0 | fixed 0 | Party Link out |
| `allow_multi_currency_invoices_against_single_party_account` | Check | 0 | dropped | single currency (§9) |
| `confirm_before_resetting_posting_date` | Check | 1 | exposed | form prompt when `set_posting_time` toggled |
| `over_billing_allowance` | Currency (%) | — (0) | exposed, 0 ★ | status updater billing tolerance (03-posting-engine) |
| `role_allowed_to_over_bill` | Link Role | — | exposed | |
| `credit_controller` | Link Role | — | exposed | bypass credit limit (§3.5) |
| `enable_overdue_billing_threshold` | Check | 0 | exposed | SI blocked when overdue > `customer_credit_limit.overdue_billing_threshold` ("Overdue Limit crossed for customer {0}. Overdue amount {1} exceeds the allowed limit {2}.") |
| `role_allowed_to_bypass_overdue_billing` | Link Role | — | exposed | |
| `determine_address_tax_category_from` | Select Billing Address / Shipping Address | Billing Address | exposed | tax category from address (§3.1) |
| `add_taxes_from_item_tax_template` | Check | 1 | exposed, 1 ★ | §3.11 |
| `add_taxes_from_taxes_and_charges_template` | Check | 0 | exposed | auto-apply the default template when the doc has none |
| `round_row_wise_tax` | Check | 0 | exposed | §3.11 step 4 |
| `book_tax_discount_loss` | Check | 0 | fixed 0 | early payment discount tax loss (discount via payment terms is basic only) |
| `make_payment_via_journal_entry` | Check | 0 | fixed 0 | "Make Payment" opens Payment Entry |
| `merge_similar_account_heads` | Check | 0 | exposed | §4.1 |
| `show_balance_in_coa` | Check | 1 | exposed | TreeView balance column (§8) |
| `allow_stale` | Check | 1 | exposed | Currency Exchange lookup (§2.8) |
| `stale_days` | Int | 1 | exposed | used when `allow_stale = 0` |
| `allow_pegged_currencies_exchange_rates` | Check | 0 | dropped | |
| `exchange_gain_loss_posting_date` | Select Invoice / Payment / Reconciliation Date | Payment | fixed | no exchange gain/loss in single-currency ledgers |
| `auto_reconcile_payments` | Check | 0 | fixed 0 | background reconciliation job out |
| `auto_reconciliation_job_trigger` | Int | 15 | dropped | |
| `reconciliation_queue_size` | Int | 5 | dropped | |
| `enable_party_matching`, `enable_fuzzy_matching` | Check | 0 / 0 | fixed 0 | bank-transaction party matching out |
| `transfer_match_days` | Int | 3 | exposed | Bank Reconciliation Tool internal-transfer matching window |
| `automatically_run_rules_on_unreconciled_transactions` | Check | 1 | dropped | Bank Transaction Rule out |
| `ignore_account_closing_balance` | Check | 0 | fixed 1 (effective) | no Account Closing Balance table (PCV out) — reports always aggregate GL |
| `ignore_is_opening_check_for_reporting` | Check | 0 | exposed | §3.13 |
| `general_ledger_remarks_length` | Int | 0 | exposed | 0 = full remarks |
| `receivable_payable_remarks_length` | Int | 0 | exposed | |
| `receivable_payable_fetch_method` | Select Buffered / UnBuffered Cursor | Buffered Cursor | dropped | SQL report function |
| `default_ageing_range` | Data | `30, 60, 90, 120` | exposed ★ | AR/AP `range` default (§7.2) |
| `show_inclusive_tax_in_print`, `show_payment_schedule_in_print`, `show_taxes_as_table_in_print` | Check | 0 / 0 / 0 | exposed | print formats (08) |
| `book_asset_depreciation_entry_automatically` | Check | 1 | exposed, 1 ★ | 10-assets |
| `calculate_depr_using_total_days` | Check | 0 | exposed | 10-assets |
| `role_to_notify_on_depreciation_failure` | Link Role | — | exposed | 10-assets |
| `use_legacy_budget_controller` | Check | 0 | fixed 0 | §4.7 ports the new `BudgetValidation` |
| `maintain_same_internal_transaction_rate`, `maintain_same_rate_action`, `role_to_override_stop_action`, `fetch_valuation_rate_for_internal_transaction` | Check / Select (Stop) / Role / Check | 0 / Stop / — / 0 | dropped | inter-company out |
| `create_pr_in_draft_status`, `fetch_payment_schedule_in_payment_request` | Check | 1 / 1 | dropped | Payment Request out |
| `automatically_process_deferred_accounting_entry`, `book_deferred_entries_via_journal_entry`, `submit_journal_entries`, `book_deferred_entries_based_on` | Check / Check / Check / Select Days | 1 / 0 / 0 / Days | dropped | deferred accounting out |
| `use_legacy_controller_for_pcv`, `pcv_job_timeout` | Check / Int | 1 / 3600 | dropped | PCV out |
| `enable_discounts_and_margin` | Check | 0 | fixed 1 (effective) | v16 feature toggle hiding discount/margin fields; we always show item discount and margin (§3.11) — see §9 |
| `enable_loyalty_point_program`, `enable_subscription`, `enable_accounting_dimensions`, `disable_include_dimensions` | Check | 0 / 1 / 0 / 0 | dropped | out of scope |
| `book_stock_expense_gl_entries` | Check | 0 | fixed 0 | 04-stock |
| `repost_allowed_types`, `preview_mode` | Table / Check | — / 0 | dropped | repost out |

The Company-level accounting fields that v16 moved off Accounts Settings (`accounts_frozen_till_date`, `role_allowed_for_frozen_entries`, `reconciliation_takes_effect_on`, `exception_budget_approver_role`, etc.) are columns on `companies` (00-setup §2.1) and are edited on the Company form; this doc only consumes them.

### 6.2 Other defaults consumed

| Source | Field | Used by |
|---|---|---|
| `companies` (00-setup §2.1) | `default_receivable_account_id`, `default_payable_account_id` | party account fallback (§3.5) |
| | `default_income_account_id`, `default_expense_account_id`, `cost_center_id` | item rows (§3.1/§3.2), round-off fallback |
| | `round_off_account_id`, `round_off_cost_center_id`, *`round_off_for_opening_id`* | §4.0 (00-setup §companies) |
| | `write_off_account_id`, `exchange_gain_loss_account_id`, `bank_charges_account_id`, `default_discount_account_id` | PE deductions / PI write-off / PE difference (§3.7) |
| | `default_bank_account_id`, `default_cash_account_id` | JE Bank/Cash Entry, PE `paid_from/paid_to` default (`get_default_bank_cash_account`) |
| | `stock_received_but_not_billed_id`, `default_inventory_account_id`, `stock_adjustment_account_id`, `enable_perpetual_inventory` | §4.4 |
| | `credit_limit`, `payment_terms_id` | §3.5 / §3.9 |
| | `accounts_frozen_till_date`, `role_allowed_for_frozen_entries` | §4.0 step 7 |
| | `exception_budget_approver_role` | §4.7 |
| Selling Settings (02) | `enable_discount_accounting` (0), `allow_negative_rates_for_items` (0) | §4.3 / §3.11 |
| Buying Settings (03) | `project_update_frequency` | PI submit |
| Stock Settings (04) | `allow_negative_stock` (0) | SI/PI `update_stock` |
| Global Defaults (00-setup) | `disable_rounded_total` (0), `default_currency` | §3.11 |
| System Settings (00-setup) | `currency_precision` (blank → `number_format` precision 2), `float_precision` (3), `rounding_method` | `app.round` |

Provisioning steps this module implements (defined in 00-setup §3.1, values not repeated): **B3** account tree from the `0115` CoA template, **B4** receivable/payable defaults, **B6** cost center tree, **B7** country tax templates (`country_wise_tax.json`), **B9** company default accounts, **B10** `Cash` mode-of-payment account, **B13** optional wizard bank account. They are added to `app.provision_organization` / `app.create_company` by the P2 migrations that create `account`, `cost_center`, the tax templates and `mode_of_payment` (B5 warehouses belong to 04-stock). Fixtures **A11** (`mode_of_payment` rows), **A13** (`party_type`) and **A15** (`print_heading` Credit Note / Debit Note) are seeded by the same migrations.

---

## 7. Reports & dashboard

All reports are `app.report_<slug>(filters jsonb) returns jsonb` (`{columns, rows, summary, chart}`) — `security invoker`, RLS applies, `stable`, called from a Server Component through `ReportView` (05-ui-ux). Common rules: company filter required and defaulted from the user's default company; ledger rows filtered `is_cancelled = false`; group accounts roll up through `account.path` (`<@`); amounts rounded with `app.round` at output only; finance book, accounting dimension, presentation currency and DuckDB options are dropped (§9). Every report has CSV/XLSX export (ReportView) and drills: account → General Ledger, voucher → document form.

### 7.1 Accounting dashboard (`accounts_dashboard/accounts/accounts.json`)

`/[org]/accounts/dashboard` (`DashboardView`), sources `app.card_*` / `app.chart_*` (company + timespan filters, cached per request):

| Widget | ERPNext source | Our function | Spec |
|---|---|---|---|
| Card **Total Outgoing Bills** | number_card `total_outgoing_bills` | `app.card_sum('sales_invoice', 'base_net_total', docstatus = 1)` | Sum, filter docstatus = 1 |
| Card **Total Incoming Bills** | `total_incoming_bills` | same on `purchase_invoice` | |
| Card **Total Incoming Payment** | `total_incoming_payment` | Σ `payment_entry.base_received_amount`, `payment_type = Receive` | |
| Card **Total Outgoing Payment** | `total_outgoing_payment` | Σ `base_paid_amount`, `payment_type = Pay` | |
| Chart **Profit and Loss** (Full, Bar) | report chart, `periodicity = Yearly`, Fiscal Year | `app.report_profit_and_loss(...).chart` | datasets Income / Expense / Net Profit/Loss |
| Chart **Outgoing Bills (Sales Invoice)** (Half, Bar) | Sum `posting_date`, Last Year, Monthly | `app.chart_timeseries('sales_invoice', 'base_net_total', 'posting_date', 'monthly', 12)` | |
| Chart **Incoming Bills (Purchase Invoice)** (Half, Bar) | same | on `purchase_invoice` | |
| Chart **Accounts Receivable Ageing** (Half, Donut) | AR report chart, `ageing_based_on = Due Date`, ranges 30/60/90/120 | `app.report_accounts_receivable(...).chart` | P7 (needs §7.2 AR) |
| Chart **Accounts Payable Ageing** (Half, Donut) | AP report chart | `app.report_accounts_payable(...).chart` | P7 |
| Chart **Budget Variance** (Full, Bar) | Budget Variance report, Monthly, Cost Center | `app.report_budget_variance(...).chart` | P7 |
| Chart **Bank Balance** (Full, Line) | custom source `Account Balance Timeline`, Last Year, Monthly | `app.chart_account_balance_timeline(account_id default = companies.default_bank_account_id, 12 months)` | month-end balances of the account subtree |

Widgets whose report is not built yet render the dashboard "not available yet" empty state (05-ui-ux) instead of being hidden, so the layout matches ERPNext. Home (00-setup) reuses the Profit and Loss chart.

### 7.2 Report specs

**General Ledger** (`general_ledger/`, P3). Filters: `company` ✔, `from_date` (today − 1 month) ✔, `to_date` (today) ✔, `account` (multi), `voucher_no`, `against_voucher_no`, `party_type`, `party` (multi, requires party_type), `party_name`, `categorize_by` (`Categorize by Voucher`, **`Categorize by Voucher (Consolidated)`** default, `Categorize by Account`, `Categorize by Party`), `tax_id`, `cost_center` (multi), `project` (multi), `show_opening_entries`, `show_cancelled_entries`, `show_net_values_in_party_account`, `show_remarks`, `ignore_err` (exclude Exchange Rate Revaluation: no-op), `ignore_cr_dr_notes` (exclude system Credit/Debit Note JEs), `disable_opening_balance_calculation`. Validations: "From Date must be before To Date"; party without party type. Columns: Posting Date, Account, Debit, Credit, Balance, Voucher Type, Voucher Subtype, Voucher No, Against Account, Party Type, Party, Party Name, Project, Cost Center, Against Voucher Type, Against Voucher, Supplier Invoice No, Remarks (with `general_ledger_remarks_length`). Rows: **Opening** (Σ before `from_date` plus `is_opening = Yes` rows dated in range unless `show_opening_entries`), entries, **Total**, **Closing (Opening + Total)**; per group when categorised (sub-totals per account / party / voucher); "Consolidated" merges rows of the same voucher + account. Balance is running `Σ(debit − credit)`.

**Trial Balance** (`trial_balance/`, P3). Filters: `company`, `fiscal_year` (current FY) ✔, `from_date` / `to_date` (FY bounds, must be inside the FY: "From Date should be within the Fiscal Year. Assuming From Date = {0}"), `cost_center`, `project`, `show_zero_values` (0), `show_unclosed_fy_pl_balances` (0), `show_net_values` (**1**), `show_group_accounts` (**1**); `with_period_closing_entry_*` dropped (no PCV). Columns: Account, Account Name, Account Number, Currency, Opening (Dr), Opening (Cr), Debit, Credit, Closing (Dr), Closing (Cr). Opening for **balance-sheet** accounts = Σ GL before `from_date` (+ `is_opening = Yes` in range); for **P&L** accounts = Σ since FY start before `from_date` (prior years' P&L is not carried — without PCV ERPNext shows it only with `show_unclosed_fy_pl_balances`, as row "Unclosed Fiscal Years Profit / Loss (Credit)"). `show_net_values` nets Dr/Cr per column pair. Tree output with group rows; Total row; group rows hidden when `show_group_accounts = 0`.

**Trial Balance for Party** (`trial_balance_for_party/`, P3). Filters: `company`, `fiscal_year`, `from_date`, `to_date`, `party_type` (**Customer**) ✔, `party`, `account` (multi), `show_zero_values` (0), `exclude_zero_balance_parties` (**1**). Columns: Party, Party Name (when naming by series), Opening (Dr/Cr), Debit, Credit, Closing (Dr/Cr), Currency; Total row. Source: GL rows with `party_type`/`party`.

**Profit and Loss Statement** (`profit_and_loss_statement/` + `financial_statements.py`, P3). Common financial-statement filters (`financial_statements.js`): `company`, `filter_based_on` (`Fiscal Year` default \| `Date Range`), `period_start_date`, `period_end_date`, `from_fiscal_year`, `to_fiscal_year` (current FY), `periodicity` (`Monthly|Quarterly|Half-Yearly|Yearly`, default **Yearly**), `cost_center`, `project`; plus `accumulated_values` (**0** for P&L), `show_zero_values`, `show_account_details` (`Summary` default \| `Account Breakdown`), `selected_view` (`Report` \| `Growth` \| `Margin`). `report_template` (Financial Report Template) dropped → always the legacy engine (§9). Period list: `get_period_list` splits the range into periodicity buckets, labels like `Jan 2026` / `Apr-Jun 2026` / `2026` (FY name for Yearly). Sections: **Income** (root_type Income, credit-positive) and **Expense** (debit-positive), each a tree with totals "Total Income (Credit)" / "Total Expense (Debit)"; final row **"Profit for the year"** = income − expense per period; summary cards Total Income / Total Expense / Net Profit (labels "… This Year" when Yearly over one FY). Chart: bar Income / Expense / Net Profit/Loss. Growth view: % change vs previous period; Margin view: % of income.

**Balance Sheet** (`balance_sheet/`, P3). Same common filters; `accumulated_values` (**1**). Sections Asset (debit-positive), Liability, Equity (credit-positive) — balances as on each period end (opening since inception). Rows added: **"Unclosed Fiscal Years Profit / Loss (Credit)"** in Equity = P&L of fiscal years before the first period (always present for us since PCV is out; ERPNext warns "Previous Financial Year is not closed"); **"Provisional Profit / Loss (Credit)"** = `total_asset − total_liability − total_equity` per period when non-zero (current unclosed P&L); **"Total (Credit)"** = liability + equity + provisional. Summary cards: Total Asset, Total Liability, Total Equity, Provisional Profit / Loss (Credit). Chart datasets Assets / Liabilities / Equity. Totals must reconcile: pgTAP asserts `asset = liability + equity + provisional + unclosed` on the §4.8 fixtures.

**Cash Flow** (`cash_flow/`, P3 nav / stretch). Common filters + `show_opening_and_closing_balance` (0). Indirect method: start from **Net Profit** (P&L "Profit for the year" per period), then sections by `account_type` net change (`get_cash_flow_accounts`): **Operations** — Depreciation (added back, sign flipped), Net Change in Accounts Receivable, Net Change in Accounts Payable, Net Change in Inventory (Stock), footer "Net Cash from Operations"; **Investing** — Net Change in Fixed Asset, "Net Cash from Investing"; **Financing** — Net Change in Equity, "Net Cash from Financing"; final "Net Change in Cash" (= Σ sections) and, with the option, Opening / Closing cash (accounts of type Cash/Bank). Accounts with other types (e.g. Tax, Current Liability) are not in any section (ERPNext behaviour), so Net Change in Cash may not equal the cash movement — documented in the report description.

**Consolidated Financial Statement** (`consolidated_financial_statement/`, **stretch**). Filters: `company` (a group company), `filter_based_on`, FY or dates, `report` (`Balance Sheet` default \| `Profit and Loss Statement` \| `Cash Flow`), `accumulated_in_group_company` (0), `show_zero_values`. Columns per subsidiary (`companies.parent_company_id` subtree) + Total; accounts matched across companies by `account_name` (+ number); inter-company eliminations none (ERPNext none). Single currency per org assumed (§9).

**Profitability Analysis** (`profitability_analysis/`, **stretch**). Filters: `company`, `based_on` (**Cost Center** \| Project; Accounting Dimension dropped), `fiscal_year`, `from_date`, `to_date`, `show_zero_values`. Columns: Account (cost center / project tree), Income, Expense, Gross Profit / Loss (income − expense). Source: P&L GL rows grouped by `cost_center_id` / `project_id`.

**Accounts Receivable / Accounts Payable** (`accounts_receivable/`, `accounts_payable/`, P7). Source: **Payment Ledger** (not GL): non-delinked PLE grouped by `(against_voucher_type, against_voucher_id)` with `posting_date ≤ report_date`. Filters (AR): `company`, `report_date` (today), `cost_center`, `project`, `party_type` (Customer), `party` (multi), `party_account`, `ageing_based_on` (`Posting Date` \| **`Due Date`**; AP adds `Supplier Invoice Date`), `age_as_on` (**Report Date** \| Today), `range` (`accounts_settings.default_ageing_range`, `30, 60, 90, 120`), `customer_group`, `payment_terms_template`, `sales_partner`, `sales_person`, `territory`, `group_by_party`, `based_on_payment_terms` (split rows by schedule term), `show_future_payments`, `show_delivery_notes`, `show_sales_person`, `show_remarks`; AP: `supplier_group` instead of customer filters. Columns: Posting Date, Party Type, Party, Party Account, Cost Center, Voucher Type, Voucher No, Due Date, (AP: Bill No, Bill Date), Invoice Grand Total, Invoiced Amount, Paid Amount, Credit Note (AP: Debit Note), Outstanding Amount, Age (Days), ageing buckets `<0`, `0-30`, `31-60`, `61-90`, `91-120`, `121-Above`, Currency, Customer LPO, Territory / Customer Group / Supplier Group, Remarks. Invoiced = PLE rows of the voucher itself; Paid = PE/JE allocations; Credit Note = return allocations; unallocated payments show as rows with negative outstanding. Age = `as_on − based_on_date`. Chart: donut of the bucket totals (dashboard §7.1). Summary variants (AR Summary / AP Summary) are not in the nav; `group_by_party` covers them.

**Budget Variance Report** (`budget_variance_report/`, P7). Filters: `company`, `from_fiscal_year`, `to_fiscal_year` (current FY), `period` (`Monthly|Quarterly|Half-Yearly|`**`Yearly`**), `budget_against` (**Cost Center** \| Project), `budget_against_filter` (multi), `show_cumulative` (0). Columns per period: Budget, Actual, Variance (budget − actual), plus totals; rows per budget-against × account. Budget amounts per period from `budget_distribution` (§2.23); actuals from GL (debit − credit) of the account for the cost center / project subtree. Chart: bar Budget vs Actual.

Out of the nav and not built: Accounts Receivable/Payable Summary, Sales/Purchase Register, Gross Profit (02-selling owns it if built), Item-wise Sales/Purchase Register (02/03), Tax Withholding Details, Bank Reconciliation Statement (stretch, P7 — the Bank Reconciliation Tool shows the same "balance as per bank vs books" header), Payment Period Based On Invoice Date, Customer/Supplier Ledger Summary, Dimension-wise Accounts Balance.

---

## 8. UI notes

Generic components only (05-ui-ux); every item below is descriptor configuration or a small extension of the shared component, not a bespoke screen, except the three tool pages (Payment Reconciliation, Bank Reconciliation Tool, Bank Clearance).

**Chart of Accounts / Cost Centers (TreeView).**
- Lazy-loaded tree by `parent_id`, root per company (company switcher in the toolbar), search by name/number.
- Columns: name, number, account type badge, and the balance when `show_balance_in_coa = 1` (`app.account_balances(company, as_of = today)` = Σ GL of the subtree, Dr/Cr suffix, tabular numerals).
- Node actions: Add Child (group only), Edit, Rename / Update Account Number (dialog → `app.update_account_number`), Convert to Group / Ledger (`convert_group_to_ledger` "Account with existing transaction cannot be converted to ledger" / "…to group"), Merge (`merge_account`, same root type, is_group and company: "Merging is only possible if following properties are same in both records. Is Group, Root Type, Company and Account Currency"), Disable, View Ledger (GL filtered).
- Delete is blocked when the account has GL ("Account with existing transaction can not be deleted") or children (Frappe NestedSet `on_trash` raises its standard "cannot delete node with children" error; we use the 02-db tree guard).
- Keyboard: arrows navigate, → expands, ← collapses, Enter opens the form, `N` adds a child.

**Transaction forms (DocForm).**
- Header: party, dates, currency/conversion (hidden while document currency = company currency).
- Items ChildTable: item code, qty, UOM, rate, discount %, amount, plus income/expense account and cost center under the row's "more" drawer.
- Taxes ChildTable: type, account, rate, amount, total.
- Totals panel (net total, taxes, discount, grand total, rounding adjustment, rounded total, in words), right-aligned with tabular numerals.
- Payment schedule ChildTable (collapsed), Advances table (SI/PI, "Get Advances Received/Paid" button → `app.get_advance_entries`), and `terms`.
- Client preview recalculates on every edit through `src/lib/calc/taxes-and-totals.ts` (§3.11). The Server Action recomputes before save; a mismatch beyond rounding refreshes the form with a toast.

**Docstatus actions.**
- Draft: Save · Submit.
- Submitted: Cancel · Amend, plus Create ▸ menus (SI: Payment, Return / Credit Note, Delivery Note; PI: Payment, Return / Debit Note, Purchase Receipt; PE: none; JE: Reverse Journal Entry). Create items come from `app.map_doc` and open a prefilled draft.
- View ▸ Accounting Ledger (GL report filtered by voucher), Payment Ledger (PLE rows; Accounts Manager).
- Confirmation dialogs list the side effects ("This will post 4 GL entries…"), using a dry-run of `app.<table>_gl_map` → the **Accounting Ledger preview** button on drafts (ERPNext "Preview Accounting Ledger").

**Lists (DocList).**
- Columns and standard filters as in §2, with status badges coloured per §5.
- Saved filters SI/PI: Unpaid, Overdue, Drafts, Credit/Debit Notes, This Month.
- Right-aligned money columns, totals in the footer for the filtered set.
- Bulk Submit / Cancel through the doc engine, one transaction per document with per-row results.

**Connections tab (`sales_invoice_dashboard.py`, `purchase_invoice_dashboard.py`).**
- SI: Payment (Payment Entry, Payment Request†, Journal Entry, Invoice Discounting†, Dunning†), Reference (Timesheet, Delivery Note, Sales Order), Returns (Sales Invoice).
- PI: Payment (Payment Entry, Payment Request†, Journal Entry), Reference (Purchase Order, Purchase Receipt, Asset, Landed Cost Voucher), Returns (Purchase Invoice).
- † = out of scope, hidden.

**Payment Entry form.**
- `payment_type` segmented control first; party and accounts follow. "Get Outstanding Invoices" dialog (`get_outstanding_reference_documents` filters: from/to posting date, due date range, outstanding amount range, cost center, "Allocate Payment Amount" check).
- Difference amount shown live with a "Set Difference Account" / "Make Difference Entry" action (§3.7).

**Journal Entry form.**
- Accounts ChildTable shows a running Total Debit / Total Credit / Difference footer.
- "Make Difference Entry" adds a balancing row.
- `voucher_type` presets (Bank/Cash Entry pre-fills the default bank/cash account row; Write Off Entry offers "Get Outstanding Invoices").

**Reports (ReportView).**
- Filters bar from the report descriptor (§7.2) with defaults, all URL-synced via nuqs; Run is explicit for heavy reports (GL, AR/AP).
- Tree reports show indent and collapse; frozen first column; negative values in error colour when `warn_if_negative`.
- Drill-down to GL / document; CSV/XLSX export; print (08).

**Tool pages.**
- **Payment Reconciliation**: party filters → two tables (Invoices, Payments) with select → Allocate → editable allocation table → Reconcile.
- **Bank Reconciliation Tool**: bank account + date range, a header with "Closing balance as per bank statement" vs "as per ERP" and difference, unreconciled transactions list → match panel (vouchers ranked by amount/reference/party; `transfer_match_days`) → Reconcile / Create Voucher (PE / JE).
- **Bank Clearance**: account + date range + "Include Reconciled Entries" → editable clearance date per voucher → Update Clearance Date.

**States.** Every list, form and report has empty ("No Sales Invoices yet — Create your first"), loading (skeleton rows), and error (retry + message from the Server Action) states. Ledger-affecting errors surface ERPNext's message text verbatim (§3–§4) in a toast with the doc link.

**Number formatting.** `src/lib/calc/number.ts` + company currency symbol; Dr/Cr suffix on balances; dates in the org date format (00-setup System Settings).

---

## 9. Deviations from ERPNext

1. **Deviation:** single ledger currency — `account.account_currency`, party accounts and bank accounts are always the company currency; documents may use another currency with `conversion_rate`, but every GL/PLE amount is posted in company currency (`*_in_account_currency = base`), and there are no Exchange Gain/Loss JEs, Exchange Rate Revaluation or multi-currency JE. **Reason:** PLAN §1 scope ("multi-currency beyond document currency" out); removes the hardest reconciliation paths.
2. **Deviation:** Financial Report Template / Account Category-driven reports are not built; BS / P&L / Cash Flow always use the legacy `financial_statements.py` engine (the v16 `FinancialReportEngine` only runs when `filters.report_template` is set). Account Category is kept as a master (seeded from the CoA template) so the data is ready. **Reason:** default behaviour is the legacy engine; the template builder is a large UI with no default usage.
3. **Deviation:** no Period Closing Voucher, Account Closing Balance or Accounting Period; reports always aggregate GL (`ignore_account_closing_balance` effectively 1) and the Balance Sheet always shows "Unclosed Fiscal Years Profit / Loss (Credit)". **Reason:** `.cursorrules` out-of-scope list (Period Closing).
4. **Deviation:** no Accounting Dimensions, Finance Books, presentation currency or DuckDB report backends; the corresponding filters, GL columns and merge-key members are dropped. **Reason:** out of scope (Accounting Dimensions) / single currency.
5. **Deviation:** Advance Payment Ledger Entry is folded into `payment_ledger_entry.advance_voucher_type/advance_voucher_id`, and `set_total_advance_paid` reads PLE. **Reason:** one ledger table fewer with identical sums; 03-posting-engine keeps the ledger set at GL/SLE/PLE/Bin.
6. **Deviation:** the 03-posting-engine reversal (mark originals `is_cancelled`, insert mirrored rows) is used for every ledger instead of ERPNext's two modes (immutable ledger on/off). **Reason:** one deterministic cancel path; matches `enable_immutable_ledger = 0` output for reports.
7. **Deviation:** SI `write_off_amount` / "Write Off Outstanding Amount" is not exposed (POS-only in v16) and SI `is_pos`, `is_consolidated`, loyalty, `is_discounted` fields are dropped; PI keeps `write_off_amount` / `write_off_account`. **Reason:** POS, Loyalty and Invoice Discounting are out of scope; v16 posts SI write-off only when `is_pos`.
8. **Deviation:** `enable_discounts_and_margin` is treated as 1 (discount and margin fields always visible) while Selling Settings `enable_discount_accounting` stays 0. **Reason:** item discounts are part of default selling/buying flows in PLAN; the v16 toggle only hides fields.
9. **Deviation:** Invoice status keeps the `… and Discounted` options in the check constraint but never sets them. **Reason:** parity of values for imports/exports; Invoice Discounting is out.
10. **Deviation:** the overdue job runs at 00:30 UTC for every org rather than per-site `daily_long` in the site time zone. **Reason:** one pg_cron job (03-posting-engine); at most a few hours' lag for far-east/west tenants, and every status refresh recomputes `is_overdue` with the current date anyway.
11. **Deviation:** Payment Reconciliation is a simplified page (no "Reconcile in background", no `Unreconcile Payment`, no Process Payment Reconciliation scheduler, no exchange difference); credit/debit note reconciliation still creates the system Credit/Debit Note JE. **Reason:** keeps the core allocation semantics with a fraction of the UI; unreconcile can be achieved by cancel + amend.
12. **Deviation:** Bank Statement Import is a dedicated CSV wizard instead of Data Import; Plaid, Bank Transaction Rules and party/fuzzy matching are out; the matcher ranks candidates by amount, reference number and party only. **Reason:** Data Import framework is not ported; integrations are out of scope.
13. **Deviation:** Tax Withholding is basic — single-threshold and cumulative thresholds on PI/PE with `Tax Withholding Rate` per fiscal year, no Lower Deduction Certificate, no TCS on SI, no Tax Withholding Entry ledger. **Reason:** PLAN P7 "basic TDS"; regional extensions are out.
14. **Deviation:** Budget implements only the v16 `BudgetValidation` path (no legacy controller), applicable to expense accounts on GL posting, Purchase Order and Material Request; no `Budget Revision` workflow UI beyond the `revision_of` link. **Reason:** `use_legacy_budget_controller = 0` is the default.
15. **Deviation:** inter-company invoices / Internal Transfer status, Party Link (common party accounting) and Shareholder / Employee party types are not supported. **Reason:** inter-company and HR are out of scope; 00-setup A13 seeds Customer and Supplier only.
16. **Deviation:** Journal Entry voucher types offered in the picker are `Journal Entry, Bank Entry, Cash Entry, Credit Card Entry, Debit Note, Credit Note, Contra Entry, Excise Entry, Write Off Entry, Opening Entry` (§3.6); `Depreciation Entry` and `Exchange Gain Or Loss` are system-only, and `Inter Company Journal Entry, Asset Disposal, Periodic Accounting Entry, Exchange Rate Revaluation, Deferred Revenue, Deferred Expense` are rejected by the check constraint. **Reason:** their source features are out of scope.
17. **Deviation:** Opening Invoice Creation Tool is not built; opening balances are entered by Opening Entry JE (party rows allowed) or by SI/PI with `is_opening = Yes`. **Reason:** out-of-scope list; the JE route covers the same ledger result.
18. **Deviation:** Accounts User does not get SI/PI cancel by default (ERPNext JSON grants Accounts User submit but cancel only to Accounts Manager on SI) — we keep ERPNext's matrix verbatim rather than PLAN's simplified role table where they differ. **Reason:** `.cursorrules` "keep ERPNext defaults"; flagged for PLAN reconciliation.
19. **Deviation:** report caching/prepared reports are not used; heavy reports (GL, AR/AP) run on demand with an explicit Run button and an index-backed SQL function. **Reason:** Prepared Report infrastructure is not ported; SQL is fast enough at SMB volumes.
20. **Not a deviation (recorded for implementers):** the rounding helpers follow Frappe's **banker's rounding** (half-to-even, the `rounding_method` ERPNext's tests run with; fixture 19453.125 → 19453.12) for document-level money (`flt` with precision), as 03-posting-engine "Rounding" specifies. Postgres `round()` is half-away-from-zero, so `app.round` implements half-even explicitly.

---

## 10. Implementation checklist

Migration numbers follow 02-database-conventions (one block per phase, numbered in build order: P2 items `02nn_accounts_*`, P3 `03nn_accounts_*`, P5/P6 invoices in those phases' blocks, P7 `07nn_accounts_*`); each item = one migration (+ RLS + `doctype_meta` + `role_permissions`), one descriptor in `src/doctypes/accounts/`, Zod schema, Server Actions, list/form, pgTAP + Vitest, `src/types/database.ts` regenerated.

### P2 — masters

- [x] `account` tree, chart seed and default-account wiring (B3, B4, B9) — §2.1
- [ ] `app.update_account_number`, `convert_group_to_ledger/ledger_to_group`, `merge_account`, balance-type and frozen validations — §2.1
- [x] `account_category` (seeded from CoA template rows) — §2.2
- [x] `cost_center` tree — §2.3
- [x] `mode_of_payment` + `mode_of_payment_account` (+ A11 fixture, B10) — §2.5
- [x] `payment_term`, `payment_terms_template` + detail — §2.6
- [ ] `payment_schedule` child table (shared by SO/PO/SI/PI) + `src/lib/calc/payment-schedule.ts` / `app.make_payment_schedule` — §2.7, §3.9
- [ ] `currency_exchange` + `app.get_exchange_rate` — §2.8
- [ ] `party_account` child (Customer/Supplier/groups) + `app.get_party_account` — §2.9, §3.5
- [ ] `sales_taxes_and_charges_template` / `purchase_taxes_and_charges_template` + child rows — §2.11
- [ ] `item_tax_template` + detail; `app.get_item_tax_map` — §2.12
- [ ] `tax_category`, `tax_rule` + `app.get_tax_template` ranking — §2.13–2.14
- [ ] `party_type` (A13) and `print_heading` (A15) fixtures
- [ ] Provisioning: B3 account tree, B4 receivable/payable, B6 cost center tree, B7 country tax templates, B9 default accounts, B13 bank account → `app.provision_organization` / `app.create_company`; `validate_default_accounts`, `validate_advance_account_currency` on Company
- [ ] `src/lib/calc/taxes-and-totals.ts` + `app.calc_taxes_and_totals` with shared JSON fixtures (Vitest ⇄ pgTAP parity) — §3.11
- [ ] TreeView descriptors for Chart of Accounts / Chart of Cost Centers; DocForm descriptors for all P2 masters — §8

### P3 — ledger engine, JE, PE, core reports

- [ ] Ledger tables `gl_entry`, `payment_ledger_entry` with the §2.24 extra columns (`transaction_currency`, `advance_voucher_*`, `is_system_generated`, PLE `voucher_no`) — 03-posting-engine
- [ ] `app.make_gl_entries` (merge, toggle, PLE, debit/credit difference + round-off, frozen date, GL validations) — §4.0
- [ ] `app.reverse_gl_entries` (+ PLE delink) — §4.0
- [ ] `app.refresh_outstanding` + `app.set_invoice_status` — §4.0, §5
- [ ] `journal_entry` + `journal_entry_account`; `app.on_submit__journal_entry`, `app.journal_entry_gl_map`, reference validator, `make_reverse_journal_entry`, `get_balance` — §2.16, §3.6, §4.1
- [ ] `payment_entry` + reference / deduction / taxes children; `app.get_payment_entry` mapper, `get_outstanding_reference_documents`, set amounts/difference, `app.payment_entry_gl_map`, payment schedule update — §2.17, §3.3, §3.7, §4.2
- [ ] Advances: `app.get_advance_entries`, `app.reconcile_against_document`, unlink on cancel (`unlink_payment_on_cancellation_of_invoice`) — §3.8, §4.6
- [ ] Payment Reconciliation page (+ `reconcile_dr_cr_note` system JE) — §2.25, §3.8
- [ ] `accounts_settings` form (exposed fields of §6.1) — §6
- [ ] Opening Entry JE validations (P&L block, round-off for opening) — §3.13
- [ ] `app.report_general_ledger` — §7.2
- [ ] `app.report_trial_balance` — §7.2
- [ ] `app.report_trial_balance_for_party` — §7.2 (nav P3; PLAN P3 lists GL/TB/BS/P&L only)
- [ ] `app.report_profit_and_loss` (+ `get_period_list` port, chart) — §7.2
- [ ] `app.report_balance_sheet` (unclosed + provisional P/L rows) — §7.2
- [ ] `app.report_cash_flow` — §7.2 (stretch)
- [ ] `app.report_consolidated_financial_statement` — §7.2 (stretch)
- [ ] `app.report_profitability_analysis` — §7.2 (stretch)
- [ ] Accounting dashboard: 4 cards, P&L / bills / bank balance charts (`app.card_sum`, `app.chart_timeseries`, `app.chart_account_balance_timeline`) — §7.1
- [ ] pgTAP: §4.8 rows 6–10 (PE/JE), BS equation, TB debit = credit

### P5 / P6 — invoices (owned here, scheduled with 02-selling / 03-buying; flagged because the requested grouping is P2/P3/P7)

- [ ] `sales_invoice` + item / taxes / advances / payment schedule children; validate + submit pipeline, `app.sales_invoice_gl_map`, returns (`update_outstanding_for_self`), credit limit and overdue-billing check — §2.18, §3.1, §3.4, §4.3 (P5)
- [ ] SO / DN → SI mappers (`app.map_doc`), SI → PE / Return — §3.1, §3.3 (P5)
- [ ] `purchase_invoice` + children; `ExpenseAccountService` port, `app.purchase_invoice_gl_map`, `is_paid`, write-off, returns, `check_supplier_invoice_uniqueness`, on-hold — §2.19, §3.2, §4.4 (P6)
- [ ] PO / PR → PI mappers — §3.2 (P6)
- [ ] `app.mark_overdue_invoices()` + pg_cron 00:30 UTC — §5.3 (lands with SI in P5)
- [ ] pgTAP: §4.8 rows 1–5, 11, 12

### P7 — banking, budgeting, AR/AP, TDS

- [ ] `bank`, `bank_account_type`, `bank_account_subtype`, `bank_account` — §2.20
- [ ] `bank_transaction` + `bank_transaction_payments`; CSV import wizard — §2.21, §3.12
- [ ] Bank Reconciliation Tool page (+ matcher, create voucher) — §3.12, §8
- [ ] Bank Clearance page (`app.update_clearance_date`) — §2.22
- [ ] `monthly_distribution` + percentages — §2.23
- [ ] `budget` + `budget_distribution`; `BudgetValidation` in `app.make_gl_entries` and PO/MR submit — §2.23, §4.7
- [ ] `cost_center_allocation` + percentages; split in `process_gl_map` — §2.4 (nav P7; PLAN P7 does not list it)
- [ ] `tax_withholding_category` + rates + accounts; PI/PE TDS rows — §2.15, §3.10
- [ ] `app.report_accounts_receivable`, `app.report_accounts_payable` (PLE-based, ageing) + dashboard ageing donuts — §7.1, §7.2
- [ ] `app.report_budget_variance` + dashboard chart — §7.2
- [ ] pgTAP: budget Stop/Warn, bank transaction allocation status, AR ageing buckets
