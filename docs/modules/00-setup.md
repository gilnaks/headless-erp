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
| Shared masters | `address`, `contact`, `contact_email`, `contact_phone`, `dynamic_link`, `currency` (global), `country` (global), `fiscal_year`, `fiscal_year_company`, `terms_and_conditions` | P1 tables (UI for Address/Contact/T&C/Fiscal Year ships in P2 per PLAN §7) |
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

### 2.4 Designation → `designation`

- **Kind:** master. **Naming:** `field:designation_name`. Fields: `designation_name text reqd unique`, `description text`. No `.py` logic.
- Seeded with 31 rows from `erpnext/setup/setup_wizard/data/designation.txt` (Accountant … Vice President; full list in §3.1 A18).
- Permissions (JSON): HR User rwc, HR Manager rwcd, Sales User r. We seed System Manager rwcd, Sales User r.

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

### 2.14 Email Account → `email_account` (outbound only)

Frappe `Email Account` plus ERPNext custom field `company` (`install.py: create_custom_company_links()`). Inbound (IMAP/POP, auto-reply, append-to) is **out** (PLAN §4).

| fieldname | type | req | default | notes |
|---|---|---|---|---|
| email_account_name | text | ✔ | | = name |
| email_id | text | ✔ | | sender address; must be a verified domain/sender at the provider |
| company_id | uuid → companies | | null | ERPNext custom field; null = org-wide |
| provider | text check | ✔ | `'resend'` | `resend \| smtp` (**Deviation:** Frappe `service` presets replaced) |
| api_key_secret | uuid → vault.secrets | | | Resend API key stored in Supabase Vault |
| smtp_server, smtp_port, use_tls, use_ssl_for_outgoing, login_id, password_secret, no_smtp_authentication | text / int / bool / uuid | | 587 / true / false | SMTP branch |
| enable_outgoing | boolean | | true | |
| default_outgoing | boolean | | | one per org (trigger) |
| always_use_account_email_id_as_sender | boolean | | false | else sender = user's email with account as envelope sender |
| always_use_account_name_as_sender_name | boolean | | false | |
| add_signature / signature | boolean / text (html) | | false | |
| footer | text (html) | | ERPNext `default_mail_footer` | |
| send_unsubscribe_message | boolean | | true | |
| track_email_status | boolean | | true | provider webhooks → `communication.status` |
| enabled | boolean | | true | |

- Sending runs in Edge Function `send-email` (service role; reads Vault). Resolution: document's company account → org default → platform account (app-level sender, used for invitations).
- Permissions: System Manager rwcd. List: name, email_id, company, provider, default_outgoing.

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

### 2.19 Address → `address` + `dynamic_link`

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

`dynamic_link` (shared child for Address and Contact): `parent_doctype text check ('Address','Contact')`, `parent_id uuid`, `link_doctype text`, `link_id uuid`, `link_title text`, `idx`. Dedupe `(parent, link_doctype, link_id)`. Allowed `link_doctype` in scope: Customer, Supplier, Company, Sales Partner (P5), Lead/Prospect are out.

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
- List: name, address_type, city, country, linked party.

### 2.20 Contact → `contact` + `contact_email` + `contact_phone` + `dynamic_link`

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
- List: full_name, email_id, mobile_no, linked party, is_primary_contact.

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

Input `p`: `{ org: {name, slug, country, currency, time_zone, language}, owner_user_id, company: {company_name, abbr, fy_start_date, fy_end_date, chart_of_accounts, bank_account}, modules: [...], invites: [{email, roles[]}] }`.

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

Stored as `supabase/seed/coa/standard.json` (and `standard_with_numbers.json`, plus the 77 verified country files from `chart_of_accounts/verified/`). Tree with `[account_type | account_category]`; `*` = group:

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

### 3.3 Company creation side-effects (second and later companies) → `app.create_company(jsonb)`

Same as Stage B (B2–B13) without the Fiscal Year (B1); `global_defaults.default_company_id` unchanged. When `parent_company` is given: `create_chart_of_accounts_based_on = 'Existing Company'`, `existing_company = parent` (`set_chart_of_accounts`) and the chart is copied from the parent's account tree (`get_account_tree_from_existing_company`, same `account_type/root_type/tax_rate/account_number/account_currency` per node); `reporting_currency` = parent's. Changing `country` later re-runs B7 (`frappe.flags.country_change`). ERPNext's `create_default_tax_template` is also exposed as a form action ("Create Default Tax Template") → `app.create_default_tax_templates(company_id)`.

### 3.4 Invite flow

Owner/System Manager → `invitations(org_id, email, roles[], role_profile?, token, expires_at = now + 7 days)` → email via platform sender using template `Invitation` with `/invite/[token]` → recipient signs up/in → Server Action `acceptInvitation(token)`: verifies not expired/accepted, inserts `org_members(status = active, roles)`, `user_profile` if missing, sets `accepted_at`, forces token refresh. Resend / revoke actions on the Users page. Mirrors Frappe's "Add User → welcome email" (`invite_users` onboarding step: *Invite your team — Add the people you work with and choose what they can see*).

**Built (P1, `0107_setup_invitations.sql`) — link-only delivery until the Email track:** no email is sent. The System Manager copies `/invite/<token>` from the invite drawer (or from the invitation row) and shares it.

- `app.create_invitation(p_org, p_email, p_roles, p_role_profile)` (System Manager only, else `42501`) returns `{ id, token }`. It raises `roles_required` (neither roles nor profile), `already_member` (the email belongs to an active member; disabled members can be re-invited and are re-activated on accept), `invite_pending` (an open invitation exists; resend it instead), `invalid_role` and `invalid_email`. An expired open invitation is revoked automatically so a new one can be created. A partial unique index keeps one open invitation per `(org_id, email)`.
- `invitations` gained `role_profile` (FK to `role_profile`, cascades on rename, set null on delete) and `revoked_at`. A trigger lower-cases the email, copies the profile's roles into `roles` when a profile is set, dedupes, and validates roles.
- `app.resend_invitation(id)` issues a new token and a fresh 7-day expiry (the old link stops working); accepted or revoked invitations raise `invitation_closed`. Revoke is an RLS update setting `revoked_at`.
- `app.invitation_preview(token)` (signed-in callers only) returns `{ org_name, email, state }` for `/invite/[token]`, which shows the organization, refuses closed invitations with a message, and offers "Sign out and switch account" when the signed-in email differs.
- `app.accept_invitation` also refuses revoked invitations and applies the invitation's `role_profile` (the membership gets the profile and its roles; without a profile, roles are merged into an existing membership as before).
- The link's origin is the browser's (`window.location.origin`), so it matches the deployment the System Manager is using.

### 3.5 Address / Contact quick-create from party forms

Customer/Supplier/Company forms show Address & Contact cards (ERPNext `load_address_and_contact`) with "+ New" opening a drawer pre-filled with `dynamic_link = (party doctype, id)`; `is_primary_address`/`is_shipping_address`/`is_primary_contact` toggles apply the "unset previous" rule. Mapper `app.party_addresses(doctype, id)` returns rows ordered primary-first.

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
- **Users page**: list + invite drawer (email, roles multi-select or role profile) + per-user panel (roles chips, user permissions tab, disable). Role Profile picker replaces roles.
  - Built as bespoke routes `src/app/(app)/[org]/setup/users/page.tsx` and `[userId]/page.tsx` (listed in `BUILT_PAGES` in `src/config/navigation.ts`) instead of a descriptor: a member is `org_members` + `auth.users` + `user_profile`, keyed by `user_id` rather than a doctype row id, and its email is only readable through the directory function.
  - List (`member-list.tsx`): search over name, email, profile and roles; Owner and status badges; rows open the panel.
  - Panel (`member-panel.tsx`): Role Profile select (choosing one shows and saves its roles; the Roles multi-select is read-only while a profile is set; clearing the profile keeps its roles as a starting point), Active toggle (disabled for the owner), Remove with a confirm dialog (hidden for the owner). Read-only with an info alert without write permission on User.
- **Role Permissions matrix** (Frappe `permission-manager` page): filter by doctype or role; rows = doctypes (grouped by module), columns = read/write/create/submit/cancel/amend/delete/if_owner toggles; "Reset to defaults" restores the seed; "Add new rule" picks role × doctype. Edits write `role_permissions`.
  - Built as the bespoke route `src/app/(app)/[org]/setup/role-permissions/page.tsx` (in `BUILT_PAGES`) with `permission-matrix.tsx`: the matrix edits many `role_permissions` rows at once, which no descriptor form models. System Manager only (others get an error alert, as Frappe restricts the page). Filters `?doctype=` / `?role=` (nuqs); nothing is listed until one is set. Each checkbox saves immediately; Submit/Cancel/Amend are disabled on non-submittable doctypes. Columns: Read, Write, Create, Delete, Submit, Cancel, Amend, Report, Export, Only If Creator. The Access doctypes are shown read-only with an info alert. "Reset to defaults" (confirm dialog) and "Add a new rule" (role × doctype, starts with Read).
- **User Permissions**: list grouped by user; "Add" dialog = user, doctype (Company/Warehouse/Cost Center…), record, applicable_for (all / one doctype), is_default, hide_descendants.
  - Built on the generic `DocList` / `DocForm` (not a dialog): the list shows the user's name and email and the record's title instead of ids, sorted by doctype. The member panel shows a "User Permissions" section (not a tab: the panel is one scrolling page of sections) with each row and an "Add user permission" button.
- **Holiday List form**: header fields + actions *Add Weekly Holidays*, *Add Local Holidays*, *Clear Table*; child grid; calendar preview coloured by `color`.
- **Department / Company**: `TreeView` with company filter (Department tree root is `All Departments`; `get_children` hides disabled unless toggled).
- **Letter Head**: live preview of header/footer over an A4 frame; Image vs HTML toggle.
- **Print Format**: read-only registry list with "Set as default" per doctype and a preview link to `/print/<doctype>/<sample>`.
- **Email Account**: provider toggle (Resend / SMTP), "Send test email" action (Edge Function), default-outgoing switch.
- **Email Digest**: checkbox groups mirroring ERPNext sections (Accounts → Sales/Purchase → Projects/Overdue POs), recipients multi-select of members, "Send now" preview (`get_digest_msg`).
- **Address / Contact** drawers reused from party forms; `dynamic_link` grid shown as chips.

---

## 9. Deviations from ERPNext

- **Deviation:** Site → Organization, Company → `companies` under `org_id`; Frappe `User`/`Role`/`User Permission` become `auth.users` + `user_profile` + `org_members.roles[]` + `roles` + `user_permissions` per org. Reason: multi-tenancy.
- **Deviation:** Only `permlevel 0` role permissions; no `select/print/email/share/import/set_user_permissions` flags; print/email allowed with read. Reason: simplicity.
- **Deviation:** Role permission edits change the org's `role_permissions` rows directly instead of creating Custom DocPerm copies; "Reset to defaults" re-copies the doctype's rows from `role_permission_template`. Reason: per-tenant table, same visible result.
- **Deviation:** Roles seeded are the 19 standard ones; Analytics, Shop Floor, HR, Academics, Delivery, Customer/Supplier website roles omitted. Reason: scope.
- **Deviation:** Every seeded (standard) role is protected from rename/delete, System Manager cannot be disabled, and the Access doctypes' permissions are fixed to System Manager (`permission_locked`). Reason: no Administrator account exists to recover from a lockout.
- **Deviation (temporary):** Inviting a user creates a copyable link instead of sending a welcome email. Reason: email sending is deferred to the Email track (P1 decision); the invitation row and token are already what the email will carry.
- **Deviation:** Disabling a role keeps it assigned (it simply grants nothing) instead of deleting the Has Role rows. Reason: reversible.
- **Deviation:** Authorization Rule limited to Grand Total on SO/PO/SI/PI with role/user approver; discount-based rules, Quotation/DN/PR, employee/designation targets dropped. Reason: Pricing/HR out of scope.
- **Deviation:** Print Format = one server-rendered modern template per doctype; no Print Format Builder, Jinja/JS formats, `Classic`/`Standard` legacy formats or raw printing. Reason: `05-ui-ux.md`, simplicity.
- **Deviation:** Print Settings `print_style` fixed to Modern; Letter Head `header_script/footer_script` dropped; HTML sanitised. Reason: security.
- **Deviation:** Email Account is outbound-only (Resend API or SMTP, secrets in Supabase Vault); no IMAP/POP, auto-reply, append-to, Communication inbox. Reason: PLAN §4.
- **Deviation:** Email Template / Terms and Conditions render a handlebars-style subset instead of Jinja. Reason: no server-side Python; safety.
- **Deviation:** Email Digest drops `issue`, `calendar_events`, `todo_list`, `notifications`, `add_quote`; no 24h card cache. Reason: Support/Frappe-desk features out of scope.
- **Deviation:** Address Template doctype replaced by code (`src/lib/format/address.ts`) covering the default + 9 country templates. Reason: simplicity.
- **Deviation:** Holiday List "Add Local Holidays" uses a TS holidays library for the org country; subdivisions optional. Reason: Python `holidays` package not available.
- **Deviation:** Default payable account selected deterministically (`Creditors`, Liability) instead of ERPNext's unordered `account_type = Payable` lookup. Reason: Postgres determinism.
- **Deviation:** Stock Entry Types, Party Types and fixtures for out-of-scope features (variants, CRM, Support, Share management, Incoterms, Delivery Trip template, Currency Exchange Settings, Pegged Currencies) are not seeded. Reason: scope.
- **Deviation:** UOMs: curated subset by default with an "Import all" action (ERPNext seeds all 239 + 235 conversions). Reason: PLAN §5.
- **Deviation:** Country, Currency, UOM template and CoA templates are global read-only tables; per-org `enabled` flag lives in `org_currency`. Reason: multi-tenancy.
- **Deviation:** Module Profiles / `block_modules` dropped; module visibility derives from permissions. Reason: simplicity.
- **Deviation:** No demo data stage and no demo-company deletion guard; P11 demo generator instead. Reason: scope.
- **Deviation:** Fiscal Year auto-creation and company monthly-sales cache run as pg_cron SQL jobs rather than Frappe scheduler. Reason: Postgres.

---

## 10. Implementation checklist

### P0 (foundation; tables that the shell needs)

- [x] `organizations`, `org_members`, `roles`, `role_permissions`, `user_permissions`, `invitations`, `user_profile` migrations + RLS + `app.has_perm/record_allowed/company_allowed` (per `01-tenancy-auth-rls.md`) — `0002_framework_tenancy.sql`, `0003_framework_function_grants.sql`; also `role_profile` table, `doctype_meta`, `app.accept_invitation()` + `public.accept_invitation()` RPC, custom access token hook
- [x] `companies` table (full column set §2.1, tree trigger, validations as constraints/triggers) + RLS — `0100_setup_company.sql`: `validate_abbr`, `validate_coa_input`, `set_chart_of_accounts`, `validate_parent_company`, `set_reporting_currency`, `validate_sdbnb_configuration` (account required). Deferred to the migrations that create the referenced tables: FKs on the `*_account_id` / `*_cost_center_id` / `*_warehouse_id` / letter head / holiday list / terms / contact / payment terms columns, `validate_default_accounts`, `validate_advance_account_currency` (P3 `account`), `validate_warehouses` (P2 `warehouse`), `validate_currency` (first submittable transaction), `cant_change_valuation_method` + `validate_perpetual_inventory` + `validate_inventory_account_settings` (P4 `stock_ledger_entry`), SDBNB outstanding-DN check (P5), `on_trash` cascades
- [x] Global tables `country`, `currency`, `uom_template`, `uom_conversion_template` + per-org `org_currency` — generated `0009_framework_reference_data.sql` (§2.21–2.22), company links in `0101_setup_company_reference_links.sql`; forms read options from the tables (`src/lib/queries/reference.ts`). `coa_template` moved to the P1 CoA loader item
- [x] `role_profile` table + seed; default permissions via `role_permission_template` (table + `app.sync_role_permissions()` done in `0004`; each doctype migration adds its rows — Company done) — `0102_setup_role_profiles.sql`: global `role_profile_template` (5 ERPNext profiles), copied into every org by `app.sync_role_permissions()` without overwriting tenant edits
- [x] `system_settings`, `global_defaults` tables + defaults — `0103_setup_global_defaults.sql`, `0104_setup_system_settings.sql` (§2.17–2.18): single doctypes seeded per org, pages at `/[org]/setup/global-defaults` and `/[org]/setup/system-settings`
- [x] Auth: email+password, magic link, `proxy.ts` session refresh, `acceptInvitation()`, custom access token hook — `/login` (Password / Email link tabs), `/signup`, `/forgot-password`, `/update-password`, `/auth/callback` (PKCE `code` or `token_hash`), `/auth/signout`, `/invite/[token]`; Server Actions in `src/lib/actions/auth.ts` + `organization.ts`
- [x] P0 precursor of §3.1 Stage A: `app.create_organization(jsonb)` (`0005`, reserved slugs `0006`) creates the org, seeds role permissions and makes the caller owner + System Manager; `/setup` form calls it and refreshes the session. P1 replaces it with `app.provision_organization()`
- [x] App shell: icon rail (org switcher, 7 modules + Setup), module sidebar from `src/config/navigation.ts` (ERPNext sidebars, out-of-scope items removed, phase per PLAN §7), top bar (company switcher → `hx_company` cookie, Ctrl/⌘K command palette with Go to / Create / Records, user menu), placeholder pages `/[org]/[module]/[...slug]`, `src/stores/session.ts` + `ui.ts`
- [x] Doctype framework proven on Company — `0007_framework_naming.sql` (`naming_series`, `app.next_name`), `0008_framework_doc_engine.sql` (`app.save_doc` / `app.delete_doc`), `src/doctypes/` (`defineDoctype`, `schemaFor`, registry, `setup/company.ts`: Details tab + Chart of Accounts section only; Accounts/Stock default Link fields wait for their tables), generic `DocList` / `DocForm` / `ChildTable` / `LinkField` on `/[org]/setup/company[/new|/<id>]`. **Company "new" currently goes through `save_doc` (plain insert, no CoA/fiscal year/warehouses); P1 swaps the create path for `app.create_company()`.**
- [x] CI and deploys (`06-deployment-ops.md`): `.github/workflows/ci.yml` (Biome, tsc, Vitest; clean `supabase db reset` + pgTAP, types drift check, doctype/DB consistency suite `src/doctypes/doctypes.db.test.ts`, `next build`, Playwright smoke `e2e/smoke.spec.ts`), gated `deploy-db.yml`, Dependabot, PR template. Netlify site and production secrets are owner setup steps
- [x] Custom claims + token refresh after role edits — the org layout uses `org_members.roles`; `ClaimsRefresher` refreshes the session once when the JWT `app.orgs` roles are stale (`01-tenancy-auth-rls.md`)
- [x] Command palette (Ctrl/⌘K): Go to, Create, Records (`searchDocs`) — `05-ui-ux.md`

### P1 (Setup module)

Decisions (2026-10-14):
- **Staged provisioning.** `app.provision_organization()` seeds only tables that exist in P1. Each later migration that creates a seeded table (item groups, territories, groups, accounts, cost centers, warehouses, modes of payment, price lists, UOMs, module settings) adds its seed step to provisioning and backfills existing orgs. §3.1 is the target end state, not the P1 deliverable.
- **Order:** Users and invites + Roles, Role Profiles and the Role Permissions matrix, then the Organization doctypes (Branch, Designation, Department, Holiday List), then the onboarding wizard and provisioning, then Printing and Email.
- **Email sending deferred:** Email Account and Email Template tables and UI are built; the provider (Edge Function, Vault) comes later.
- **Workflow:** one branch and PR per item, merged when CI is green.

- [ ] `app.provision_organization(jsonb)` implementing §3.1 Stages A–C (idempotent, single transaction) + pgTAP test asserting counts/names of every seeded record and every `companies.*_account_id` default
- [ ] `app.create_company(jsonb)` (§3.3) incl. parent-company CoA copy and "Create Default Tax Template" action
- [ ] CoA template loader: global `coa_template` table (generated migration like `0009`, ~9.4 MB of source JSON), `supabase/seed/coa/*.json` from `verified/` (77 files) + `standard`, `standard_with_numbers`; `app.coa_template_preview(key)`, `app.coa_templates_for_country(country)`
- [ ] Country-wise tax seed (`country_wise_tax.json`) → `app.create_default_tax_templates(company_id)`
- [ ] Onboarding wizard UI (Account → Organization → Company → Modules → Invite) with progress states "Setting up the basics / Creating your company / Applying recommended settings"
- [ ] Company: descriptor, Zod, form with 6 tabs, list, Address & Contact rail
- [x] Users: list, invite drawer, member panel, disable/remove, role profile assignment; `invitations` resend/revoke — `0106_setup_users.sql` (§2.6, §8), `0107_setup_invitations.sql` (§3.4, link-only delivery)
- [ ] Branch: table, descriptor, list/form
- [ ] Department: table (tree), seed root + 13 per company, TreeView
- [ ] Designation: table, 31-row seed, list/form
- [ ] Holiday List + Holiday: tables, validations trigger, actions (weekly off, local holidays, clear), `app.is_holiday()`
- [x] Roles: list/form (custom roles), Role Profile list/form — `0105_setup_roles.sql` (§2.7), descriptors `role.ts` / `role-profile.ts`, `MultiSelect` field type
- [x] Role Permissions matrix page + Server Actions + "reset to defaults" — `0108_setup_role_permission_manager.sql` (§2.8, §8), per-doctype reset
- [x] User Permissions: list/form, picker for Company/Warehouse/Cost Center — `0109_setup_user_permissions.sql` (§2.9), descriptor `user-permission.ts`, `DynamicLink` field type; Warehouse/Cost Center join the picker with their P2 tables
- [ ] Authorization Rule: table, descriptor, list/form (enforcement `app.validate_approving_authority` wired in P5/P6 submit paths)
- [ ] Letter Head: table, storage upload, preview, default trigger
- [ ] Print Format registry table + `/print/[doctype]/[id]` route shell + generic record template; standard templates added per module
- [ ] Print Settings: table + SettingsPage
- [ ] Email Account: table, Vault secret handling, Edge Function `send-email` (Resend + SMTP), test-send action
- [ ] Email Template: table, handlebars-subset renderer (`src/lib/email/render.ts`), app-level `Invitation` + `Send Document` templates, form "Email" action
- [ ] Email Digest + Recipient: tables, `app.email_digest_payload()`, Edge Function `send-email-digest`, pg_cron daily job, "Send now" preview
- [ ] Global Defaults + System Settings pages (**done in P0**, single-doctype forms); Settings pointer list in sidebar
- [ ] Address + Contact + `contact_email` + `contact_phone` + `dynamic_link`: tables, naming, preferred/primary triggers, `app.party_addresses()`, `app.company_address()`, `formatAddress()` TS
- [ ] Fiscal Year + Fiscal Year Company: tables, validations, `app.auto_create_fiscal_year()` pg_cron daily
- [ ] Terms and Conditions: table, validation, renderer
- [ ] Home page: onboarding checklist (`onboarding_progress`), number-card + P&L chart placeholders wired to `app.home_number_cards()` / `app.report_profit_and_loss()` as modules land
- [ ] `doctype_meta` rows + `role_permissions` upserts for every table above; `supabase gen types`; descriptors in `src/doctypes/setup/*.ts`
- [ ] RLS pgTAP for every Setup table (cross-org isolation, owner cannot be demoted)
