# 00 — Setup module

Port of ERPNext's **Setup** module (`erpnext/setup/`) plus the Frappe-framework doctypes it leans on (User, Role, User Permission, Letter Head, Print Format, Print Settings, Email Account, Email Template, Address, Contact, Currency, Country). This doc also owns the **onboarding / provisioning spec** (`app.provision_organization()`) and the shared cross-module masters created at onboarding (Fiscal Year, Terms and Conditions, Address, Contact).

Primary sources: `erpnext/setup/sidebar/setup/setup.json`, `erpnext/setup/setup_wizard/setup_wizard.py`, `erpnext/setup/setup_wizard/operations/{install_fixtures,defaults_setup,company_setup,taxes_setup}.py`, `erpnext/setup/setup_wizard/data/*`, `erpnext/setup/install.py`, `erpnext/setup/doctype/company/company.py`, `erpnext/accounts/doctype/account/chart_of_accounts/chart_of_accounts.py`, `erpnext/accounts/doctype/account/chart_of_accounts/verified/standard_chart_of_accounts.py`, `erpnext/setup/workspace/home/home.json`, `erpnext/setup/module_onboarding/organization_onboarding/organization_onboarding.json`, `erpnext/hooks.py`.

Conventions from `docs/architecture/01-tenancy-auth-rls.md` and `02-database-conventions.md` apply everywhere: every table has `org_id` + RLS, base columns (`id, org_id, created_at, created_by, updated_at, updated_by`), masters add `name text` + `unique (org_id, name)` + `disabled`. Field tables below list only the columns on top of those base columns. Column types follow the fieldtype map in `docs/erpnext-reference.md`.

---

## 1. Scope & sidebar mapping

Sidebar source: `erpnext/setup/sidebar/setup/setup.json`. Sections marked *out* are not ported (PLAN §1), except **Global Defaults** and a pointer list to the per-module Settings pages.

| Sidebar section / item | Route (`/[org]/setup/...`) | ERPNext doctype → our table(s) | Phase |
|---|---|---|---|
| Home (Workspace "Home") | `/[org]` (org home) | workspace content → `app.home_dashboard()` + onboarding checklist | P1 |
| Company | `/setup/company`, `/setup/company/[id]` | Company → `companies` | P0 (table) / P1 (form) |
| Users (User) | `/setup/users` (with the invite drawer), `/setup/users/[id]` | User → `auth.users` + `user_profile` + `org_members` + `invitations` | P0/P1 |
| Organization › Branch | `/setup/branch` | Branch → `branch` | P1 |
| Organization › Department | `/setup/department` (tree) | Department → `department` | P1 |
| Organization › Designation | `/setup/designation` | Designation → `designation` | P1 |
| Organization › Holiday List | `/setup/holiday-list` | Holiday List / Holiday → `holiday_list`, `holiday` | P1 |
| Access › Role | `/setup/roles` | Role → `roles` | P0/P1 |
| Access › Role Profile | `/setup/role-profile` | Role Profile → `role_profile` | P0/P1 |
| Access › Role Permissions (page `permission-manager`) | `/setup/role-permissions` | Role Permission Manager → `role_permissions` matrix UI | P1 |
| Access › User Permissions | `/setup/user-permissions` | User Permission → `user_permissions` | P1 |
| Access › Authorization Rule | `/setup/authorization-rule` | Authorization Rule → `authorization_rule` (simplified, see §2.10) | P1 table/UI, enforcement P5/P6 |
| Printing › Letter Head | `/setup/letter-head` | Letter Head → `letter_head` | P1 |
| Printing › Print Format | `/setup/print-format` | Print Format → `print_format` (template registry, see §2.12) | P1 |
| Printing › Print Settings | `/setup/print-settings` | Print Settings (single) → `print_settings` | P1 |
| Email › Email Account | `/setup/email-account` | Email Account → `email_account` (outbound only) | P1 |
| Email › Email Template | `/setup/email-template` | Email Template → `email_template` | P1 |
| Email › Email Digest | `/setup/email-digest` | Email Digest / Email Digest Recipient → `email_digest`, `email_digest_recipient` | P1 (job wired as modules land) |
| Settings › Global Defaults | `/setup/global-defaults` | Global Defaults (single) → `global_defaults` | P0 ✅ |
| Settings › System | `/setup/system-settings` | System Settings (Frappe, subset) → `system_settings` | P0 ✅ |
| Settings › Accounts / Selling / Buying / Stock / Manufacturing / Projects | `/[org]/<module>/settings` | pointer links only — each is owned by its module doc (`01-accounts.md` … `06-projects.md`) | per module |
| Data (Data Import, Rename Tool, Bulk Transaction Log, Transaction Deletion Record) | — | **out** (PLAN §1: Data Import/Rename tools) | — |
| Integrations (telephony, Code List, Common Code) | — | **out** | — |
| Settings › CRM, Support, POS, Subscription, Item Variant, Delivery, Currency Exchange, Appointment Booking, Stock Reposting | — | **out** (features out of scope; Currency Exchange Settings = external rate fetch, replaced by manual `currency_exchange` rows in P2) | — |

Additionally owned by this doc (not sidebar items):

| Concern | Tables / functions | Phase |
|---|---|---|
| Provisioning spec (setup wizard + `Company.on_update`) | `app.provision_organization(jsonb)`, `app.create_company(jsonb)` | P1 |
| Shared masters | `address` + `address_link`, `contact`, `contact_email`, `contact_phone`, `contact_link`, `currency` (global), `country` (global), `fiscal_year`, `fiscal_year_company`, `terms_and_conditions` | P1 tables (UI for Address/Contact/T&C/Fiscal Year ships in P2 per PLAN §7) |
| Home workspace | onboarding checklist, number cards, P&L chart | P1 shell, data as modules land |

---

## 2. Doctype inventory

### 2.1 Company → `companies`

- **Kind:** tree master (`parent_company`, `is_group`; `nsm_parent_field = "parent_company"`). **Naming:** `field:company_name` (unique per org). Abbreviation `abbr` unique per org.
- Source: `erpnext/setup/doctype/company/company.json`, `company.py`.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| company_name | text | ✔ | | = `name` |
| abbr | text | ✔ | initials of words, upper-cased (`validate_abbr`) | unique per org; used as suffix ` - ABBR` on Account/Cost Center/Warehouse/Department names |
| is_group | boolean | | false | group companies hold no transactions |
| parent_id (parent_company) | uuid → companies | | null | parent must be `is_group` (`validate_parent_company`) |
| default_currency | text → currency.code | ✔ | org `default_currency` | cannot change once submitted SI/DN/SO/QTN/PI/PR/PO/SQ exist (`validate_currency`) |
| reporting_currency | text | | = default_currency (or parent's) | read-only, `set_reporting_currency` |
| country | text → country | ✔ | org country | change re-runs country tax fixtures |
| create_chart_of_accounts_based_on | text check | | `'Standard Template'` | `'Standard Template' \| 'Existing Company'`; forced to Existing Company when parent set |
| chart_of_accounts | text | | `'Standard'` | template key: `Standard`, `Standard with Numbers`, or a verified country JSON name (`get_charts_for_country`) |
| existing_company_id | uuid → companies | | null | copy CoA from |
| domain | text | | null | wizard persona, informational |
| company_logo | text (storage path) | | | |
| company_description | text (html) | | | |
| tax_id, phone_no, fax, email, website | text | | | |
| date_of_establishment, date_of_incorporation, date_of_commencement | date | | | |
| registration_details | text | | | |
| default_letter_head_id | uuid → letter_head | | null | |
| default_holiday_list_id | uuid → holiday_list | | null | |
| default_finance_book_id | uuid | | null | single default finance book in our scope; column kept, hidden |
| **Accounts tab** | | | | |
| default_bank_account_id | uuid → account | | wizard bank account | all `*_account` fields: must be non-group, enabled, belong to this company, in company currency (`validate_default_accounts`) |
| default_cash_account_id | uuid → account | | `Cash - ABBR` | |
| default_receivable_account_id | uuid → account | | `Debtors - ABBR` | |
| default_payable_account_id | uuid → account | | `Creditors - ABBR` | |
| default_expense_account_id | uuid → account | | `Cost of Goods Sold - ABBR` | |
| default_income_account_id | uuid → account | | `Sales - ABBR` | |
| round_off_account_id | uuid → account | | `Round Off - ABBR` | |
| round_off_cost_center_id | uuid → cost_center | | `Main - ABBR` | |
| write_off_account_id | uuid → account | | `Write Off - ABBR` | |
| bank_charges_account_id | uuid → account | | `Bank Charges - ABBR` | |
| exchange_gain_loss_account_id | uuid → account | | `Exchange Gain/Loss - ABBR` | fixed-rate multi-currency only |
| exchange_gain_account_id / exchange_loss_account_id | uuid → account | | `Exchange Gain - ABBR` / `Exchange Loss - ABBR` | |
| unrealized_exchange_gain_loss_account_id, unrealized_profit_loss_account_id | uuid → account | | null | kept, hidden (out of scope) |
| default_discount_account_id | uuid → account | | null | payment discount (Payment Terms) |
| default_advance_received_account_id, default_advance_paid_account_id, book_advance_payments_in_separate_party_account | uuid / boolean | | null / false | hidden, out of scope |
| default_deferred_revenue_account_id, default_deferred_expense_account_id | uuid | | null | hidden, out of scope |
| cost_center_id | uuid → cost_center | | `Main - ABBR` | default cost center for P&L postings |
| credit_limit | numeric(21,9) | | 0 | default customer credit limit |
| payment_terms_id | uuid → payment_terms_template | | null | |
| accounts_frozen_till_date | date | | null | GL posting guard (posting engine step 1) |
| role_allowed_for_frozen_entries | text → roles | | null | |
| reconciliation_takes_effect_on | text check | | `'Oldest Of Invoice Or Advance'` | `Advance Payment Date \| Oldest Of Invoice Or Advance \| Reconciliation Date` |
| auto_exchange_rate_revaluation, auto_err_frequency, submit_err_jv | boolean/text | | false | hidden, out of scope |
| exception_budget_approver_role | text → roles | | null | Budgeting (P7) |
| **Buying and Selling tab** | | | | |
| default_selling_terms_id, default_buying_terms_id | uuid → terms_and_conditions | | null | |
| default_warehouse_for_sales_return_id | uuid → warehouse | | null | |
| default_sales_contact_id | uuid → contact | | null | |
| monthly_sales_target | numeric | | 0 | Dashboard tab |
| total_monthly_sales, sales_monthly_history, transactions_annual_history | numeric / jsonb | | | read-only caches refreshed by daily job (`cache_companies_monthly_sales_history`) |
| **Stock and Manufacturing tab** | | | | |
| enable_perpetual_inventory | boolean | | **true** | wizard passes 1; disabling blocked when SLEs exist |
| enable_item_wise_inventory_account | boolean | | false | hidden |
| default_inventory_account_id | uuid → account | | `Stock In Hand - ABBR` | only when perpetual |
| stock_adjustment_account_id | uuid → account | | `Stock Adjustment - ABBR` | |
| stock_received_but_not_billed_id | uuid → account | | `Stock Received But Not Billed - ABBR` | |
| stock_delivered_but_not_billed_id, enable_stock_delivered_but_not_billed, disable_sdbnb_in_sr | uuid / boolean | | `Stock Delivered But Not Billed - ABBR` / false / false | SDBNB feature off by default; account still wired |
| default_purchase_price_variance_account_id, default_manufacturing_variance_account_id, purchase_expense_account_id, purchase_expense_contra_account_id, service_expense_account_id, expenses_added_to_stock_account_id, expenses_added_to_stock_contra_account_id, enable_provisional_accounting_for_non_stock_items, default_provisional_account_id | uuid / boolean | | null / false | hidden, out of scope |
| default_operating_cost_account_id | uuid → account | | null | Manufacturing operating cost (falls back to `Expenses Included In Valuation` in posting engine) |
| valuation_method | text check | ✔ | `'FIFO'` | `FIFO \| Moving Average \| LIFO`; cannot change once SLEs exist for items without own method (`cant_change_valuation_method`) |
| default_warehouse_id | uuid → warehouse | | `Stores - ABBR` | all `*_warehouse` fields: non-group, same company (`validate_warehouses`) |
| default_in_transit_warehouse_id | uuid → warehouse | | null | ERPNext leaves null even though `Goods In Transit` exists |
| default_wip_warehouse_id, default_fg_warehouse_id, default_scrap_warehouse_id | uuid → warehouse | | null | Manufacturing defaults (Work Order prompts if empty) |
| sample_retention_warehouse_id | uuid → warehouse | | null | hidden |
| **Assets** (in Accounts tab) | | | | |
| accumulated_depreciation_account_id | uuid → account | | `Accumulated Depreciation - ABBR` | |
| depreciation_expense_account_id | uuid → account | | `Depreciation - ABBR` | |
| series_for_depreciation_entry | text | | null | naming series for depreciation JEs |
| disposal_account_id | uuid → account | | `Gain/Loss on Asset Disposal - ABBR` | |
| depreciation_cost_center_id | uuid → cost_center | | `Main - ABBR` | |
| capital_work_in_progress_account_id | uuid → account | | `CWIP Account - ABBR` | |
| asset_received_but_not_billed_id | uuid → account | | `Asset Received But Not Billed - ABBR` | |

- **Child tables:** none. **Links in:** every company-scoped table.
- **Validations ported:** `validate_abbr`, `validate_default_accounts`, `validate_currency`, `validate_coa_input`, `validate_perpetual_inventory` (block disabling when SLEs exist), `validate_parent_company`, `set_reporting_currency`, `validate_warehouses`, `cant_change_valuation_method`, `validate_sdbnb_configuration` (blocked when outstanding DNs exist on the SDBNB account). Deletion (`on_trash`): only when no `gl_entry`/`stock_ledger_entry` rows; cascades Account, Cost Center, Warehouse, Budget, Mode of Payment Account, Item Default, Department, tax templates. **Deviation:** no demo-company guard.
- **Side effects on insert** (`on_update`): see §3.3.
- **Permissions (JSON):** System Manager rwcd, Accounts Manager rwcd, HR Manager rw; read: Accounts User, Employee, Sales User, Sales Manager, Purchase User, Stock User, Projects User. We seed: System Manager rwcd, Accounts Manager rwcd, read for Accounts User, Sales User/Manager, Purchase User, Stock User, Projects User.
- **List columns:** name, abbr, default_currency, country, is_group.

### 2.2 Branch → `branch`

- **Kind:** master. **Naming:** `field:branch`. No company link in ERPNext.
- Fields: `branch text reqd unique` (= name). No `.py` validation.
- Permissions (JSON): HR User rwcd, HR Manager rwcd — both out of scope; we seed **System Manager rwcd**, read for all standard roles (**Deviation:** HR roles not seeded).
- List: name.
- **Built (0110):** `public.branch (id, org_id, branch)` with `unique (org_id, lower(branch))` (case-insensitive, **Deviation:** ERPNext's name uniqueness is case-insensitive on MariaDB too, so behaviour matches); a `before insert/update` trigger trims the name. Renaming is a plain save (the UUID is the key). Descriptor `src/doctypes/setup/branch.ts`; pgTAP `15_branch.test.sql`; e2e `branch.spec.ts`.

### 2.3 Department → `department`

- **Kind:** tree master (`parent_department`, `is_group`, `path ltree`). **Naming:** `autoname`: `"<department_name> - <abbr>"` when company set, else `department_name` (root `All Departments` has no company). Rename keeps suffix (`before_rename`).
- Source: `erpnext/setup/doctype/department/department.py`.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| department_name | text | ✔ | | |
| parent_id (parent_department) | uuid → department | | root | `validate`: empty parent → root of tree |
| company_id | uuid → companies | ✔ (except root) | | root row `company_id null`, `is_group true` — one per org |
| is_group | boolean | | false | |
| disabled | boolean | | false | tree view hides disabled unless `include_disabled` |

- Permissions (JSON): HR User/HR Manager/Academics User rwcd; read-less rows for Employee, Accounts User, Projects Manager/User, Quality Manager. We seed System Manager rwcd + read for Projects Manager/User and Accounts User (used as a filter dimension on Project/Task).
- List/tree: name, company, is_group.
- **Built (0112):** `public.department` (`department_name`, computed `name`, `parent_id`, `company_id`, `is_group`, `disabled`, `path`) with the `0004` tree triggers, `unique (org_id, name)` and one root per org (`parent_id is null`).
  - `app.department_validate` (security definer) ports `autoname`/`before_rename`/`validate`: trims the name, sets `name = department_name || ' - ' || abbr` on every save (so renames keep the suffix) and an empty parent becomes the root.
  - `app.department_guard` (security invoker, API callers only): non-root departments need a company (`company_required`); the root cannot be changed or deleted (`department_root`). Seeds and cascades bypass it.
  - Seeds: `organizations_seed_department_root` creates "All Departments" (`is_group`); `companies_seed_departments` adds the 13 `create_default_departments` rows under it; the migration backfilled existing orgs and companies.
  - Deleting a company deletes its departments (`on delete cascade`, as `company.py on_trash`). Deleting a group with children fails (self FK).
  - **Deviation:** changing a company's abbreviation re-derives its department names (`companies_rename_departments`); ERPNext keeps the old names.
  - Descriptor `department.ts` with `tree: { parentField: "parent_id", groupField: "is_group", filters: ["company_id"], disabledField: "disabled" }` (Tree view, §8); pgTAP `17_department.test.sql`; e2e `department.spec.ts`.

### 2.4 Designation → `designation`

- **Kind:** master. **Naming:** `field:designation_name`. Fields: `designation_name text reqd unique`, `description text`. No `.py` logic.
- Seeded with 31 rows from `erpnext/setup/setup_wizard/data/designation.txt` (Accountant … Vice President; full list in §3.1 A18).
- Permissions (JSON): HR User rwc, HR Manager rwcd, Sales User r. We seed System Manager rwcd, Sales User r.
- **Built (0111):** `public.designation` with `unique (org_id, lower(designation_name))` and a trimming trigger. `app.seed_designations(org)` inserts the 31 presets (idempotent, `on conflict do nothing`); the `organizations_seed_designations` trigger runs it for every new organization and the migration backfilled existing ones. **Deviation:** ERPNext installs the presets once per site in the setup wizard; we seed per organization at creation (§3.1 A18 is satisfied by the trigger, not the provisioning function). Descriptor `designation.ts`; pgTAP `16_designation.test.sql`; e2e `designation.spec.ts`.

### 2.5 Holiday List → `holiday_list` + child `holiday`

- **Kind:** master with child table. **Naming:** `field:holiday_list_name`. Source: `erpnext/setup/doctype/holiday_list/holiday_list.py`.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| holiday_list_name | text | ✔ | | |
| from_date / to_date | date | ✔ | | `from_date <= to_date` |
| total_holidays | numeric | | computed | Σ (0.5 if `is_half_day` else 1) over rows |
| weekly_off | text check | | '' | Sunday…Saturday; drives "Add Weekly Holidays" action |
| is_half_day | boolean | | false | applied to generated weekly-off rows |
| color | text | | | calendar colour |
| country / subdivision | text | | | for "Add Local Holidays" |

`holiday` (child, `parent_id → holiday_list`, `idx`): `holiday_date date reqd`, `description text reqd`, `weekly_off boolean default false`, `is_half_day boolean default false`.

- Validations ported: dates in range; no duplicate `holiday_date`; rows sorted by `(weekly_off, holiday_date)` and re-indexed; `total_holidays` recomputed. Actions: `get_weekly_off_dates` (append every `weekly_off` weekday between the dates, skipping existing), `clear_table`. `is_holiday(list, date)` / `is_half_holiday()` helpers → `app.is_holiday(holiday_list_id, date)` (used by Workstation/Job Card scheduling in P8).
- **Deviation:** "Add Local Holidays" (python `holidays` package + babel) is replaced by a TS implementation using `date-holidays` for the org's country only; subdivisions optional.
- Permissions (JSON): HR Manager rwcd; read-less rows for HR User, Accounts Manager, Manufacturing User, Projects Manager/User, Sales Manager. We seed System Manager rwcd, read for Manufacturing Manager/User, Projects Manager/User.
- List: name, from_date, to_date, total_holidays.
- **Built (0113):** `public.holiday_list` (name unique per org, `weekly_off` checked against Sunday…Saturday, `color` checked as `#rrggbb`, `country` → `country.country_name`) and child `public.holiday` (`parent_id`, `idx`, composite FK to the parent with cascade).
  - `app.holiday_list_validate` (before trigger) trims the name, stores an empty weekly off as null and raises `holiday_dates` when To Date is before From Date.
  - `app.holiday_list_refresh(list)` ports `validate_days` / `sort_holidays` / `total_holidays`: raises `holiday_out_of_range` and `holiday_duplicate`, re-indexes the rows by `(weekly_off, holiday_date)` and recomputes `total_holidays` (half days count 0.5). It runs from **deferred constraint triggers** on the header and the rows, so the whole document (header + rows written by `save_doc`) is checked once at commit.
  - `app.is_holiday(list, date)` / `app.is_half_holiday(list, date)` (executable by `authenticated`).
  - `companies.default_holiday_list_id` gets its FK (`companies_default_holiday_list_fkey`, same org; deleting a list in use fails) and the Company form shows it.
  - Form actions (client-side, they only edit the unsaved form; `src/lib/holidays.ts`): *Add Weekly Holidays* (`get_weekly_off_dates`: every `weekly_off` weekday in range, skipping existing dates, flagged `weekly_off` + `is_half_day`; "Please select weekly off day." when empty), *Add Local Holidays* (`get_local_holidays`, Server Action `getLocalHolidays` with `date-holidays`, public holidays in English, skipping existing dates, at most 10 years), *Clear Table*.
  - **Deviation:** Add Local Holidays uses the list's `country` (codes from `country.code`) and optional `subdivision` with the `date-holidays` package instead of Python `holidays` + babel; holiday names are English only.
  - **Deviation:** no calendar view yet; `color` is stored for the P8 scheduling calendar.
  - Descriptor `holiday-list.ts`; pgTAP `18_holiday_list.test.sql`; e2e `holiday-list.spec.ts`.

### 2.6 User → `auth.users` + `user_profile` + `org_members`

Frappe `User` is a site-wide record with roles; in our model identity is global (Supabase Auth) and membership + roles are per org (`01-tenancy-auth-rls.md`).

| Frappe User field | Ours | notes |
|---|---|---|
| email, enabled | `auth.users.email`, `org_members.status` (`active \| invited \| disabled`) | disabling is per org |
| first_name, last_name, full_name, user_image, language, time_zone | `user_profile(user_id pk → auth.users, first_name, last_name, full_name generated, avatar_url, language default org language, time_zone default org tz)` | one row per auth user; RLS: self rw, members of a shared org r |
| user_type (System User / Website User) | implicit: every member is a "System User" | portal users out of scope |
| roles (Has Role) | `org_members.roles text[]` | validated against `roles(org_id, name)` by trigger |
| role_profile_name | `org_members.role_profile text null → role_profile` | assigning a profile replaces `roles` with the profile's roles (Frappe behaviour) |
| module_profile, block_modules | — | **Deviation:** module visibility derives from permissions only |
| new_password / reset | Supabase Auth flows | |
| `hooks.py doc_events.User.after_insert → update_contact` | trigger: when a `contact.email_id` matches a new member's email, set `contact.user_id` | |

- Owner (`org_members.is_owner`) always holds System Manager and cannot be removed/disabled.
- List columns: full_name, email, roles (chips), status, last_sign_in_at.
- **Built (P1, `0106_setup_users.sql`):**
  - `app.org_member_directory(p_org)` (security definer, called through the security-invoker `public.org_member_directory`) joins `org_members` with `auth.users` (email) and `user_profile`. It returns rows only to active members of `p_org`; `last_sign_in_at` is filled only for System Managers. Owner first, then by name.
  - Removing a member (deleting the `org_members` row) deletes their `user_permissions` in that org (Frappe `User.on_trash`); the auth user stays.
  - User permissions: System Manager rwcd (Frappe `user.json`), locked like the other Access doctypes (§2.7). Writes to `org_members` are authorized by RLS (System Manager) and validated by `org_members_validate` (`owner_protected`, `invalid_role`).
  - Disabling sets `status = 'disabled'`: roles are kept, and `app.is_member` / `user_org_ids` stop counting the membership, so the org disappears for that user.
  - Server Actions `src/lib/actions/setup/users.ts`: `updateMemberRoles` (profile or hand-picked roles), `setMemberStatus`, `removeMember`. A user's JWT catches up with role changes through `ClaimsRefresher` on their next page load.
  - Frappe User behaviour above is ported from memory (no local Frappe clone).

### 2.7 Role → `roles`; Role Profile → `role_profile`

- `roles(org_id, name, is_standard boolean, disabled boolean default false, is_custom boolean generated as not is_standard)`; pk `(org_id, name)`. Frappe fields `desk_access`, `two_factor_auth`, `restrict_to_domain`, `home_page` are dropped (**Deviation**: no desk/website split, no 2FA per role).
- Standard roles seeded (01 doc): System Manager, Accounts Manager, Accounts User, Auditor, Sales Manager, Sales User, Purchase Manager, Purchase User, Stock Manager, Stock User, Item Manager, Manufacturing Manager, Manufacturing User, Projects Manager, Projects User, Maintenance Manager, Maintenance User, Quality Manager, Employee. ERPNext-specific roles created in `install.py` and **not** seeded: Analytics, Shop Floor Manager/User, Customer, Supplier (website roles).
- `role_profile(org_id, name, roles text[])`, seeded from `erpnext/setup/install.py: DEFAULT_ROLE_PROFILES`:

| Profile | Roles |
|---|---|
| Inventory | Stock User, Stock Manager, Item Manager |
| Manufacturing | Stock User, Manufacturing User, Manufacturing Manager |
| Accounts | Accounts User, Accounts Manager |
| Sales | Sales User, Stock User, Sales Manager |
| Purchase | Item Manager, Stock User, Purchase User, Purchase Manager |

- Permissions: System Manager rwcd on roles/role_profile; everyone read.
- **Built (P1, `0105_setup_roles.sql`):** both tables gained a uuid `id` (`unique (org_id, id)`; the primary key stays `(org_id, name)`), so they use the generic list/form at `/setup/roles` and `/setup/role-profile` (descriptors `src/doctypes/setup/role.ts`, `role-profile.ts`; `roles` is a `MultiSelect` over the org's enabled roles). Rules:
  - Standard roles cannot be renamed or deleted and their `is_standard` flag cannot change (`role_standard`); roles created through the API are never standard. System Manager cannot be disabled (`role_protected`). Frappe protects only Administrator/Guest/All/Desk User; we protect every seeded role because provisioning and the permission templates refer to them by name.
  - Renaming a custom role rewrites it in `role_profile.roles`, `org_members.roles` and `invitations.roles`; deleting strips it. `role_permissions` and the Company role columns follow through their foreign keys.
  - Profile roles are de-duplicated (order kept) and must exist (`invalid_role`). Saving a profile re-syncs every member holding it (Frappe `RoleProfile.on_update`), and a member with a profile always carries exactly its roles: assigning roles by hand means clearing the profile in the same update (Frappe `User.validate`).
  - Permissions for the Access doctypes (User, Role, Role Profile, User Permission) are fixed to System Manager: their `role_permission_template` rows are seeded, RLS checks the System Manager role, and any API change to their `role_permissions` rows raises `permission_locked`.
  - **Deviation:** disabling a role keeps it on members and profiles (the permission helpers ignore disabled roles), so enabling it again restores access; Frappe deletes the Has Role rows. Reason: reversible, no data loss.
  - Frappe Role / Role Profile / User behaviour above is ported from memory (no local Frappe clone).

### 2.8 Role Permission Manager → `role_permissions`

- Table per 01 doc: `(org_id, role, doctype, can_read, can_write, can_create, can_submit, can_cancel, can_amend, can_delete, can_report default true, can_export default true, if_owner default false)`, pk `(org_id, role, doctype)`. Only `permlevel 0` is ported (**Deviation**: no field-level permlevels, no `set_user_permissions`/`share`/`print`/`email`/`import` flags — print/email allowed whenever `can_read`).
- Seeded per org from `supabase/seed/role_permissions.json` (extracted from every in-scope doctype JSON `permissions[]`). System Manager rows are seeded for all doctypes.
- Editing: System Manager only.
- UI: matrix page (§8).
- **Built (P1, `0108_setup_role_permission_manager.sql`):**
  - Edits are plain RLS writes on `role_permissions` (System Manager policies from `0002`); a before insert/update trigger (API callers only) ports Frappe `validate_permissions`: `doctype_unknown` (missing or child doctype), `perm_not_submittable` (Submit/Cancel/Amend on a non-submittable doctype), `perm_dependency` (Submit/Cancel/Amend need Write, Cancel needs Submit, Amend needs Cancel). The matrix applies the same dependencies when a box is ticked or cleared (`permToggle` in `src/lib/role-permissions.ts`), so the trigger only fires for crafted requests.
  - `app.reset_role_permissions(org, doctype)` → count: System Manager only (42501), refuses the Access doctypes (`permission_locked`); deletes the doctype's rows and re-inserts them from `role_permission_template` for roles that exist in the org. Scope is one doctype, like Frappe's reset.
  - `public.permission_doctypes()` lists non-child doctypes with module, `is_submittable` and `locked` (`app.locked_permission_doctypes()`).
  - Permissions are read live by `app.has_perm`, so no token refresh is needed after an edit (the JWT carries roles, not permissions).

### 2.9 User Permission → `user_permissions`

Frappe fields → columns: `user → user_id`, `allow (DocType) → doctype text`, `for_value (Dynamic Link) → record_id uuid`, `apply_to_all_doctypes (default 1) / applicable_for → applicable_for text null` (null = all), `is_default boolean default false`, `hide_descendants boolean default false` (tree doctypes). Unique `(org_id, user_id, doctype, record_id, coalesce(applicable_for,''))`.

- Honoured by `app.record_allowed()` / `app.company_allowed()` in RLS. Allowed `doctype` values in P1: Company, Warehouse, Cost Center (others added as their tables land; the picker lists `doctype_meta` rows flagged `user_permission_target`).
- `is_default`: pre-fills the link field in new documents (session default), mirrors Frappe.
- Permissions: System Manager rwcd. List: user, doctype, record (title), applicable_for, is_default.
- **Built (P1, `0109_setup_user_permissions.sql`):**
  - Validation trigger (every caller; security definer so a System Manager restricted to some companies can still grant others): `user_not_member`, `doctype_not_allowed` (not a `user_permission_target`), `record_unknown` (no such record in the org), `applicable_for_unknown` (blank → null = all document types), `default_exists` (one default per user and doctype, Frappe `validate_default_permission`); duplicates hit the unique index (`duplicate`). `hide_descendants` is forced off for non-tree doctypes.
  - Descendants: on a tree doctype (`doctype_meta.is_tree`, `path` ltree) a permission allows the record and everything below it, unless `hide_descendants` (Frappe `get_user_permissions`). Company is the only target in P1; Warehouse and Cost Center become targets with their P2 tables.
  - `applicable_for`: rows with a value only restrict that doctype; when RLS checks a doctype's own records (e.g. the Company list) it uses the rows for all doctypes plus the rows applicable to that doctype. If no row applies, the user is unrestricted.
  - Non-strict mode (ERPNext `build_qb_match_conditions` default): documents whose link is empty stay visible; transaction policies (P3+) will pass `company_allowed(org_id, company_id, '<Doctype>')` and allow null links.
  - `is_default` on Company picks the top-bar company when the user has no `hx_company` cookie (`[org]` layout). Defaults for other link fields come with the transaction forms.
  - UI: descriptor `src/doctypes/setup/user-permission.ts` on the generic list/form (`/setup/user-permissions`): User is a Link over the members, Allow a Select of the target doctypes, For Value a Dynamic Link, Hide Descendants shown for tree targets only. The member panel lists the member's rows with "Add user permission" (opens the form with `?user_id=` prefilled).

### 2.10 Authorization Rule → `authorization_rule` (simplified port)

ERPNext behaviour (`erpnext/setup/doctype/authorization_rule/authorization_rule.py`, `authorization_control.py`): rules per `transaction` (SO, PO, Quotation, DN, SI, PI, PR) `based_on` Grand Total / Average Discount / Customerwise Discount / Itemwise Discount / Item Group wise Discount, optional `company`, threshold `value`, "applicable to" (`system_role` or `system_user`, or neither = global), and "approver" (`approving_role` or `approving_user`). `validate_approving_authority(doctype, company, total, doc)` runs at submit: it evaluates user-specific rules first, then role-specific rules, then global rules; for each, it finds rules whose `value <= total` (company-specific rules take precedence over company-less ones), then collects approvers of the rules with the largest threshold, and throws `Not authorized since Grand Total exceeds limits` / `Can be approved by <roles/users>` unless the current user holds an approving role or is the approving user. Validations on the rule: approver required; approver ≠ applicable user/role; discount bases not allowed for purchase doctypes; Average Discount ≤ 100; Customerwise Discount needs a customer; duplicate rule check on (transaction, based_on, system_user, system_role, approving_user, approving_role, to_emp, to_designation).

**Our port (P1 table + UI, enforcement hooked into `app.submit_doc` in P5/P6):**

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| transaction | text check | ✔ | | `Sales Order \| Purchase Order \| Sales Invoice \| Purchase Invoice` (**Deviation:** Quotation/DN/PR dropped) |
| based_on | text check | ✔ | `'Grand Total'` | only `Grand Total` (**Deviation:** discount-based rules dropped — Pricing Rules out of scope) |
| company_id | uuid → companies | | null | null = all companies |
| value | numeric(21,9) | | 0 | threshold in company currency |
| system_role | text → roles | | null | applicable to role |
| system_user | uuid → auth.users | | null | applicable to user |
| approving_role | text → roles | | null | one of approving_role/approving_user required |
| approving_user | uuid → auth.users | | null | |

Naming: `HR-ARU-.#####` (ERPNext `autoname`); we keep the same series. Fields `to_emp`, `to_designation`, `master_name`, `customer_or_item` are dropped (Employee/expense-claim path). Enforcement `app.validate_approving_authority(doctype, company_id, grand_total, user)` replicates the user → role → global precedence and the company-specific-first lookup; message texts copied.

- Permissions: System Manager rwcd. List: transaction, based_on, company, value, approving_role/user.
- **Built (P1, `0125_setup_authorization_rule.sql`, descriptor `authorization-rule.ts`):** `public.authorization_rule` with composite FKs to `companies` and `roles` (deleted roles clear the field), `system_user` / `approving_user` → `auth.users` (deleted users clear the field; both must be members). `system_user` is a reserved word since Postgres 16, so DDL quotes it; the column keeps the ERPNext name. `app.authorization_rule_validate` issues the name from `HR-ARU-.#####` (write-once), runs `check_duplicate_entry` (null-safe on the applicable/approving fields, `duplicate:` names the existing rule) and `validate_rule` (`approver_required`, `approving_user_same`, `approving_role_same`, messages copied); cascaded FK updates skip validation. `app.validate_approving_authority(doctype, company_id, total, user)` (definer, not callable by API roles) ports `validate_approving_authority`: user rules if the user has any for the transaction, else rules for the user's roles, else global rules; per level the largest threshold ≤ total (company rules first, then company-less) selects the approvers of rules at that threshold or above the total; raises `not_authorized: Not authorized since Grand Total exceeds limits. Can be approved by <roles/emails joined with "or">`. Wired into submit in P5/P6. pgTAP `29_authorization_rule`, e2e `authorization-rule.spec.ts`.

### 2.11 Letter Head → `letter_head`

Frappe doctype; ERPNext adds `Company.default_letter_head` / `default_letter_head_report`.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| letter_head_name | text | ✔ | | = name |
| source | text check | | `'HTML'` | `HTML \| Image` |
| content | text (html) | | | header HTML when source = HTML |
| image | text (storage path) | | | header image when source = Image |
| image_height / image_width | numeric | | | px |
| align | text check | | `'Left'` | `Left \| Right \| Center` |
| footer_source | text check | | `'HTML'` | |
| footer | text (html) | | | |
| footer_image | text (storage path) | | | |
| is_default | boolean | | false | exactly one default per org (trigger unsets others — Frappe `set_as_default`) |
| disabled | boolean | | false | |

- Frappe `header_script` / `footer_script` dropped (**Deviation:** no arbitrary JS in prints). HTML is sanitised server-side (allow-list: block/inline formatting, img, table).
- Print route resolution: document `letter_head` field → company `default_letter_head` → org default (`is_default`) → none.
- Permissions: System Manager rwcd, all roles read. List: name, source, is_default, disabled.
- **Built (0118):** `public.letter_head` (name unique per org, case-insensitive; `source` / `footer_source` `HTML|Image`; `align` / `footer_align` `Left|Right|Center`; image paths must start with `<org_id>/letter-head/`; partial unique index = one default per org).
  - `app.letter_head_validate` (before trigger) ports `validate_disabled_and_default` (`letter_head_disabled_default`: "Letter Head cannot be both disabled and default"), the "first enabled letter head becomes the default" rule, and `set_as_default` (setting `is_default` clears the org's previous default).
  - `companies.default_letter_head_id` gets its FK (`companies_default_letter_head_fkey`, same org, `on delete set null (default_letter_head_id)`, so deleting a letter head clears the company link) and the Company form shows it.
  - Images live in the private `org-files` storage bucket (created by the migration; see `docs/architecture/02-database-conventions.md`), uploaded through the `AttachImage` field and shown with signed URLs.
  - Header/Footer HTML are `html: true` Text fields: `saveDoc` sanitizes them with `src/lib/html/sanitize.ts` (`sanitize-html` allow-list). The form shows a live A4 preview (unsaved HTML in a sandboxed frame without scripts).
  - Frappe `footer_image_height`, `footer_image_width` and `footer_align` are kept alongside the header ones.
  - **Deviation:** Frappe stores the generated `<img>` HTML in `content` when the source is Image; we keep the image fields and render them at print time. `default_letter_head_report` (report prints) is not ported.
  - **Deviation:** Frappe Letter Head ported from memory (the frappe repo is not cloned locally).
  - Descriptor `letter-head.ts`; pgTAP `22_letter_head.test.sql`; Vitest `sanitize.test.ts`; e2e `letter-head.spec.ts`.

### 2.12 Print Format → `print_format`

ERPNext ships Jinja/JS print formats and `install.py: set_default_print_formats()` makes `"<Doctype> Classic"` the default for Sales Order, Sales Invoice, Delivery Note, Purchase Order, Purchase Invoice, POS Invoice, Quotation, Request for Quotation. Per `docs/architecture/05-ui-ux.md` we ship **one modern server-rendered default format per transaction doctype**, rendered at `/print/[doctype]/[id]` with the resolved Letter Head.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| name | text | ✔ | | e.g. `Sales Invoice Standard` |
| doc_type | text → doctype_meta | ✔ | | |
| template_key | text | ✔ | | key into `src/print/templates/*.tsx` (`standard`, later `compact`) |
| is_standard | boolean | | true | standard rows are seeded, not editable |
| is_default | boolean | | | one per `(org_id, doc_type)` |
| options | jsonb | | `{}` | per-format overrides of Print Settings (e.g. `show_item_code`, `group_taxes`) |
| disabled | boolean | | false | |

- **Deviation:** no Print Format Builder / HTML editing / raw printing in P1 (Frappe `html`, `css`, `format_data`, `print_format_type`, `raw_printing` dropped). Custom formats = future work.
- Doctypes that need a standard format (seeded as modules land): Quotation, Sales Order, Delivery Note, Sales Invoice (P5); Material Request, Request for Quotation, Supplier Quotation, Purchase Order, Purchase Receipt, Purchase Invoice (P4/P6); Payment Entry, Journal Entry (P3); Stock Entry, Stock Reconciliation (P4); BOM, Work Order, Job Card, Subcontracting Order, Subcontracting Receipt (P8); Timesheet (P9); Asset (P10). Masters print via a generic "record" template.
- Permissions: System Manager rwcd, all read.
- **Built (0120):** `public.print_format` (name unique per org, case-insensitive; `doc_type` → `doctype_meta`; `template_key` default `record`; `options` jsonb object; partial unique index = one default per `(org_id, doc_type)`).
  - `app.print_format_validate` (before trigger, security invoker so `current_user` tells API callers from the system): API roles cannot create standard rows; standard rows keep their name, doctype, template and options (only Default and Disabled change; `print_format_standard`); `doc_type` must be printable (`print_format_doc_type`); a disabled format cannot be the default (`print_format_disabled_default`); a new default clears the previous one (`app.print_format_clear_default`). Standard rows cannot be deleted.
  - `app.is_printable(doctype)`: organization doctypes (table with `org_id`) that are neither child tables nor singles, except User (members) and Print Format.
  - `app.seed_print_formats(org, doctype?)` creates `"<Doctype> Standard"` (`template_key = 'record'`, standard, default when the doctype has none). Run by an `organizations` insert trigger (Stage A4), by an `after insert on doctype_meta` trigger (doctypes registered by later migrations get their format in every org, so module migrations need no extra step) and by the backfill.
  - Descriptor `print-format.ts`: list (name, doctype, template, default, disabled) and form; Template options come from `src/print/template-keys.ts`.
  - **Print route** `src/app/(print)/print/[doctype]/[id]/page.tsx` (outside the app shell, `[doctype]` = descriptor slug): the record is read with the user's client, so missing and other organizations' records render the 404 page. Format = `?format=<id>` when enabled, else the doctype's default (`pickPrintFormat`); the template comes from `src/print/registry.tsx`. Letter head (`resolveLetterHeadId` in `src/lib/print/resolve.ts`): document `letter_head_id` → company `default_letter_head_id` (the company itself when printing a Company) → Print Settings `letter_head_id` → org default; none when `with_letterhead` is off; disabled letter heads are skipped. Header/footer HTML is sanitized again at render; images use signed URLs.
  - Print Settings applied: `font_size` (pt) and `font`, `@page { size }` from `pdf_page_size` (Custom = width × height mm), "Draft" heading on submittable drafts (`add_draft_heading`), `allow_print_for_draft` / `allow_print_for_cancelled` ("Not allowed to print draft/cancelled documents" instead of the page).
  - Toolbar (screen only): back to the form, Print Format picker, Print (`window.print()`). `DocForm`'s "More actions" menu has **Print**, which opens the route in a new tab.
  - Generic template `src/print/templates/record.tsx`: the descriptor's tabs → sections → columns, fields with a value only (Check prints Yes/No, Links print the target's title, numbers grouped), child tables as tables.
  - **Deviation:** `repeat_header_footer`, `allow_page_break_inside_tables`, `compact_item_print` and PDF generation (`send_print_as_pdf`) wait for the transaction templates and the Email track; the browser's print dialog produces the PDF.
  - **Deviation:** Frappe Print Format ported from memory (the frappe repo is not cloned locally); ERPNext `set_default_print_formats` ("<Doctype> Classic" for 8 transactions) becomes a "<Doctype> Standard" default for every printable doctype.
  - pgTAP `24_print_format.test.sql`, `21_provision_organization` asserts the seeded formats; Vitest `resolve.test.ts`; e2e `print.spec.ts`.

### 2.13 Print Settings → `print_settings` (single, per org)

Frappe single + ERPNext custom fields from `erpnext/setup/install.py: create_print_setting_custom_fields()`.

| fieldname | type | default | notes |
|---|---|---|---|
| print_style | text | `'Modern'` | we support `Modern` only (**Deviation**) |
| font | text | `'Default'` | |
| font_size | integer | 9 | Frappe default |
| pdf_page_size | text | `'A4'` | `A4 \| Letter \| Legal \| Custom`; `pdf_page_height/width` for Custom |
| with_letterhead | boolean | true | |
| letter_head_id | uuid → letter_head | null | default letter head override |
| allow_print_for_draft | boolean | true | |
| allow_print_for_cancelled | boolean | false | |
| add_draft_heading | boolean | true | "DRAFT" watermark |
| allow_page_break_inside_tables | boolean | false | |
| repeat_header_footer | boolean | true | |
| send_print_as_pdf | boolean | false | attach PDF when emailing (we always attach PDF link; flag kept) |
| attach_view_link | boolean | true | |
| **compact_item_print** (ERPNext) | boolean | **true** | hides item code/description columns duplication in item tables |
| **print_uom_after_quantity** (ERPNext) | boolean | **false** | render `10 Nos` |
| **print_taxes_with_zero_amount** (ERPNext) | boolean | **false** | |

- Permissions: System Manager rw. Rendered with `SettingsPage`.
- **Built (0119):** `public.print_settings`, one row per org seeded by `app.organizations_seed_print_settings` (after insert on `organizations`, Stage A4 of provisioning) plus a backfill; `doctype_meta.is_single`.
  - Checks: `print_style = 'Modern'`; `pdf_page_size` in `A4|Letter|Legal|Custom`, with `pdf_page_height` / `pdf_page_width` (mm) required for Custom (`print_settings_custom_size`); `font_size` 6–24.
  - `letter_head_id` → `letter_head` of the same org (`on delete set null (letter_head_id)`).
  - RLS: every member reads (the print route applies the settings), System Manager writes; no insert/delete.
  - Descriptor `print-settings.ts` (`single: true`) on the generic single route, sections PDF Settings / Page Settings / Print Style as in Frappe; `font` offers Frappe's font list.
  - **Deviation:** print server / raw printing fields (`enable_print_server`, `enable_raw_printing`, …) are not ported; Frappe's global default letter head is `letter_head_id` here.
  - **Deviation:** Frappe Print Settings ported from memory (the frappe repo is not cloned locally); ERPNext custom fields from `erpnext/setup/install.py` `create_print_setting_custom_fields`.
  - pgTAP `23_print_settings.test.sql`, `21_provision_organization` asserts the seeded row; e2e `print-settings.spec.ts`.

### 2.14 Email Account → `email_account` (outbound only)

Frappe `Email Account` plus ERPNext custom field `company` (`install.py: create_custom_company_links()`). Inbound (IMAP/POP, auto-reply, append-to) is **out** (PLAN §4).

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| email_account_name | text | ✔ | | = name |
| email_id | text | ✔ | | sender address; must be a verified domain/sender at the provider |
| company_id | uuid → companies | | null | ERPNext custom field; null = org-wide |
| provider | text check | ✔ | `'resend'` | `resend` only for now; `smtp` deferred (**Deviation:** Frappe `service` presets replaced) |
| api_key_secret | uuid → vault.secrets | | | Resend API key stored in Supabase Vault; `has_api_key` (generated) shows whether one is saved |
| smtp_server, smtp_port, use_tls, use_ssl_for_outgoing, login_id, password_secret, no_smtp_authentication | text / int / bool / uuid | | 587 / true / false | SMTP branch (deferred, not built) |
| enable_outgoing | boolean | | true | |
| default_outgoing | boolean | | | one per org (trigger) |
| always_use_account_email_id_as_sender | boolean | | false | else Reply-To = the sending user's email (From stays the account address) |
| always_use_account_name_as_sender_name | boolean | | false | else the display name is the sending user's |
| add_signature / signature | boolean / text (html) | | false | |
| footer | text (html) | | null | appended to every email from the account |
| send_unsubscribe_message | boolean | | true | dropped (no bulk mail) |
| track_email_status | boolean | | true | dropped (no provider webhooks yet) |
| enabled | boolean | | true | |

- Resolution (Frappe `get_outgoing_email_account`): the document's company account, then the org's default outgoing account, then the platform sender (`RESEND_API_KEY` + `EMAIL_FROM`, also used for invitations).
- Permissions: System Manager rwcd. List: name, email_id, company, provider, default_outgoing.
- **Built (P1, `0123_setup_email_account.sql`, descriptor `email-account.ts`):**
  - `app.email_account_validate` trims, lower-cases and format-checks `email_id` (`invalid_email`), rejects a default outgoing account that is disabled or has outgoing off (`email_default_disabled`), and clears the previous default. Unlike Letter Head, the first account is not made the default automatically.
  - The key is write-only. `public.set_email_account_key(p_id, p_secret)` (definer, needs Email Account write) creates or updates the Vault secret. `save_doc` cannot change `api_key_secret` (the trigger keeps the stored id), and deleting an account deletes its secret.
  - `public.email_sender(p_org, p_company, p_account)` returns the resolved account with its decrypted key. Only `service_role` can execute it. Accounts without a saved key are skipped.
  - `email_log` records every send (`Sent` / `Error`, provider message id, reference document, `sent_by`). It is append-only: no role can update or delete rows, and only the service role inserts. System Managers read the org's rows; other users read the rows they sent.
  - The app sends from a server-only module, not an Edge Function. `src/lib/email/transport.ts` posts to the Resend API (`EMAIL_DRY_RUN=1` returns a fake id and sends nothing). `src/lib/email/sender.ts` (`resolveSender`, `deliver`) is the only code that reads credentials, using the service-role client.
  - Form: the generic `Password` field type (never pre-filled, kept out of the `save_doc` payload, saved through the descriptor's `secretRpc` after the document is saved) and a "Send Test Email" action that sends through the account to the signed-in user.
  - pgTAP `27_email_account`, Vitest `transport.test.ts` / `sender.test.ts`, e2e `email-account.spec.ts` (dry run).

### 2.15 Email Template → `email_template`

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| name | text | ✔ | | prompt naming |
| subject | text | ✔ | | |
| use_html | boolean | | true | |
| response_html | text (html) | | | body |
| response | text | | | plain-text fallback (Frappe `response` Text Editor) |

- Placeholders: handlebars-style subset `{{doc.<field>}}`, `{{doc.<child>[0].<field>}}`, `{{company.<field>}}`, `{{user.full_name}}` with helpers `money`, `date`, `qty` (**Deviation:** Frappe renders full Jinja with `restrict_globals`). Validation: compile the template on save, reject unknown helpers.
- Seeded per org: none of ERPNext's (`Dispatch Notification` belongs to Delivery Trip, out of scope). App-level (non-org) templates: `Invitation`, `Send Document` (used by the form "Email" action with subject `{{doc.doctype}} {{doc.name}}`).
- Permissions: System Manager rwcd; Sales/Purchase/Accounts Manager rw, all read.
- **Built (P1, `0124_setup_email_template.sql`, descriptor `email-template.ts`):**
  - Table with trims, a non-empty subject, and names unique per org (case-insensitive; the name is set once). Permissions as above: the 19 standard roles read, the three managers also write, and only System Manager creates and deletes.
  - `src/lib/email/render.ts`: `compileTemplate` / `renderTemplate`. Placeholders are `{{doc.x}}`, `{{doc.items[0].x}}`, `{{company.x}}` and `{{user.full_name}}`, optionally with one helper (`money`, `date`, `qty`). `money` uses `doc.currency`, then the company's default currency. Missing values and objects render as empty. HTML output escapes every value. Unknown helpers or roots, `{{#blocks}}`, filters and unbalanced `{{ }}` are errors.
  - The descriptor's `validate` hook compiles the subject and both bodies; the client resolver and `saveDoc` share it, so errors land on the field. `response_html` is sanitized on save like other HTML fields.
  - Live preview (`preview: "EmailTemplate"`): subject and body rendered against a sample Sales Invoice; the HTML body is shown in a sandboxed frame, and compile errors are shown in place.
  - App-level templates live in code (`src/lib/email/templates.ts`): `Invitation` and `Send Document` (subject `{{doc.doctype}} {{doc.name}}`).
  - pgTAP `28_email_template`, Vitest `render.test.ts`, e2e `email-template.spec.ts`.
- **Built — form "Email" action** (Frappe `CommunicationComposer` / `make`): saved, non-single documents get **Email** in the form's More menu. The compose dialog (`email-dialog.tsx`) has To, CC, a template picker (Send Document by default, plus the org's templates), Subject and an HTML Message. Defaults come from `getEmailDraft`, which reads the record with RLS (no access = not found) and renders the template with `doc` = the record plus `doctype`, `name` and `print_url`, `company` = the record's company (or the Company itself), and `user` = the sender. To defaults to the record's `contact_email` / `email_id` / `email`. `sendDocumentEmail` re-reads the record, validates up to 20 addresses, sanitizes the message, sends through `resolveSender(org, company)` (company account, else org default, else the platform sender) and logs to `email_log` against the record. e2e `email-send.spec.ts` (dry run).

### 2.16 Email Digest → `email_digest` + child `email_digest_recipient`

Source: `erpnext/setup/doctype/email_digest/email_digest.py`. Scheduled by `hooks.py scheduler_events.daily_maintenance → email_digest.send`.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| name | text | ✔ | | prompt |
| enabled | boolean | | false | |
| company_id | uuid → companies | ✔ | | |
| frequency | text check | ✔ | | `Daily \| Weekly \| Monthly` |
| next_send | date | | computed | `get_next_sending()`; shown as "<date> at midnight" |
| income, expenses_booked, income_year_to_date, expense_year_to_date, bank_balance, credit_balance, invoiced_amount, payables, sales_orders_to_bill, purchase_orders_to_bill, sales_order, purchase_order, sales_orders_to_deliver, purchase_orders_to_receive, sales_invoice, purchase_invoice, new_quotations, pending_quotations | boolean ×18 | | false | accounting/transaction cards |
| project, purchase_orders_items_overdue | boolean | | false | list sections |
| issue, calendar_events, todo_list, notifications, add_quote | — | | | **Deviation:** dropped (Support / Frappe desk features) |

`email_digest_recipient` (Table MultiSelect): `parent_id → email_digest`, `user_id → auth.users` (must be an active org member at send time — ERPNext checks `User.enabled`).

Period logic (`get_from_to_date` / `set_dates`): Daily → period = yesterday, past = day before; Weekly → previous Monday–Sunday, past = the week before; Monthly → previous calendar month, past = the month before. `get_next_sending()`: send_date = to_date + 1 day; `next_send` = send_date + 1 day / 1 week / 1 month. The job runs daily and sends when `today == send_date`. Subject `"<Frequency> Digest"`; title `Daily Reminders / This Week's Summary / This Month's Summary`.

Card definitions (each returns `label, value, last_value, count` and the renderer shows `diff = (value − last_value)/last_value × 100`):

| key | source |
|---|---|
| income / expenses_booked | Σ balance change of Income / Expense root accounts in period vs past period (`get_incomes_expenses_for_period`, FY-aware) |
| income_year_to_date / expense_year_to_date | Σ `get_balance_on(account, to_date, start_date = FY start)` over non-group Income / Expense accounts |
| bank_balance / credit_balance | Σ balances of `account_type = Bank` accounts with `root_type = Asset` / `Liability` (credit shown × −1) |
| invoiced_amount / payables | Σ balances of `account_type = Receivable` / `Payable` accounts |
| sales_orders_to_bill / sales_orders_to_deliver | Σ `grand_total × (1 − per_billed/100)` / `(1 − per_delivered/100)` of SOs dated ≤ to_date, status ∉ {Closed, Cancelled, Completed}, billing/delivery status ≠ Fully Billed/Delivered |
| purchase_orders_to_bill / purchase_orders_to_receive | same on PO with `per_billed` / `per_received` |
| sales_order, purchase_order, sales_invoice, purchase_invoice, new_quotations | Σ `grand_total` + count in period (SI/PI by `posting_date`, others `transaction_date`), status ≠ Cancelled, vs past period |
| pending_quotations | Σ `grand_total` of Quotations ≤ to_date with status ∉ {Ordered, Cancelled, Lost} vs ≤ past_to_date |
| project | Open projects with `project_type = External` (first 10, count) |
| purchase_orders_items_overdue | PO items with `schedule_date < today`, `received_qty < qty`, PO status ≠ Closed, grouped by PO |

Implementation: `app.email_digest_payload(digest_id) returns jsonb` computes all cards (24h cache per card key in ERPNext → we use no cache); Edge Function `send-email-digest` (pg_cron daily 00:30 org-local) renders the HTML and sends via the company's email account.

- Permissions: System Manager rwcd. List: name, company, frequency, enabled, next_send.

### 2.17 Global Defaults → `global_defaults` (single, per org)

Source: `erpnext/setup/doctype/global_defaults/global_defaults.json`, `.py`.

| fieldname | type | default | notes |
|---|---|---|---|
| default_company_id | uuid → companies | first company | session default |
| country | text → country | org country | |
| default_currency | text → currency | org currency (ERPNext JSON default `INR`) | enabling it sets `currency.enabled` in ERPNext; ours: `org_currency` row |
| default_distance_unit | text → uom | null | Delivery Trip only; kept |
| hide_currency_symbol | boolean | false | |
| disable_rounded_total | boolean | false | hides `rounded_total` on QTN/SO/SI/DN/SQ/PO/PI/PR and sets their `disable_rounded_total` default (`toggle_rounded_total`) |
| disable_in_words | boolean | false | hides `in_words` (`toggle_in_words`) |
| use_posting_datetime_for_naming_documents | boolean | **true** | `.YYYY.`/`.MM.` tokens use `posting_date` → already the `app.next_name(..., posting_date)` contract |
| enable_item_search_index | boolean | false | Frappe sqlite search; **Deviation:** we always use Postgres FTS |

- `on_update` pushes `company/currency/country/hide_currency_symbol/disable_rounded_total/disable_in_words` into user defaults → ours: Server Components read `global_defaults` directly; `revalidateTag('global-defaults')`.
- Permissions: System Manager rwc.
- **Built (P0, `0103_setup_global_defaults.sql`):** one row per org, seeded by a trigger on `organizations` insert (country + currency); the first company inserted becomes `default_company_id`. Members read, System Manager writes (`role_permissions`: read/write, no create/delete; rows are never inserted or deleted through the API). Link errors: `country_unknown`, `currency_unknown`, `company_unknown` (company from another org). Saving a new `default_currency` enables it in `org_currency`. `default_distance_unit` is in the table but joins the form with the UOM doctype (P1). `demo_company` is not ported.

### 2.18 System Settings (Frappe) → `system_settings` (single, per org)

Only the fields that affect our behaviour; defaults are Frappe's.

| fieldname | type | default | notes |
|---|---|---|---|
| float_precision | integer | **3** | qty/rate rounding |
| currency_precision | integer null | null (= from currency `fraction_units`/number format, i.e. 2) | |
| date_format | text | `dd-mm-yyyy` | wizard copies `country.date_format` when set |
| time_format | text | `HH:mm:ss` | |
| number_format | text | `#,###.##` | from `currency.number_format` when the currency defines one |
| first_day_of_the_week | text | `Sunday` | |
| language | text | org language (`en`) | |
| time_zone | text | org tz | |
| email_footer_address | text | company_name | set by wizard (`defaults_setup.set_default_settings`) |
| app_name | text | `headless-erp` (ERPNext: `ERPNext`) | |
| session defaults | — | `Company` | `install.py: add_company_to_session_defaults` → the company switcher + `hx_company` cookie |

- Permissions: System Manager rw.
- **Built (P0, `0104_setup_system_settings.sql`):** one row per org, seeded on `organizations` insert: `date_format`/`time_format` from the country, `number_format` from the currency, `time_zone` from the org (unknown zones fall back to `UTC`). Selects are text with Frappe's option lists as check constraints (`float_precision` 2–9, `currency_precision` empty or 0–9). `time_zone_unknown` rejects zones Postgres does not know. Members read the row through RLS. **Deviation:** Frappe grants System Settings and Global Defaults to System Manager only; every other standard role gets read-only access so the pages open for them. `email_footer_address` is left empty until the wizard sets it. Number and date rendering still use the current formatting; applying these settings is a follow-up.

### 2.19 Address → `address` + `address_link`

Frappe `Address` (extended by `erpnext/accounts/custom/address.py: ERPNextAddress`) + ERPNext custom fields from `install.py: create_address_and_contact_custom_fields()`.

- **Kind:** master. **Naming:** `"<address_title>-<address_type>"` (Frappe `autoname`), `-1`, `-2` on duplicates; `address_title` defaults to the first link's title.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| address_title | text | | first link title | |
| address_type | text check | ✔ | `'Billing'` | `Billing \| Shipping \| Office \| Personal \| Plant \| Postal \| Shop \| Subsidiary \| Warehouse \| Current \| Permanent \| Other` |
| address_line1 | text | ✔ | | |
| address_line2 | text | | | |
| city | text | ✔ | | |
| county, state | text | | | |
| country | text → country | ✔ | org country | |
| pincode | text | | | |
| email_id, phone, fax | text | | | |
| is_primary_address | boolean | | false | setting it unsets the previous primary for each linked party (`validate_preferred_address`) |
| is_shipping_address | boolean | | false | same rule |
| disabled | boolean | | false | |
| **tax_category_id** (ERPNext) | uuid → tax_category | | null | drives Tax Rule lookup (P2) |
| **is_your_company_address** (ERPNext) | boolean | | false | auto-set when a `Company` link exists; if set, a Company link is required (`validate_reference`) |

`address_link` (Address `links`; Frappe `Dynamic Link`): `parent_id uuid`, `link_doctype text`, `link_id uuid`, `link_title text`, `idx`. Unique `(parent_id, link_doctype, link_id)`. Allowed `link_doctype`: Company now; Customer, Supplier (P2) and Sales Partner (P5) widen the check when their tables land; Lead/Prospect are out. **Deviation:** one link table per parent (`address_link`, `contact_link`) instead of a shared `dynamic_link`, because the doc engine maps a child doctype to one parent (`02-database-conventions.md`, Link integrity).

- `on_update`: refreshes `customer.primary_address` display text for customers whose `customer_primary_address` is this row. `get_default_company_address(company, sort_key)` → company address for prints (`is_primary_address`) and `get_shipping_address(company)` (`is_shipping_address` + `is_your_company_address`) → `app.company_address(company_id, kind)`.
- Address display: Frappe renders `Address Template` (Jinja, per country). Default template (`frappe/contacts/doctype/address_template/address_template.py`):

```jinja
{{ address_line1 }}<br>
{% if address_line2 %}{{ address_line2 }}<br>{% endif -%}
{{ city }}<br>
{% if state %}{{ state }}<br>{% endif -%}
{% if pincode %}{{ pincode }}<br>{% endif -%}
{{ country }}<br>
{% if phone %}Phone: {{ phone }}<br>{% endif -%}
{% if fax %}Fax: {{ fax }}<br>{% endif -%}
{% if email_id %}Email: {{ email_id }}<br>{% endif -%}
```

  **Deviation:** no `address_template` table; `src/lib/format/address.ts` implements the default and the 9 country variants from `erpnext/regional/address_template/templates/` (Bosnia and Herzegovina, Croatia, Denmark, Germany, Luxembourg, Sweden, Switzerland, Taiwan, United States) as code.
- Permissions (Frappe JSON + `install.py: grant_address_read_to_accounts_manager`): Sales User, Purchase User, Maintenance User, Accounts User, Stock User rwcd; Accounts Manager read (export off); Sales/Purchase Manager rwcd. We seed those.
- List: name, address_type, city, country.
- **Built** (0121, descriptor `address.ts`): `app.address_validate` (trims; `name` is write-once; `country` falls back to the organization's), `app.address_link_validate` (same-org target, `link_title`), deferred `app.address_refresh` (naming, `update_company_address` + `validate_reference`, `validate_preferred_address` per linked party), `app.dynamic_link_sync('Company')` on `companies` (renames refresh titles; deletes drop the links and clear `is_your_company_address` when no Company link is left), `app.company_address(company, 'primary'|'shipping')` and `app.party_addresses(doctype, id)` (+ `public.*` RPC wrappers, RLS applies), `src/lib/format/address.ts` `formatAddress()`. The form's Links grid uses `DynamicLink` cells that read `link_doctype` from the same row. `tax_category_id` waits for Tax Category (P2); the `customer.primary_address` refresh waits for Customer (P2). pgTAP `25_address`, e2e `address.spec.ts`.

### 2.20 Contact → `contact` + `contact_email` + `contact_phone` + `contact_link`

- **Kind:** master. **Naming:** full name, plus `"-<first link title>"` when links exist; `-1` on duplicates.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| first_name | text | ✔ | | |
| middle_name, last_name | text | | | |
| full_name | text | | generated | `first [middle] [last]` |
| salutation | text | | | free text (Frappe link to Salutation dropped) |
| designation_id | uuid → designation | | | |
| gender | text | | | |
| email_id | text | | from primary `contact_email` | denormalised |
| mobile_no, phone | text | | from `contact_phone` rows flagged primary | |
| company_name | text | | | party's company name (free text) |
| user_id | uuid → auth.users | | | matched by email on member insert |
| address_id | uuid → address | | | |
| image | text (storage path) | | | |
| status | text check | | `'Passive'` | `Passive \| Open \| Replied` (CRM only; kept) |
| is_primary_contact | boolean | | false | unsets previous primary per link |
| **is_billing_contact** (ERPNext) | boolean | | false | custom field |
| department | text | | | |
| unsubscribed | boolean | | false | |

`contact_email(parent_id, email_id reqd, is_primary)`, `contact_phone(parent_id, phone reqd, is_primary_phone, is_primary_mobile_no)`. Validations: at most one primary email / primary phone / primary mobile; email format; `full_name` set; parent `email_id/mobile_no/phone` refreshed from primary rows.
- `on_update` refreshes `customer.mobile_no/email_id` for customers whose `customer_primary_contact` is this row (ERPNext `Customer` fetches them).
- Permissions (Frappe JSON): Sales User, Purchase User, Maintenance User, Accounts User, Stock User rwcd; Sales/Purchase Manager rwcd.
- List: name, email_id, mobile_no, is_primary_contact.
- **Built** (0122, descriptor `contact.ts`): child tables `contact_email` (`email_ids`), `contact_phone` (`phone_nos`) and `contact_link` (`links`, same rules as `address_link`); `app.contact_validate` (trims, `full_name`, write-once `name`), `app.contact_email_validate` (email format), deferred `app.contact_refresh` (one primary email / phone / mobile, denormalised `email_id` / `phone` / `mobile_no` follow the primary rows and are cleared when there is none, `set_user` against the org's members, naming, one primary contact per linked party), `app.contact_match_member` on `org_members` insert, `app.party_contacts(doctype, id)` (+ `public` RPC), `app.file_doctype` maps the `contact` folder to Contact (image upload), `companies.default_sales_contact_id` FK `on delete set null` and a *Buying and Selling* tab on the Company form. `gender` is a check over Frappe's Gender fixtures; `designation_id` / `address_id` are FKs that clear on delete. The `customer.mobile_no/email_id` refresh waits for Customer (P2). pgTAP `26_contact`, e2e `contact.spec.ts`.

### 2.21 Currency → `currency` (global, `is_global`)

Frappe `Currency`: `code (name) text pk`, `currency_name text`, `enabled boolean`, `fraction text` (e.g. Cent), `fraction_units integer` (100), `smallest_currency_fraction_value numeric` (0.01), `symbol text`, `symbol_on_right boolean`, `number_format text` (`#,###.##`, `#.###,##`, `# ###.##`, `#,##,###.##` …). **Built (P0, `0009_framework_reference_data.sql`):** 144 currencies created from `country_info.json` exactly as `frappe/geo/country_info.py` does (first country carrying a code wins; Frappe has no separate `currency.json`). **Deviation:** Frappe stores the code in `currency_name`; ours holds the ICU English name ("US Dollar") so pickers search by code or name. No global `enabled`: **`org_currency(org_id, code, enabled)`** holds the per-org flag, set by triggers when an organization or company uses a currency (ERPNext sets `enabled = 1` for the company/default currency on Company save and in `Global Defaults.on_update`); readable by members, updatable by System Manager. Currency precision for a company = `fraction_units` digits (2) unless `system_settings.currency_precision` overrides.

### 2.22 Country → `country` (global)

Frappe `Country`: `country_name text pk`, `code text` (ISO-2, lower case as in Frappe), `date_format text`, `time_format text`, `time_zones text[]`. **Built (P0):** 250 countries from Frappe's `country_info.json` (Frappe defaults `dd-mm-yyyy` / `HH:mm:ss` when the JSON has none). `organizations.country` / `companies.country` store the country **name** (as ERPNext does) with an FK; a `before` trigger raises `country_unknown: Could not find Country: X` / `currency_unknown: Could not find Currency: X` (Frappe `LinkValidationError` wording) so forms map the error onto the field.

**Source and regeneration (Country, Currency, UOM templates):** vendored inputs live in `supabase/seed/reference/` (`country_info.json` from frappe/frappe, `uom_data.json` + `uom_conversion_data.json` from ERPNext; commit SHAs in `SOURCES.json`). `node scripts/gen-reference-data.mjs` regenerates `0009_framework_reference_data.sql` (idempotent upserts). `uom_template` (239 rows; `category` is null for count UOMs such as Nos/Box/Unit, as in ERPNext) and `uom_conversion_template` (235 rows) are copied into each org's `uom` tables by P1 provisioning (A19). Conversions keep ERPNext's rows without an FK to `uom_template`: ERPNext `db_insert`s them unvalidated and three name UOMs it never creates (Manzana, Medio Metro, Peck). One source value has a typo (`"0.006993s"`, Meter → Ells (UK)); we store `0.006993` where Frappe's `flt()` would store 0. Used by: org/company `country`, Territory seed, Address, CoA template filter (`get_charts_for_country` matches verified JSON files prefixed with the ISO code or country name), country-wise tax seed.

### 2.23 Fiscal Year → `fiscal_year` + child `fiscal_year_company`

Module Accounts (`erpnext/accounts/doctype/fiscal_year/fiscal_year.py`), but created at onboarding.

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| year | text | ✔ | `"2026"` or `"2026-2027"` (`get_fy_details`) | = name, unique per org |
| year_start_date / year_end_date | date | ✔ | | start ≤ end; unless `is_short_year`, end must equal start + 1 year − 1 day |
| disabled | boolean | | false | |
| is_short_year | boolean | | false | |
| auto_created | boolean | | false | set by the scheduler |

`fiscal_year_company(parent_id, company_id)`: empty = applies to all companies. `validate_overlap`: another FY overlapping the date range is an error when both have no companies or share a company (`Year start date or end date is overlapping with {0}. To avoid please set company`).

Scheduled job `app.auto_create_fiscal_year()` (daily; ERPNext `daily_maintenance`): for every non-short FY with `year_end_date <= today + 3 days`, insert the next year (`start = end + 1`, `end = start + 1y − 1d`, same companies, `auto_created = true`, `disabled` copied) if that `year` name does not already exist.

- Permissions: System Manager rwcd; read for Sales User, Purchase User, Accounts User, Stock User, Employee, Accounts Manager, Stock Manager, Auditor.
- **Built (0114):** `public.fiscal_year` (`year` unique per org, case-insensitive) and child `public.fiscal_year_company` (`company_id`, unique per year; deleting a company removes its rows). Route `/[org]/accounts/fiscal-year` (Accounting › Setup, as in ERPNext).
  - `app.fiscal_year_validate` (before trigger) ports `validate_dates` (`fiscal_year_dates`: "Year End Date must be after Year Start Date", "Fiscal Year End Date should be one year after Fiscal Year Start Date" unless `is_short_year`) and names an empty `year` with `app.fiscal_year_name(start, end)` (`get_fy_details`).
  - `app.fiscal_year_check_overlap` ports `validate_overlap` (`fiscal_year_overlap`) as a deferred constraint trigger on the year and its company rows (document-level validation, 02-database-conventions).
  - `app.auto_create_fiscal_year()` runs daily through `pg_cron` (job `auto-create-fiscal-year`); a next year that would conflict is skipped.
  - Form: changing Year Start Date sets Year End Date (start + 12 months − 1 day, unless short year) and re-derives a generated Year Name (`fiscal_year.js`; descriptor `triggers`). **Deviation:** a new form does not prefill the start date (`year_start()`); Year Name may be left empty.
  - Descriptor `src/doctypes/accounts/fiscal-year.ts`; pgTAP `19_fiscal_year.test.sql`; e2e `fiscal-year.spec.ts`.

### 2.24 Terms and Conditions → `terms_and_conditions`

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| title | text | ✔ | | = name |
| disabled | boolean | | false | |
| terms | text (html) | | | template rendered with the document as context |
| selling | boolean | | **true** | |
| buying | boolean | | **true** | |
| copy_attachments_to_transaction | boolean | | false | kept, no-op until attachments land |

- Validation: at least one of `selling`/`buying` unless `disabled` (ERPNext also reads a non-existent `hr` flag; dropped). `get_terms_and_conditions(template, doc)` renders Jinja → ours: same handlebars subset as Email Template (**Deviation**). Link fields `tc_name` on QTN/SO/DN/SI/SQ/PO/PR/PI pick templates filtered by `selling`/`buying`; `Company.default_selling_terms/default_buying_terms` pre-fill.
- Permissions (JSON): System Manager, Accounts Manager, Sales Master Manager rwcd; Sales User, Purchase User, Stock User, Accounts User read. We seed System Manager + Accounts Manager + Sales Manager + Purchase Manager rwcd, the four users read.

---

## 3. Document flows & mappers

### 3.1 Onboarding → `app.provision_organization(p jsonb)`

Mirrors `setup_wizard.get_setup_stages()`: **Setting up the basics** (`install_fixtures.install(country)`) → **Creating your company** (`install_company`) → **Applying recommended settings** (`install_defaults`) → (Personalizing = telemetry, skipped) → (Demo data, skipped; P11 generator). Runs as one `security definer` transaction called from the onboarding Server Action after verifying the caller; idempotent per `org_id` (re-run = no-op when `organizations.provisioned_at` is set).

Input `p`: `{ org: {name, slug, country, default_currency, time_zone, language}, company: {company_name, abbr, fy_start_date, fy_end_date, chart_of_accounts, domain}, invites: [{email, roles[], role_profile}] }`. The owner is the caller (`auth.uid()`); there is no `modules` key (the wizard's Modules step is dropped) and `bank_account` arrives with B13.

**Built (0116, staged):** `app.provision_organization(p)` (`security definer`, one transaction; public RPC `provision_organization`) runs:
- **Stage A** through `app.create_organization` (validates the slug, inserts the organization including `language`, `app.sync_role_permissions`, owner membership). The organizations insert triggers seed System Settings, Global Defaults, Print Settings (0119), the standard Print Formats (0120), the 31 designations and the `All Departments` root. A1-A4 and A18 are done; A5-A17 and A19-A22 wait for their tables.
- **Stage B:**
  - B1: a Fiscal Year from `fy_start_date` / `fy_end_date` (the end defaults to one year later; skipped without a start date, as in `install_company`).
  - B2: the company through `app.create_company`. The abbreviation defaults to the word initials (`app.company_abbr`), currency and country default to the organization's, `chart_of_accounts` defaults to `Standard`, `enable_perpetual_inventory = true` and `create_chart_of_accounts_based_on = 'Standard Template'`.
  - B8 (departments) and B11 (`org_currency`) run through the companies insert triggers.
  - B3-B7, B9, B10 and B13 need the P2 account, cost center, warehouse, tax and mode-of-payment tables and are added by those migrations.
- **Stage C:**
  - C3: `global_defaults` gets `default_company_id`, `default_currency` and `country`.
  - C5: one `app.create_invitation` per invite. After provisioning, the `provisionOrganization` Server Action emails each open invitation (§3.4). This is best effort: a failed send leaves the invitation open for Resend or Copy link on the Users page.
  - C6: `provisioned_at = now()`.
  - C1, C2 and C4 wait for their tables.
- **Idempotency:** re-running for a slug the caller owns that is already provisioned returns `{id, slug, company_id}` unchanged; any other existing slug fails with `slug_taken`.
- **Atomicity:** any error, such as an invalid invite or an unknown chart, rolls back the whole organization.
- **Existing organizations:** those created before 0116 had `provisioned_at` backfilled to `created_at`.
- **Tests:** pgTAP `21_provision_organization.test.sql`, which also took over the slug checks of the former `03_create_organization` test.
- **Caller:** the onboarding wizard (05-ui-ux) is the only caller. The P0 `public.create_organization` RPC was dropped in `0117`, and pgTAP fixtures call `app.create_organization` directly.

**Stage A — basics (org-level fixtures)**

| # | Record(s) | Values (ERPNext source) |
|---|---|---|
| A1 | `organizations` | name, slug, country, default_currency, time_zone, language; `provisioned_at` set at the end |
| A2 | `org_members` (owner) | `roles = {System Manager}`, `is_owner = true`, `status = active` |
| A3 | `roles` ×19 standard, `role_permissions` from `supabase/seed/role_permissions.json`, `role_profile` ×5 (§2.7) | `install.py: create_default_role_profiles` |
| A4 | `system_settings`, `global_defaults`, `print_settings`, module settings rows (`accounts_settings`, `selling_settings`, `buying_settings`, `stock_settings`, `manufacturing_settings`, `projects_settings`) | DocField defaults (`install.py: set_single_defaults`) then wizard overrides in Stage C |
| A5 | `item_group` tree | `All Item Groups` (group) → `Products`, `Raw Material`, `Services`, `Sub Assemblies`, `Consumable` |
| A6 | `stock_entry_type` (`is_standard = true`, `purpose` = name) | `Material Issue`, `Material Receipt`, `Material Transfer`, `Manufacture`, `Repack`, `Material Transfer for Manufacture`, `Material Consumption for Manufacture`, `Send to Subcontractor`. **Deviation:** ERPNext also seeds `Disassemble`, `Receive from Customer`, `Return Raw Material to Customer`, `Subcontracting Delivery`, `Subcontracting Return`, `Batch Split` (purpose Repack, `batch_split = 1`) — out of scope |
| A7 | `territory` tree | `All Territories` (group) → `<Country name with apostrophes removed>`, `Rest Of The World` |
| A8 | `customer_group` tree | `All Customer Groups` (group) → `Individual`, `Commercial`, `Non Profit`, `Government` |
| A9 | `supplier_group` tree | `All Supplier Groups` (group) → `Services`, `Local`, `Raw Material`, `Electrical`, `Hardware`, `Pharmaceutical`, `Distributor` |
| A10 | `sales_person` tree | `Sales Team` (group) |
| A11 | `mode_of_payment` | `Cheque` (`Check` when country = United States) type Bank; `Cash` type Cash; `Credit Card` Bank; `Wire Transfer` Bank; `Bank Draft` Bank |
| A12 | `activity_type` | `Planning`, `Research`, `Proposal Writing`, `Execution`, `Communication` |
| A13 | `party_type` | `Customer` → Receivable, `Supplier` → Payable (ERPNext also `Employee`, `Shareholder` → Payable; dropped) |
| A14 | `project_type` | `Internal`, `External`, `Other` |
| A15 | `print_heading` | `Credit Note`, `Debit Note` (optional; used by `select_print_heading` on returns) |
| A16 | `warehouse_type` | `Transit` |
| A17 | `workstation_operating_component` | `Electricity`, `Consumables`, `Rent`, `Wages` (P8) |
| A18 | `designation` ×31 | `designation.txt`: Accountant, Administrative Assistant, Administrative Officer, Analyst, Associate, Business Analyst, Business Development Manager, Consultant, Chief Executive Officer, Chief Financial Officer, Chief Operating Officer, Chief Technology Officer, Customer Service Representative, Designer, Engineer, Executive Assistant, Finance Manager, HR Manager, Head of Marketing and Sales, Manager, Managing Director, Marketing Manager, Marketing Specialist, President, Product Manager, Project Manager, Researcher, Sales Representative, Secretary, Software Developer, Vice President |
| A19 | `uom_category`, `uom`, `uom_conversion_factor` | from `uom_data.json` (239 UOMs incl. `Nos`, `Unit`, `Box`, `Pair`, `Set` with `must_be_whole_number = 1`) and `uom_conversion_data.json` (235 rows). PLAN §5: copy a curated subset by default (Nos, Unit, Box, Kg, Gram, Litre, Meter, Hour, Day, Set, Pair, Dozen, Millilitre, Centimeter, Millimeter, Minute, Week, Tonne, Pound, Square Meter, Cubic Meter) + their conversions; "Import all UOMs" action copies the rest from the global `uom_template` |
| A20 | `selling_settings` | `cust_master_name = Customer Name`, `so_required = No`, `dn_required = No`, `allow_multiple_items = 1`, `sales_update_frequency = Each Transaction` |
| A21 | `buying_settings` | `supp_master_name = Supplier Name`, `po_required = No`, `pr_required = No`, `maintain_same_rate = 1`, `allow_multiple_items = 1` |
| A22 | `naming_series` | one row per `(company, series)` from `doctype_meta.naming_series_default` (created lazily by `app.next_name` if missing) |
| — | **Skipped fixtures** | Address Template (code, §2.19), Sales Stage, Industry Type, UTM Source, Sales Partner Type, Item Attribute `Size`/`Colour`, Issue Priority, Opportunity Type, Share Type, Market Segment, Email Template `Dispatch Notification`, Supplier Scorecard defaults (P6 doc), Incoterms, Operation `Assembly` (P8 doc), Item Variant Settings, Currency Exchange Settings (`frankfurter.dev - v2`), Pegged Currencies, Global Search settings |

**Stage B — company** (`install_company` + `Company.on_update`; reusable as `app.create_company()`)

| # | Record(s) | Values |
|---|---|---|
| B1 | `fiscal_year` | `year = get_fy_details(start, end)` (`"2026"` if same calendar year else `"2026-2027"`), dates from wizard; no company rows (applies to all) |
| B2 | `companies` | `company_name`, `abbr` (default initials), `default_currency`, `country`, `enable_perpetual_inventory = true`, `create_chart_of_accounts_based_on = 'Standard Template'`, `chart_of_accounts` (default `'Standard'`), `valuation_method = 'FIFO'`, `reporting_currency = default_currency`, `domain` |
| B3 | `account` tree (`create_charts`) | expand the template (§3.2) — per node: `account_name`, `parent_id`, `is_group` (explicit `is_group` or "has children"), `root_type` (from the root), `report_type` = Balance Sheet for Asset/Liability/Equity else Profit and Loss, `account_number`, `account_type`, `account_category`, `account_currency = company currency`, `tax_rate`; `name = "<account_name> - <ABBR>"` (`"<number> - <name> - <ABBR>"` for numbered templates); duplicate names get ` 1`, ` 2` suffix |
| B4 | `companies.default_receivable_account_id` / `default_payable_account_id` | first non-group `account_type = Receivable` → `Debtors`; `Payable` → `Creditors`. **Deviation:** ERPNext's unordered lookup could also hit `Employee Advances` (type Payable); we select by `root_type = Liability` first |
| B5 | `warehouse` tree (`create_default_warehouses`) | `All Warehouses` (group) → `Stores`, `Work In Progress`, `Finished Goods`, `Goods In Transit` (`warehouse_type = Transit`); names ` - ABBR`; `companies.default_warehouse_id = Stores` |
| B6 | `cost_center` tree (`create_default_cost_center`) | `<Company name>` (group, root) → `Main`; `companies.cost_center_id = round_off_cost_center_id = depreciation_cost_center_id = Main - ABBR` |
| B7 | Country tax templates (`create_default_tax_template` → `taxes_setup.setup_taxes_and_charges`) | from `country_wise_tax.json` (170 countries) when the country has an entry: tax accounts created under the `account_type = Tax` group (`Duties and Taxes` for Liability, `Tax Assets` for Asset) with `account_type = Tax`, `report_type = Balance Sheet`; `sales_taxes_and_charges_template` / `purchase_taxes_and_charges_template` rows (tax row defaults `category = Total`, `charge_type = On Net Total`, `cost_center = company.cost_center`, purchase `add_deduct_tax = Add`, `description = "<account_name> @ <rate>"`), `item_tax_template` rows, `tax_category` rows when listed; one template flagged `is_default`. Regional `update_regional_tax_settings` skipped |
| B8 | `department` tree (`create_default_departments`) | root `All Departments` (org-level, no company; created once) → 13 per company: `Accounts`, `Marketing`, `Sales`, `Purchase`, `Operations`, `Production`, `Dispatch`, `Customer Service`, `Human Resources`, `Management`, `Quality Management`, `Research & Development`, `Legal` (names ` - ABBR`) |
| B9 | `companies` default accounts (`set_default_accounts`) | by `account_type`: `default_cash_account = Cash`, `default_bank_account = <type Bank, non-group>` (none in the Standard chart until B13), `round_off_account = Round Off`, `accumulated_depreciation_account = Accumulated Depreciation`, `depreciation_expense_account = Depreciation`, `capital_work_in_progress_account = CWIP Account` (type Capital Work in Progress), `asset_received_but_not_billed = Asset Received But Not Billed`, `default_expense_account = Cost of Goods Sold`; perpetual: `stock_received_but_not_billed`, `stock_delivered_but_not_billed`, `default_inventory_account = Stock In Hand` (type Stock), `stock_adjustment_account = Stock Adjustment`. By `account_name`: `default_income_account = Sales` (or `Sales Account` / type Income Account), `write_off_account = Write Off`, `bank_charges_account = Bank Charges`, `exchange_gain_loss_account = Exchange Gain/Loss`, `exchange_gain_account = Exchange Gain`, `exchange_loss_account = Exchange Loss`, `disposal_account = Gain/Loss on Asset Disposal` |
| B10 | `mode_of_payment_account` (`set_mode_of_payment_account`) | `Cash` mode → `(company, default_account = default_cash_account)` |
| B11 | `org_currency` | company currency `enabled = true` |
| B12 | `department` / `account` `path` rebuild | `rebuild_tree` equivalents run by the ltree trigger |
| B13 | Bank account (`create_bank_account`, Stage C in ERPNext but needs the chart) | if `p.company.bank_account`: `account(account_name = bank_account, parent = Bank Accounts - ABBR, account_type = Bank, is_group = false)` → `companies.default_bank_account_id`; duplicate of a chart account → ignored |

**Stage C — recommended settings** (`install_defaults`)

| # | Record(s) | Values |
|---|---|---|
| C1 | `price_list` | `Standard Buying` (`enabled`, `buying = 1`, `selling = 0`, currency), `Standard Selling` (`selling = 1`, `buying = 0`) |
| C2 | `stock_settings.email_footer_address` | company_name; `system_settings.email_footer_address` likewise (`defaults_setup`) |
| C3 | `global_defaults` | `default_currency`, `default_company_id`, `country` |
| C4 | `stock_settings` | `item_naming_by = Item Code`, `valuation_method = FIFO`, `stock_uom = Nos`, `auto_indent = 1`, `auto_insert_price_list_rate_if_missing = 1`, `update_price_list_based_on = Rate`, `set_qty_in_transactions_based_on_serial_no_input = 1` |
| C5 | `invitations` | one row per `p.invites` + email via platform sender (§3.4) |
| C6 | `organizations.provisioned_at = now()`; `onboarding_progress` rows for the Home checklist (§7) | |

Default print formats (`install.py: set_default_print_formats`) are seeded with each module's transaction tables (§2.12), not here.

### 3.2 Standard chart of accounts (`standard_chart_of_accounts.py`)

Vendored as `supabase/seed/coa/standard_chart_of_accounts.py` and `standard_chart_of_accounts_with_account_number.py` (ERPNext ships them as Python modules; the generator converts the dict literal) plus the 73 verified country files in `supabase/seed/coa/verified/`. Tree with `[account_type | account_category]`; `*` = group:

```
Application of Funds (Assets) *                         root_type Asset
  Current Assets *
    Accounts Receivable *
      Debtors                                            [Receivable | Trade Receivables]
    Bank Accounts *                                      [Bank | Cash and Cash Equivalents]
    Cash In Hand *                                       [Cash | Cash and Cash Equivalents]
      Cash                                               [Cash | Cash and Cash Equivalents]
    Loans and Advances (Assets) *
      Employee Advances                                  [Payable | Other Receivables]
    Securities and Deposits *
      Earnest Money                                      [— | Other Current Assets]
    Prepaid Expenses                                     [— | Other Current Assets]
    Short-term Investments                               [— | Short-term Investments]
    Stock Assets *                                       [Stock | Stock Assets]
      Stock In Hand                                      [Stock | Stock Assets]
      Stock Delivered But Not Billed                     [Stock Delivered But Not Billed | Stock Assets]
    Tax Assets *                                         [— | Other Current Assets]
  Fixed Assets *
    Capital Equipment, Electronic Equipment, Furniture and Fixtures, Office Equipment,
    Plants and Machineries, Buildings                    [Fixed Asset | Tangible Assets]
    Software                                             [Fixed Asset | Intangible Assets]
    Accumulated Depreciation                             [Accumulated Depreciation | Tangible Assets]
    CWIP Account                                         [Capital Work in Progress | Tangible Assets]
  Investments *                                          [— | Long-term Investments]
  Temporary Accounts *
    Temporary Opening                                    [Temporary | Other Non-current Assets]
Expenses *                                               root_type Expense
  Direct Expenses *
    Stock Expenses *
      Cost of Goods Sold                                 [Cost of Goods Sold | Cost of Goods Sold]
      Expenses Included In Asset Valuation               [Expenses Included In Asset Valuation | Other Direct Costs]
      Expenses Included In Valuation                     [Expenses Included In Valuation | Other Direct Costs]
      Stock Adjustment                                   [Stock Adjustment | Other Direct Costs]
  Indirect Expenses *
    Administrative Expenses, Commission on Sales, Entertainment Expenses, Legal Expenses,
    Office Maintenance Expenses, Office Rent, Postal Expenses, Print and Stationery, Salary,
    Sales Expenses, Telephone Expenses, Travel Expenses, Utility Expenses, Write Off,
    Exchange Gain/Loss, Impairment, Exchange Loss        [— | Operating Expenses]
    Depreciation                                         [Depreciation | Operating Expenses]
    Freight and Forwarding Charges, Marketing Expenses, Miscellaneous Expenses
                                                         [Chargeable | Operating Expenses]
    Round Off                                            [Round Off | Operating Expenses]
    Interest Expense, Bank Charges                       [— | Finance Costs]
    Gain/Loss on Asset Disposal                          [— | Other Operating Income]
    Tax Expense                                          [— | Tax Expense]
Income *                                                 root_type Income
  Direct Income *
    Sales, Service                                       [— | Revenue from Operations]
  Indirect Income *
    Interest Income, Interest on Fixed Deposits          [— | Investment Income]
    Exchange Gain                                        [— | Other Operating Income]
Source of Funds (Liabilities) *                          root_type Liability
  Current Liabilities *
    Accounts Payable *
      Creditors                                          [Payable | Trade Payables]
      Payroll Payable                                    [— | Other Payables]
    Accrued Expenses, Customer Advances                  [— | Other Current Liabilities]
    Stock Liabilities *
      Stock Received But Not Billed                      [Stock Received But Not Billed | Trade Payables]
      Asset Received But Not Billed                      [Asset Received But Not Billed | Trade Payables]
    Duties and Taxes *                                   [Tax | Current Tax Liabilities]
    Short-term Provisions                                [— | Short-term Provisions]
    Loans (Liabilities) *
      Secured Loans, Unsecured Loans                     [— | Long-term Borrowings]
      Bank Overdraft Account                             [— | Short-term Borrowings]
  Non-Current Liabilities *
    Long-term Provisions                                 [— | Long-term Provisions]
    Employee Benefits Obligation                         [— | Other Non-current Liabilities]
Equity *                                                 root_type Equity
  Capital Stock                                          [Equity | Share Capital]
  Dividends Paid, Opening Balance Equity, Retained Earnings, Revaluation Surplus
                                                         [Equity | Reserves and Surplus]
```

Template selection (`get_charts_for_country(country, with_standard)`): verified JSON files whose filename starts with the country ISO code or name and are not `disabled`; if exactly one matches, only it is offered, otherwise the list plus `Standard` and `Standard with Numbers`. We always show `Standard`, `Standard with Numbers` and the country matches, preselecting the single country match when there is one. Preview via `build_tree_from_json` → `app.coa_template_preview(key)`.

**Built (0115, generated by `node scripts/gen-coa-templates.mjs`):**
- Global `public.coa_template (name pk, disabled, tree json)`: 41 templates, i.e. Standard, Standard with Numbers and the 39 distinct charts of the 73 files. The trees are stored as `json`, not `jsonb`, so ERPNext's account order survives. `public.coa_template_file (file_name pk, template)`: ERPNext's per-country Syscohada copies (17 countries plus the generic file) all point to one template; the generator checks that the copies hold the same accounts.
- `public.coa_template_country` (view): a file belongs to a country when its name starts with the country code or name, case-sensitive like `startswith`. As in ERPNext, this also matches some accidental prefixes: `philippines.json` matches Philippines through its code `ph`, and the generic `syscohada_*.json` files match Syria (`sy`).
- `app.coa_templates_for_country(country)` (RPC `public.coa_templates_for_country`): the country's charts by name, then Standard and Standard with Numbers; `is_default` marks the single country chart, else Standard.
- `app.coa_template_preview(name)` (RPC `public.coa_template_preview`): `idx`, `account` (`"<number> - <name>"` when numbered), `parent_account`, `is_group` (`identify_is_group`), `root_type` (from the root), `account_type`, `account_number`, `depth`.
- Company: `chart_of_accounts` has an FK to `coa_template` and `companies_validate_links` raises `coa_unknown: Could not find Chart Of Accounts Template: X`. The form's template Select uses the `ChartOfAccounts` source, narrowed to the company country plus the standard charts (`filterOptions`).
- Accounts are not created from the templates yet (B3 waits for the P2 `account` table). pgTAP `20_coa_templates.test.sql`; converter tests `scripts/lib/coa.test.mjs`.

### 3.3 Company creation side-effects (second and later companies) → `app.create_company(jsonb)`

Same as Stage B (B2–B13) without the Fiscal Year (B1); `global_defaults.default_company_id` unchanged. When `parent_company` is given: `create_chart_of_accounts_based_on = 'Existing Company'`, `existing_company = parent` (`set_chart_of_accounts`) and the chart is copied from the parent's account tree (`get_account_tree_from_existing_company`, same `account_type/root_type/tax_rate/account_number/account_currency` per node); `reporting_currency` = parent's. Changing `country` later re-runs B7 (`frappe.flags.country_change`). ERPNext's `create_default_tax_template` is also exposed as a form action ("Create Default Tax Template") → `app.create_default_tax_templates(company_id)`.

**Built (0116):**
- `app.create_company(p)` (`security invoker`, so RLS authorizes; public RPC `create_company`) inserts the company through `app.save_doc` and returns `{id, name}`.
- The Company descriptor's `create: "create_company"` hook makes the Company form's "new" path call it (05-ui-ux).
- Departments (B8) and the org currency (B11) come from the insert triggers. The default company is set only when the organization has none.
- The P2 side effects (B3-B7, B9, B10, B13) and the parent-company chart copy are added to this function by the migrations that create their tables.

### 3.4 Invite flow

Owner/System Manager → `invitations(org_id, email, roles[], role_profile?, token, expires_at = now + 7 days)` → email via platform sender using template `Invitation` with `/invite/[token]` → recipient signs up/in → Server Action `acceptInvitation(token)`: verifies not expired/accepted, inserts `org_members(status = active, roles)`, `user_profile` if missing, sets `accepted_at`, forces token refresh. Resend / revoke actions on the Users page. Mirrors Frappe's "Add User → welcome email" (`invite_users` onboarding step: *Invite your team — Add the people you work with and choose what they can see*).

**Built (P1, `0107_setup_invitations.sql`; email delivery from the Email track):**

- `createInvitation` and `resendInvitation` send the app-level `Invitation` template (`src/lib/email/templates.ts`) through the platform sender (`RESEND_API_KEY` + `EMAIL_FROM`) and log it to `email_log` (reference doctype `Invitation`). The drawer says "Invitation emailed to …" and still shows the link. When email is not configured or the send fails, the invitation is kept, the drawer explains why no email went out, and "Copy link" is the fallback. Resend from the list emails the new link, or copies it when sending is not possible.

- `app.create_invitation(p_org, p_email, p_roles, p_role_profile)` (System Manager only, else `42501`) returns `{ id, token }`. It raises `roles_required` (neither roles nor profile), `already_member` (the email belongs to an active member; disabled members can be re-invited and are re-activated on accept), `invite_pending` (an open invitation exists; resend it instead), `invalid_role` and `invalid_email`. An expired open invitation is revoked automatically so a new one can be created. A partial unique index keeps one open invitation per `(org_id, email)`.
- `invitations` gained `role_profile` (FK to `role_profile`, cascades on rename, set null on delete) and `revoked_at`. A trigger lower-cases the email, copies the profile's roles into `roles` when a profile is set, dedupes, and validates roles.
- `app.resend_invitation(id)` issues a new token and a fresh 7-day expiry (the old link stops working); accepted or revoked invitations raise `invitation_closed`. Revoke is an RLS update setting `revoked_at`.
- `app.invitation_preview(token)` (signed-in callers only) returns `{ org_name, email, state }` for `/invite/[token]`, which shows the organization, refuses closed invitations with a message, and offers "Sign out and switch account" when the signed-in email differs.
- `app.accept_invitation` also refuses revoked invitations and applies the invitation's `role_profile` (the membership gets the profile and its roles; without a profile, roles are merged into an existing membership as before).
- The link's origin is the browser's (`window.location.origin`) for "Copy link", and the request's origin (else `APP_URL`, `src/lib/app-url.ts`) in the email, so both match the deployment the System Manager is using.

### 3.5 Address / Contact quick-create from party forms

Customer/Supplier/Company forms show Address & Contact cards (ERPNext `load_address_and_contact`) with "+ New" opening a drawer pre-filled with `dynamic_link = (party doctype, id)`; `is_primary_address`/`is_shipping_address`/`is_primary_contact` toggles apply the "unset previous" rule. Mapper `app.party_addresses(doctype, id)` returns rows ordered primary-first.
- **Built** (P1, Company): `addressContact: true` on the Company descriptor shows the Address & Contact rail on saved companies (`AddressContactRail`, `getAddressesAndContacts` → `app.party_addresses` / `app.party_contacts`). "+ New" opens `/[org]/setup/address/new?links.link_doctype=Company&links.link_id=<id>` (same for Contact): the full form with the link row seeded, not a drawer (`05-ui-ux.md`). The unset-previous rules run in the database (0121/0122). Company prints show the preferred billing address (`app.company_address`). e2e `party-rail.spec.ts`.

---

## 4. Posting rules

None. The Setup module writes no ledger rows. Its only posting-relevant job is **wiring default accounts on `companies`** (§3.1 B4, B9, B13) that the posting engine reads: receivable/payable (party rows), cash/bank (Payment Entry), `default_inventory_account`, `stock_received_but_not_billed`, `stock_adjustment_account`, `default_expense_account` (COGS), `default_income_account`, `round_off_account` + `round_off_cost_center`, `write_off_account`, `exchange_gain_loss_account`, depreciation/CWIP/ARBNB/disposal accounts, `cost_center`, `accounts_frozen_till_date` + `role_allowed_for_frozen_entries`, `valuation_method`, `enable_perpetual_inventory`. `app.make_gl_entries` fails fast with `Please set default <X> account in Company <Y>` when a needed default is null (ERPNext message texts).

---

## 5. Statuses

No submittable doctypes in this module (all `docstatus = 0` masters/singles). Status-like fields:

| Table | Field | Values |
|---|---|---|
| `org_members` | status | `active \| invited \| disabled` |
| `invitations` | derived | `pending \| accepted \| expired \| revoked` — `accepted_at` set → accepted; else `revoked_at` set → revoked; else `expires_at < now()` → expired; else pending (`src/lib/invitations.ts`, `app.invitation_preview`) |
| `contact` | status | `Passive \| Open \| Replied` (default Passive) |
| `email_digest` | enabled / next_send | badge "Next: <date>" when enabled |
| `fiscal_year` | disabled / auto_created | |
| masters (`branch`, `department`, `designation`, `holiday_list`, `letter_head`, `print_format`, `email_account`, `address`, `terms_and_conditions`) | disabled | hidden from link pickers when true |

---

## 6. Settings & defaults

Owned here: `global_defaults` (§2.17), `system_settings` (§2.18), `print_settings` (§2.13). Values seeded for every new org:

| Setting | Default | Source |
|---|---|---|
| Float precision | 3 | Frappe System Settings |
| Currency precision | from currency (2) | Frappe System Settings (`currency_precision` empty) |
| Date format | `dd-mm-yyyy` (or `country.date_format`) | Frappe |
| Time format | `HH:mm:ss` | Frappe |
| Number format | `#,###.##` (or `currency.number_format`) | Frappe |
| First day of week | `Sunday` | Frappe |
| Session defaults | `Company` | `install.py: add_company_to_session_defaults` |
| Global Defaults | `default_company` = first company, `default_currency`, `country`, `disable_rounded_total = 0`, `disable_in_words = 0`, `hide_currency_symbol = 0`, `use_posting_datetime_for_naming_documents = 1` | `install_fixtures.set_global_defaults`, doctype JSON |
| Print Settings | `with_letterhead = 1`, `allow_print_for_draft = 1`, `allow_print_for_cancelled = 0`, `add_draft_heading = 1`, `repeat_header_footer = 1`, `pdf_page_size = A4`, `font_size = 9`, `compact_item_print = 1`, `print_uom_after_quantity = 0`, `print_taxes_with_zero_amount = 0` | Frappe + `install.py` custom fields |
| Email | no org email account; platform sender used until one is configured; footer = ERPNext `default_mail_footer` text adapted | `install.py` |
| Company | `enable_perpetual_inventory = 1`, `valuation_method = FIFO`, `chart_of_accounts = Standard`, `reconciliation_takes_effect_on = Oldest Of Invoice Or Advance` | wizard + JSON defaults |

Pointers to module-owned settings (seeded in Stage A4, documented in their module docs): Accounts Settings (`01-accounts.md`), Selling Settings (`02-selling.md`), Buying Settings (`03-buying.md`), Stock Settings (`04-stock.md`), Manufacturing Settings (`05-manufacturing.md`), Projects Settings (`06-projects.md`). PLAN §5 lists the values.

---

## 7. Reports & dashboard (Home page)

No reports in the Setup sidebar. The **Home** workspace (`erpnext/setup/workspace/home/home.json`, roles: Desk User = every member) renders, in order:

1. **Onboarding checklist** — module onboarding `Organization Onboarding` ("Get to know ERPNext", roles System Manager). Steps (title — description — action):
   - Invite Users: *Invite your team* — "Add the people you work with and choose what they can see." — Create Entry (User) → our `/setup/users/invite`.
   - Complete Accounting Onboarding: *Get your books ready* — "Check your chart of accounts and taxes, and add the bank account you use." → `/accounts`.
   - Complete Selling Onboarding: *Make your first sale* — "Add an item and a customer, bill them and collect the payment." → `/selling`.
   - Complete Buying Onboarding: *Order from your suppliers* — "Add a supplier, order from them and pay their bill." → `/buying`.
   - Complete Stock Onboarding: *Keep track of your stock* — "Set up your warehouses and enter the stock you have today." → `/stock`.
   - Complete Manufacturing Onboarding: *Plan and run production* — "Write down what goes into a product and make it with a work order." → `/manufacturing`.
   - Complete Projects Onboarding: *Plan and deliver projects* — "Break a project into tasks and log the time your team spends." → `/projects`.
   - Complete Asset Onboarding: *Track what your business owns* — "Record an asset and see what it's worth year by year." → `/assets`.
   - Complete Quality Onboarding — **dropped** (Quality out of scope).
   Progress is stored in `onboarding_progress(org_id, step, completed_at, skipped_at)`; the card is hidden once all steps are complete/skipped or dismissed. Steps show only for modules enabled at onboarding.
2. **Chart "Profit and Loss"** (`erpnext/accounts/dashboard_chart/profit_and_loss/profit_and_loss.json`): Report chart over `Profit and Loss Statement`, filters `filter_based_on = Fiscal Year`, `from/to_fiscal_year = current FY`, `periodicity = Yearly`, company = session company; Bar; empty state "Your income and expenses over the year, and what's left as profit." → `app.report_profit_and_loss()` (P3).
3. **Number cards** (col 4 each):
   - **Annual Sales** (`erpnext/selling/number_card/annual_sales/annual_sales.json`): Σ `base_net_total` of Sales Orders, `docstatus = 1`, status ∉ {Draft, Cancelled, Closed}, `modified` this year, company = session company; % stats monthly.
   - **Annual Purchase** (`erpnext/buying/number_card/annual_purchase/annual_purchase.json`): Σ `base_net_total` of Purchase Orders, `transaction_date` this year, `docstatus = 1`, status ∉ {Draft, Cancelled, Closed}, company filter; monthly stats.
   - **Total Stock Value** (`erpnext/stock/number_card/total_stock_value/total_stock_value.json`): Σ `bin.stock_value`, no filters; daily stats.
   → `app.home_number_cards(company_id)`; cards render as empty-state placeholders until P4/P5/P6 ship.

Shortcuts/links on Home are empty in ERPNext (`shortcuts: []`, `links: []`); we add nothing.

---

## 8. UI notes

- **Company form tabs** (Tab Breaks in `company.json`): *Details* (implicit first tab: name, abbr, is_group, parent, currency, country, letter head, holiday list, logo/description, CoA selection, registration fields) · *Accounts* (default accounts, cost center, frozen entries, exchange gain/loss, assets) · *Buying and Selling* (terms, sales-return warehouse, default sales contact, credit limit, payment terms) · *Stock and Manufacturing* (perpetual inventory, inventory/adjustment/SRBNB accounts, valuation method, default warehouses, operating cost) · *Dashboard* (monthly target, total monthly sales, transaction heatmap) · *Accounts Closing* (frozen till date, role allowed). Right rail: Address & Contact cards. Actions: Create Default Tax Template, Delete Transactions (out of scope → hidden).
- **CoA selection step** (onboarding + new company): radio *Standard* / *Standard with Numbers* / `<country template(s)>`, with a read-only `TreeView` preview from `app.coa_template_preview(key)`; bank account name input validated against the template (`validate_bank_account`: cannot reuse an existing chart account name).
  - Built in the onboarding wizard's Company step:
    - A combobox lists `coa_templates_for_country` (country charts first, default preselected).
    - An indented read-only list previews the chosen template (`coa_template_preview`).
    - The Company form uses the `ChartOfAccounts` select narrowed by country.
    - The bank account input waits for B13 (P2).
- **Users page**: list + invite drawer (email, roles multi-select or role profile) + per-user panel (roles chips, user permissions tab, disable). Role Profile picker replaces roles.
  - Built as bespoke routes `src/app/(app)/[org]/setup/users/page.tsx` and `[userId]/page.tsx` (listed in `BUILT_PAGES` in `src/config/navigation.ts`) instead of a descriptor: a member is `org_members` + `auth.users` + `user_profile`, keyed by `user_id` rather than a doctype row id, and its email is only readable through the directory function.
  - List (`member-list.tsx`): search over name, email, profile and roles; Owner and status badges; rows open the panel.
  - Panel (`member-panel.tsx`): Role Profile select (choosing one shows and saves its roles; the Roles multi-select is read-only while a profile is set; clearing the profile keeps its roles as a starting point), Active toggle (disabled for the owner), Remove with a confirm dialog (hidden for the owner). Read-only with an info alert without write permission on User.
- **Role Permissions matrix** (Frappe `permission-manager` page): filter by doctype or role; rows = doctypes (grouped by module), columns = read/write/create/submit/cancel/amend/delete/if_owner toggles; "Reset to defaults" restores the seed; "Add new rule" picks role × doctype. Edits write `role_permissions`.
  - Built as the bespoke route `src/app/(app)/[org]/setup/role-permissions/page.tsx` (in `BUILT_PAGES`) with `permission-matrix.tsx`: the matrix edits many `role_permissions` rows at once, which no descriptor form models. System Manager only (others get an error alert, as Frappe restricts the page). Filters `?doctype=` / `?role=` (nuqs); nothing is listed until one is set. Each checkbox saves immediately; Submit/Cancel/Amend are disabled on non-submittable doctypes. Columns: Read, Write, Create, Delete, Submit, Cancel, Amend, Report, Export, Only If Creator. The Access doctypes are shown read-only with an info alert. "Reset to defaults" (confirm dialog) and "Add a new rule" (role × doctype, starts with Read).
- **User Permissions**: list grouped by user; "Add" dialog = user, doctype (Company/Warehouse/Cost Center…), record, applicable_for (all / one doctype), is_default, hide_descendants.
  - Built on the generic `DocList` / `DocForm` (not a dialog): the list shows the user's name and email and the record's title instead of ids, sorted by doctype. The member panel shows a "User Permissions" section (not a tab: the panel is one scrolling page of sections) with each row and an "Add user permission" button.
- **Holiday List form**: header fields + actions *Add Weekly Holidays*, *Add Local Holidays*, *Clear Table*; child grid; calendar preview coloured by `color`.
  - Built: the actions sit in the generic form "Actions" menu (descriptor `actions`, 05-ui-ux); results replace the Holidays grid and Total Holidays in the unsaved form, and Save persists them. The calendar preview is deferred to P8.
- **Department / Company**: `TreeView` with company filter (Department tree root is `All Departments`; `get_children` hides disabled unless toggled).
  - Built: both list routes have a List / Tree toggle (`?view=tree`). Department filters by Company (`?company_id=`), keeping the root above the company's departments, and has "Include disabled". "Add child" on a group opens the new form with the parent and company prefilled (the root takes the company from the filter, as `add_node` does). See 05-ui-ux `TreeView`.
- **Letter Head**: live preview of header/footer over an A4 frame; Image vs HTML toggle.
  - Built on the generic `DocForm`: "Letter Head Based On" / "Footer Based On" switch the HTML and image fields (`dependsOn`); the descriptor's `preview: "LetterHead"` adds the A4-width Preview panel below the form (`form-preview.tsx`), updated as you type.
- **Print Format**: read-only registry list with "Set as default" per doctype and a preview link to `/print/<doctype>/<sample>`.
  - Built on the generic `DocList` / `DocForm`: Default is a checkbox on the form (setting it clears the previous default) instead of a list action; previews come from a record's "More actions" → Print.
- **Email Account**: provider toggle (Resend / SMTP), "Send test email" action (Edge Function), default-outgoing switch.
  - Built on the generic `DocForm`: Resend only, so the Service select has one option; the API Key is a write-only password field with an "API Key Saved" indicator; "Send Test Email" is a form action backed by a Server Action (no Edge Function).
- **Email Digest**: checkbox groups mirroring ERPNext sections (Accounts → Sales/Purchase → Projects/Overdue POs), recipients multi-select of members, "Send now" preview (`get_digest_msg`).
- **Address / Contact**: full forms opened from the party rail with the link row pre-filled (no drawer); the Links grid is a normal child table with Dynamic Link cells.

---

## 9. Deviations from ERPNext

- **Deviation:** Site → Organization, Company → `companies` under `org_id`; Frappe `User`/`Role`/`User Permission` become `auth.users` + `user_profile` + `org_members.roles[]` + `roles` + `user_permissions` per org. Reason: multi-tenancy.
- **Deviation:** Only `permlevel 0` role permissions; no `select/print/email/share/import/set_user_permissions` flags; print/email allowed with read. Reason: simplicity.
- **Deviation:** Role permission edits change the org's `role_permissions` rows directly instead of creating Custom DocPerm copies; "Reset to defaults" re-copies the doctype's rows from `role_permission_template`. Reason: per-tenant table, same visible result.
- **Deviation:** Roles seeded are the 19 standard ones; Analytics, Shop Floor, HR, Academics, Delivery, Customer/Supplier website roles omitted. Reason: scope.
- **Deviation:** Every seeded (standard) role is protected from rename/delete, System Manager cannot be disabled, and the Access doctypes' permissions are fixed to System Manager (`permission_locked`). Reason: no Administrator account exists to recover from a lockout.
- **Deviation:** Emailing a record (form "Email", Frappe `CommunicationComposer`) attaches no PDF; the message links to the print view, which opens for signed-in members of the organization only. Sends are recorded in `email_log`, not as Communication documents with a timeline. Reason: no server-side PDF rendering yet; Communication is part of the out-of-scope inbox.
- **Deviation:** Disabling a role keeps it assigned (it simply grants nothing) instead of deleting the Has Role rows. Reason: reversible.
- **Deviation:** Authorization Rule limited to Grand Total on SO/PO/SI/PI with role/user approver; discount-based rules, Quotation/DN/PR, employee/designation targets dropped. Reason: Pricing/HR out of scope.
- **Deviation:** Print Format = one server-rendered modern template per doctype; no Print Format Builder, Jinja/JS formats, `Classic`/`Standard` legacy formats or raw printing. Reason: `05-ui-ux.md`, simplicity.
- **Deviation:** Print Settings `print_style` fixed to Modern; Letter Head `header_script/footer_script` dropped; HTML sanitised. Reason: security.
- **Deviation:** Email Account is outbound-only (Resend API, secrets in Supabase Vault; SMTP deferred); no IMAP/POP, auto-reply, append-to, Communication inbox, unsubscribe footer or delivery tracking. The From address is always the account's (verified) address. The default footer is empty, not ERPNext's "Sent via ERPNext" `default_mail_footer`. Reason: PLAN §4; the provider only sends from verified domains.
- **Deviation:** Email Template / Terms and Conditions render a handlebars-style subset instead of Jinja. Reason: no server-side Python; safety.
- **Deviation:** Email Digest drops `issue`, `calendar_events`, `todo_list`, `notifications`, `add_quote`; no 24h card cache. Reason: Support/Frappe-desk features out of scope.
- **Deviation:** Address Template doctype replaced by code (`src/lib/format/address.ts`) covering the default + 9 country templates. Reason: simplicity.
- **Deviation:** Holiday List "Add Local Holidays" uses the `date-holidays` package for the list's country; subdivisions optional, English names only. Reason: Python `holidays` package not available.
- **Deviation:** Default payable account selected deterministically (`Creditors`, Liability) instead of ERPNext's unordered `account_type = Payable` lookup. Reason: Postgres determinism.
- **Deviation:** Stock Entry Types, Party Types and fixtures for out-of-scope features (variants, CRM, Support, Share management, Incoterms, Delivery Trip template, Currency Exchange Settings, Pegged Currencies) are not seeded. Reason: scope.
- **Deviation:** UOMs: curated subset by default with an "Import all" action (ERPNext seeds all 239 + 235 conversions). Reason: PLAN §5.
- **Deviation:** Country, Currency, UOM template and CoA templates are global read-only tables; per-org `enabled` flag lives in `org_currency`. Reason: multi-tenancy.
- **Deviation:** Module Profiles / `block_modules` dropped; module visibility derives from permissions. Reason: simplicity.
- **Deviation:** No demo data stage and no demo-company deletion guard; P11 demo generator instead. Reason: scope.
- **Deviation:** Fiscal Year auto-creation and company monthly-sales cache run as pg_cron SQL jobs rather than Frappe scheduler. Reason: Postgres.
- **Deviation:** The setup wizard has no persona/Modules slide (module visibility derives from permissions), no demo-data checkbox and no language slide (the organization language defaults to `en`). Invites are part of the wizard (ERPNext invites from the User list later). Reason: scope; invites save a step for multi-user tenants.
- **Deviation:** The wizard's fiscal year end is the start + 12 months − 1 day, not the end date from `erpnext.setup.fiscal_years`. ERPNext's own start-date handler computes it the same way, and the map's `02-28` end for South Africa would fail the one-year rule in leap years. Reason: consistency with the Fiscal Year validation.
- **Deviation:** Wizard invites pick a role profile only (no individual roles). Reason: the organization's roles do not exist yet; profiles are the standard five, and roles can be edited on the Users page afterwards.

---

## 10. Implementation checklist

### P0 (foundation; tables that the shell needs)

- [x] `organizations`, `org_members`, `roles`, `role_permissions`, `user_permissions`, `invitations`, `user_profile` migrations + RLS + `app.has_perm/record_allowed/company_allowed` (per `01-tenancy-auth-rls.md`) — `0002_framework_tenancy.sql`, `0003_framework_function_grants.sql`; also `role_profile` table, `doctype_meta`, `app.accept_invitation()` + `public.accept_invitation()` RPC, custom access token hook
- [x] `companies` table (full column set §2.1, tree trigger, validations as constraints/triggers) + RLS — `0100_setup_company.sql`: `validate_abbr`, `validate_coa_input`, `set_chart_of_accounts`, `validate_parent_company`, `set_reporting_currency`, `validate_sdbnb_configuration` (account required). Deferred to the migrations that create the referenced tables: FKs on the `*_account_id` / `*_cost_center_id` / `*_warehouse_id` / letter head / holiday list / terms / contact / payment terms columns, `validate_default_accounts`, `validate_advance_account_currency` (P3 `account`), `validate_warehouses` (P2 `warehouse`), `validate_currency` (first submittable transaction), `cant_change_valuation_method` + `validate_perpetual_inventory` + `validate_inventory_account_settings` (P4 `stock_ledger_entry`), SDBNB outstanding-DN check (P5), `on_trash` cascades
- [x] Global tables `country`, `currency`, `uom_template`, `uom_conversion_template` + per-org `org_currency` — generated `0009_framework_reference_data.sql` (§2.21–2.22), company links in `0101_setup_company_reference_links.sql`; forms read options from the tables (`src/lib/queries/reference.ts`). `coa_template` moved to the P1 CoA loader item
- [x] `role_profile` table + seed; default permissions via `role_permission_template` (table + `app.sync_role_permissions()` done in `0004`; each doctype migration adds its rows — Company done) — `0102_setup_role_profiles.sql`: global `role_profile_template` (5 ERPNext profiles), copied into every org by `app.sync_role_permissions()` without overwriting tenant edits
- [x] `system_settings`, `global_defaults` tables + defaults — `0103_setup_global_defaults.sql`, `0104_setup_system_settings.sql` (§2.17–2.18): single doctypes seeded per org, pages at `/[org]/setup/global-defaults` and `/[org]/setup/system-settings`
- [x] Auth: email+password, magic link, `proxy.ts` session refresh, `acceptInvitation()`, custom access token hook — `/login` (Password / Email link tabs), `/signup`, `/forgot-password`, `/update-password`, `/auth/callback` (PKCE `code` or `token_hash`), `/auth/signout`, `/invite/[token]`; Server Actions in `src/lib/actions/auth.ts` + `organization.ts`
- [x] P0 precursor of §3.1 Stage A: `app.create_organization(jsonb)` (`0005`, reserved slugs `0006`) creates the org, seeds role permissions and makes the caller owner + System Manager; `/setup` form calls it and refreshes the session. P1 wraps it as Stage A of `app.provision_organization()` (0116) and replaces the form with the onboarding wizard (0117 drops the public RPC)
- [x] App shell: icon rail (org switcher, 7 modules + Setup), module sidebar from `src/config/navigation.ts` (ERPNext sidebars, out-of-scope items removed, phase per PLAN §7), top bar (company switcher → `hx_company` cookie, Ctrl/⌘K command palette with Go to / Create / Records, user menu), placeholder pages `/[org]/[module]/[...slug]`, `src/stores/session.ts` + `ui.ts`
- [x] Doctype framework proven on Company — `0007_framework_naming.sql` (`naming_series`, `app.next_name`), `0008_framework_doc_engine.sql` (`app.save_doc` / `app.delete_doc`), `src/doctypes/` (`defineDoctype`, `schemaFor`, registry, `setup/company.ts`: Details tab + Chart of Accounts section only; Accounts/Stock default Link fields wait for their tables), generic `DocList` / `DocForm` / `ChildTable` / `LinkField` on `/[org]/setup/company[/new|/<id>]`. Company "new" goes through `app.create_company()` (descriptor `create` hook, 0116).
- [x] CI and deploys (`06-deployment-ops.md`): `.github/workflows/ci.yml` (Biome, tsc, Vitest; clean `supabase db reset` + pgTAP, types drift check, doctype/DB consistency suite `src/doctypes/doctypes.db.test.ts`, `next build`, Playwright smoke `e2e/smoke.spec.ts`), gated `deploy-db.yml`, Dependabot, PR template. Netlify site and production secrets are owner setup steps
- [x] Custom claims + token refresh after role edits — the org layout uses `org_members.roles`; `ClaimsRefresher` refreshes the session once when the JWT `app.orgs` roles are stale (`01-tenancy-auth-rls.md`)
- [x] Command palette (Ctrl/⌘K): Go to, Create, Records (`searchDocs`) — `05-ui-ux.md`

### P1 (Setup module)

Decisions (2026-10-14):
- **Staged provisioning.** `app.provision_organization()` seeds only tables that exist in P1. Each later migration that creates a seeded table (item groups, territories, groups, accounts, cost centers, warehouses, modes of payment, price lists, UOMs, module settings) adds its seed step to provisioning and backfills existing orgs. §3.1 is the target end state, not the P1 deliverable.
- **Order:** Users and invites + Roles, Role Profiles and the Role Permissions matrix, then the Organization doctypes (Branch, Designation, Department, Holiday List), then the onboarding wizard and provisioning, then Printing and Email.
- **Email sending (2026-10-15):** Server Actions send through a server-only module (`src/lib/email/`) with the Resend API; keys live in Vault and only that module reads them (service role). An Edge Function comes later, for the Email Digest only. SMTP and Email Digest are deferred.
- **Workflow:** one branch and PR per item, merged when CI is green.

- [x] `app.provision_organization(jsonb)` implementing §3.1 Stages A–C (idempotent, single transaction) + pgTAP test asserting counts/names of every seeded record — `0116_setup_provision_organization.sql`, `21_provision_organization.test.sql`; staged: the P1 steps (A1-A4, A18, B1, B2, B8, B11, C3, C5, C6) are built, and each P2+ migration adds its steps and assertions, including every `companies.*_account_id` default
- [ ] `app.create_company(jsonb)` (§3.3) incl. parent-company CoA copy and "Create Default Tax Template" action — the function and the Company form's create hook are built (0116); the chart, defaults, parent copy and tax templates wait for the P2 tables
- [x] CoA template loader: global `coa_template` table (generated migration like `0009`), `supabase/seed/coa/verified/*.json` (73 files) + the two standard Python charts; `app.coa_template_preview(key)`, `app.coa_templates_for_country(country)` — `0115_setup_coa_templates.sql` (§3.2, 1.5 MB: 41 templates), `scripts/gen-coa-templates.mjs`, Company `ChartOfAccounts` select
- [ ] Country-wise tax seed (`country_wise_tax.json`) → `app.create_default_tax_templates(company_id)`
- [x] Onboarding wizard UI (Account → Organization → Company → Modules → Invite) with progress states "Setting up the basics / Creating your company / Applying recommended settings" — `/setup` stepper Organization → Company → Invite (05-ui-ux; Modules dropped, §9), `provisionOrganization` Server Action, country fiscal-year defaults (`src/lib/fiscal-year.ts`), chart preview, `0117` drops the P0 RPC; e2e `onboarding.spec.ts`, and `createOrganization` in `e2e/helpers.ts` now drives the wizard (every spec's organization has a first company)
- [ ] Company: descriptor, Zod, form with 6 tabs, list, Address & Contact rail — the rail is built (§3.5) and the Buying and Selling tab holds Default Sales Contact; the remaining default-account and warehouse fields wait for their P2/P3 tables
- [x] Users: list, invite drawer, member panel, disable/remove, role profile assignment; `invitations` resend/revoke — `0106_setup_users.sql` (§2.6, §8), `0107_setup_invitations.sql` (§3.4, link-only delivery)
- [x] Branch: table, descriptor, list/form — `0110_setup_branch.sql` (§2.2), descriptor `branch.ts`
- [x] Department: table (tree), seed root + 13 per company, TreeView — `0112_setup_department.sql` (§2.3), descriptor `department.ts`, generic `tree-view.tsx`
- [x] Designation: table, 31-row seed, list/form — `0111_setup_designation.sql` (§2.4), org seed trigger + backfill
- [x] Holiday List + Holiday: tables, validations trigger, actions (weekly off, local holidays, clear), `app.is_holiday()` — `0113_setup_holiday_list.sql` (§2.5), descriptor `holiday-list.ts` with form actions, `date-holidays` Server Action, Company `default_holiday_list_id` FK
- [x] Roles: list/form (custom roles), Role Profile list/form — `0105_setup_roles.sql` (§2.7), descriptors `role.ts` / `role-profile.ts`, `MultiSelect` field type
- [x] Role Permissions matrix page + Server Actions + "reset to defaults" — `0108_setup_role_permission_manager.sql` (§2.8, §8), per-doctype reset
- [x] User Permissions: list/form, picker for Company/Warehouse/Cost Center — `0109_setup_user_permissions.sql` (§2.9), descriptor `user-permission.ts`, `DynamicLink` field type; Warehouse/Cost Center join the picker with their P2 tables
- [x] Authorization Rule: table, descriptor, list/form, `app.validate_approving_authority` (0125; wired into the P5/P6 submit paths)
- [x] Letter Head: table, storage upload, preview, default trigger
- [x] Print Format registry table + `/print/[doctype]/[id]` route shell + generic record template; standard templates added per module
- [x] Print Settings: table + SettingsPage
- [x] Email Account: table, Vault secret handling, Edge Function `send-email` (Resend + SMTP), test-send action — `0123_setup_email_account.sql` (§2.14), descriptor `email-account.ts`, `email_log`; sending is a server-only module (`src/lib/email/transport.ts`, `sender.ts`) instead of an Edge Function; SMTP deferred
- [x] Email Template: table, handlebars-subset renderer (`src/lib/email/render.ts`), app-level `Invitation` + `Send Document` templates, form "Email" action — `0124_setup_email_template.sql` (§2.15); the form "Email" action is `email-dialog.tsx` + `src/lib/actions/email.ts` (§2.15); invitations are emailed (§3.4)
- [ ] Email Digest + Recipient: tables, `app.email_digest_payload()`, Edge Function `send-email-digest`, pg_cron daily job, "Send now" preview
- [ ] Global Defaults + System Settings pages (**done in P0**, single-doctype forms); Settings pointer list in sidebar
- [x] Address + `address_link`: tables, naming, preferred/company-address triggers, `app.party_addresses()`, `app.company_address()`, `formatAddress()` TS — `0121_setup_address.sql` (§2.19), descriptor `address.ts`
- [x] Contact + `contact_email` + `contact_phone` + `contact_link`: tables, naming, primary triggers, user match, `app.party_contacts()` — `0122_setup_contact.sql` (§2.20), descriptor `contact.ts`, Company `default_sales_contact_id` FK
- [x] Fiscal Year + Fiscal Year Company: tables, validations, `app.auto_create_fiscal_year()` pg_cron daily — `0114_accounts_fiscal_year.sql` (§2.23), descriptor `fiscal-year.ts`, field triggers
- [ ] Terms and Conditions: table, validation, renderer
- [ ] Home page: onboarding checklist (`onboarding_progress`), number-card + P&L chart placeholders wired to `app.home_number_cards()` / `app.report_profit_and_loss()` as modules land
- [ ] `doctype_meta` rows + `role_permissions` upserts for every table above; `supabase gen types`; descriptors in `src/doctypes/setup/*.ts`
- [ ] RLS pgTAP for every Setup table (cross-org isolation, owner cannot be demoted)
