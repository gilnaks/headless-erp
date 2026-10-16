# 02 — Selling module

Port of ERPNext v16 (`develop`) **default** selling: customers and the sales tree (customer group, territory, sales person), the quotation → sales order → delivery note chain, product bundles, Selling Settings, the selling dashboard and the reports on the Selling sidebar.

Read with: `docs/PLAN.md` (§5 settings baseline, §7 phases P2/P5), `docs/architecture/03-posting-engine.md` (status updater, DN stock/GL row), `docs/modules/00-setup.md` (fixtures A7, A8, A10, A20; Address and Contact), `docs/modules/01-accounts.md` (Sales Invoice, taxes-and-totals §3.11, party account, due date, credit limit §3.5, payment schedule §3.9, returns §3.4). Stock ledger detail for the Delivery Note is `docs/modules/04-stock.md` (not written yet); this doc states the selling-side rules the stock engine must honour.

This doc **does not repeat** the invoice GL/PLE recipes, the taxes pipeline, or the provisioning seed lists. It **owns** the selling documents those recipes read (`per_billed`, `per_delivered`, `so_detail`, `dn_detail`, customer credit limits, `so_required` / `dn_required`).

One doctype, one route. Sidebar items in other modules are aliases:

| Doctype | Canonical route | Also linked from |
|---|---|---|
| Customer, Customer Group, Territory, Sales Person, Quotation, Sales Order, Selling Settings, Product Bundle | `/[org]/selling/…` | — |
| Sales Invoice | `/[org]/accounts/sales-invoice` | Selling sidebar (nav currently says `selling/sales-invoice`; P5 points it here) |
| Delivery Note | `/[org]/stock/delivery-note` | Selling sidebar (nav currently says `selling/delivery-note`; P5 points it here) |
| Item, Price List | `/[org]/stock/item`, `/[org]/stock/price-list` | Selling and Buying sidebars |

ERPNext sources read (repo-relative to `C:\Users\John\Desktop\erpnext`):

- Masters: `erpnext/selling/doctype/customer/customer.{json,py}`, `customer_credit_limit/`, `erpnext/setup/doctype/customer_group/`, `territory/`, `sales_person/`, `erpnext/selling/doctype/sales_team/`, `industry_type/`, `product_bundle/product_bundle.py`, `erpnext/setup/doctype/quotation_lost_reason/`.
- Transactions: `quotation/quotation.py`, `quotation/mapper.py`, `sales_order/sales_order.py`, `sales_order/services/status.py`, `sales_order/mapper.py`, `erpnext/stock/doctype/delivery_note/delivery_note.py`, `delivery_note/mapper.py`, `delivery_note/services/billing_status.py`.
- Shared: `erpnext/controllers/selling_controller.py`, `erpnext/controllers/status_updater.py` (`status_map`), `erpnext/stock/doctype/packed_item/`, `erpnext/stock/get_item_details.py`, `erpnext/setup/setup_wizard/operations/install_fixtures.py` (`update_selling_defaults`).
- Reports and dashboard: `erpnext/selling/selling_dashboard/selling/selling.json`, `erpnext/selling/number_card/*`, `erpnext/selling/dashboard_chart/*`, `erpnext/selling/report/sales_analytics/sales_analytics.py`, `erpnext/accounts/report/sales_register/sales_register.py`, `erpnext/accounts/report/gross_profit/gross_profit.py`.
- Tests used for status examples: `sales_order/test_sales_order.py`, `quotation/test_quotation.py`, `stock/doctype/delivery_note/test_delivery_note.py`.

---

## 1. Scope & sidebar mapping

Module id `selling`, label **Selling**. Each row is one descriptor unless marked alias, page or report. `src/config/navigation.ts` already lists this sidebar and already omits Pricing Rule and POS.

| Sidebar group › item | Route / target | Kind | Phase |
|---|---|---|---|
| Home | `/[org]/selling` | workspace | P5 |
| Dashboard | `/[org]/selling/dashboard` | DashboardView (§7.1) | P5 |
| Customer | `selling/customer` | doctype | P2 |
| Quotation | `selling/quotation` | submittable | P5 |
| Sales Order | `selling/sales-order` | submittable | P5 |
| Delivery Note | `stock/delivery-note` | submittable (alias) | P5 |
| Sales Invoice | `accounts/sales-invoice` | alias of 01-accounts | P5 |
| Reports › Sales Analytics, Sales Register, Gross Profit | `selling/report/<slug>` | ReportView | P5 |
| Reports › Accounts Receivable, Accounts Receivable Summary | `accounts/report/<slug>` | alias of 01-accounts | P7 |
| Items › Item, Price List | `stock/item`, `stock/price-list` | aliases (04-stock / P2) | P2 |
| Items › Pricing Rule | — | not built (§9) | — |
| POS › POS, POS Profile, POS Invoice | — | not built (§9) | — |
| Setup › Customer Group, Territory, Sales Person | `selling/<slug>` | tree doctypes | P2 |
| Setup › Settings | `selling/settings` | single | P5 (row seeded in A4/A20) |
| *(not in nav)* Industry Type | `selling/industry-type` | doctype (Customer link) | P2 |
| *(not in nav)* Product Bundle | `selling/product-bundle` | submittable | P2 |
| *(not in nav)* Quotation Lost Reason | `selling/quotation-lost-reason` | doctype | P5 |

Out of scope (PLAN / `.cursorrules`): CRM (Lead, Opportunity, Prospect, Campaign, Competitors), Pricing Rule, Coupon Code, Loyalty, POS, Blanket Order, Installation Note, Delivery Trip, Sales Partner and commission reports, UTM, Shopping Cart, inter-company orders, subcontracted sales orders, stock reservation entries (Stock Settings `enable_stock_reservation` defaults to 0; the columns stay, the entry doctype is not built). Pick List is specified in 04-stock, not here.

---

## 2. Doctype inventory

Conventions match 01-accounts §2: `id`, `org_id`, `name` unique per org, audit columns, RLS, money/qty `numeric(21,9)`, trees via `parent_id` + `is_group` + `path ltree`. Submittables add `naming_series`, `docstatus`, `amended_from`. Children add `parent_id`, `idx`. Perms are ERPNext JSON `permlevel 0` after the role fold in §9 item 4.

### 2.1 Customer → `customer`

- **Kind:** master. **Naming** (`customer.py: autoname`, driven by `selling_settings.cust_master_name`, wizard value `Customer Name`):
  - `Customer Name` (default): `name = trim(customer_name)`. If that name exists, the next free `"<customer_name> - <n>"` is used (the highest trailing integer among `"<name> - %"` plus one; a non-numeric suffix counts as 0) and the form shows "Changed customer name to '{0}' as '{1}' already exists."
  - `Naming Series`: `CUST-.YYYY.-` via `app.next_name`.
  - `Auto Name`: ERPNext calls `set_name_from_naming_options` with the doctype autoname `naming_series:`, so this option also uses `CUST-.YYYY.-`. The wizard never selects it.
- **Perms:** Sales User rwc, Sales Manager rwcd (JSON gives delete to Sales Master Manager only — folded, §9 item 4), Stock User r, Stock Manager r, Accounts User r, Accounts Manager r.
- **Migration:** `02nn_selling_customer.sql`.

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| customer_name | text | ✔ | | stripped on save |
| customer_type | text check `Company\|Individual\|Partnership` | ✔ | `Company` | |
| customer_group | customer_group_id | | | must be a leaf ("Cannot select a Group type Customer Group…") |
| territory | territory_id | | | |
| tax_id | text | | | |
| tax_category | tax_category_id | | | feeds Tax Rule (01-accounts) |
| default_currency | text | | | document-currency hint; party account stays company currency (01-accounts §9 item 1) |
| default_price_list | price_list_id | | | must be a selling list |
| language | text | | | |
| website | text | | | |
| customer_primary_contact | contact_id | | | display fetched |
| customer_primary_address | address_id | | | |
| payment_terms | payment_terms_template_id | | | copied from the group by "Get Customer Group Details" |
| customer_details | text | | | |
| industry | industry_type_id | | | |
| disabled | boolean | | false | "Customer {0} is disabled" blocks selling docs |
| is_frozen | boolean | | false | "Customer {0} is frozen" |
| on_hold | boolean | | false | clears `release_date` when off |
| release_date | date | | | on hold until this date |
| so_required | boolean | | false | label **Allow sales invoice creation without sales order** (§3.8) |
| dn_required | boolean | | false | label **Allow sales invoice creation without delivery note** |
| alias | text | | | unique per org |
| default_bank_account | bank_account_id | | | P7; must be a company bank account ("{0} is not a company bank account") |
| accounts | `party_account` | | | 01-accounts; company receivable override |
| credit_limits | `customer_credit_limit` | | | §2.2 |
| sales_team | `sales_team` | | | §2.6; percentages must total 100 |

- **Validations (`customer.py: validate`):** leaf customer group; `validate_party_accounts` (01-accounts); one credit-limit row per company ("Credit limit is already defined for the Company {0}"); default price list is selling; default bank account is a company account; sales-team total. Internal customer, lead/prospect conversion, loyalty and portal users are not ported.
- **Action:** `app.get_customer_group_details(customer_id)` copies the group's `accounts`, `credit_limits`, `payment_terms` and `default_price_list` onto the customer and saves.
- **Delete:** blocked while submitted quotations, orders, delivery notes or invoices point at it (Frappe link check).
- **Connections:** Quotation, Sales Order, Delivery Note, Sales Invoice, Payment Entry, addresses and contacts (00-setup).

### 2.2 Customer Credit Limit → `customer_credit_limit`

Child of Customer and of Customer Group. One row per company on a parent ("Credit limit is already defined for the Company {0}").

| fieldname | column | default | notes |
|---|---|---|---|
| company | company_id | | ✔ when a row exists |
| credit_limit | numeric | | 0 = no limit from this row; resolution order is 01-accounts §3.5 |
| bypass_credit_limit_check | boolean | false | this company skips the check, including the open-order portion |

`overdue_billing_threshold` stays hidden and unused (`accounts_settings.enable_overdue_billing_threshold` is off).

### 2.3 Customer Group → `customer_group`

- **Kind:** tree, org-level. **Naming:** `field:customer_group_name` (unique). **Perms:** Sales Manager rwcd; Sales User and Accounts User read. System Manager also reads (the JSON omits that role). Sales Manager holds the rwcd that the JSON gives Sales Master Manager, which is not seeded (§9).
- **Migration:** `0203_selling_customer_group.sql`. Parent of a new non-root defaults to the root (`get_root_of`).
- Fields in this migration: `customer_group_name` ✔, `parent_id`, `is_group` default false, `path`. `default_price_list`, `payment_terms`, `accounts` and `credit_limits` wait for Price List, Payment Terms, and Account.
- A group that still has children cannot become a leaf. A leaf that is selected on a customer cannot become a group; that check lands with Customer.
- **Seed (00-setup A8):** `All Customer Groups` (group) → `Individual`, `Commercial`, `Non Profit`, `Government`. `selling_settings.customer_group` is left null (ERPNext default); the customer form does not force a group.

### 2.4 Territory → `territory`

- **Kind:** tree, org-level. **Naming:** `field:territory_name`. **Perms:** Sales Manager rwcd, Sales User r, Stock User r, Accounts User r.
- Fields: `territory_name` ✔, `parent_id`, `is_group` default false, `territory_manager` → sales person, `path`.
- **Seed (00-setup A7):** `All Territories` (group) → the company country (apostrophes removed), `Rest Of The World`.
- Target Detail rows and the territory target-variance reports are not built (§9).

### 2.5 Sales Person → `sales_person`

- **Kind:** tree, org-level. **Naming:** `field:sales_person_name`. **Perms:** Sales Manager rwcd, Sales User r.
- Fields: `sales_person_name` ✔, `parent_id`, `is_group` ✔ default false, `enabled` default true, `commission_rate` percent. `employee` is not built (HR).
- A disabled sales person cannot be added to a sales team ("Sales Person {0} is disabled.").
- **Seed (00-setup A10):** `Sales Team` (group) only.
- Target rows are not built (§9).

### 2.6 Sales Team → `sales_team`

Child of Customer, Sales Order and Delivery Note.

| fieldname | column | req | notes |
|---|---|---|---|
| sales_person | sales_person_id | ✔ | enabled leaf or group, as ERPNext allows |
| allocated_percentage | numeric | | rows present → sum must equal 100 ("Total allocated percentage for sales team should be 100" on transactions; "Total contribution percentage should be equal to 100" on the customer) |
| allocated_amount | numeric | | read-only; `amount_eligible_for_commission × allocated_percentage / 100` |
| commission_rate | numeric | | fetched from the sales person |
| incentives | numeric | | `allocated_amount × commission_rate / 100` |

`amount_eligible_for_commission` on the transaction is the sum of `base_net_amount` of rows whose item has `grant_commission`. Sales Partner is not built, so the header `commission_rate` / `total_commission` fields are omitted (§9).

### 2.7 Industry Type → `industry_type`

- **Naming:** `field:industry`. **Perms:** Sales Manager rwc, Sales User r. Field: `industry` text ✔ unique.
- Not seeded (00-setup skipped fixtures). Users add rows from the Customer form.

### 2.8 Quotation Lost Reason → `quotation_lost_reason`

- **Naming:** `field:order_lost_reason`. **Perms:** Sales Manager rwcd, Sales User r. Field: `order_lost_reason` text ✔ unique.
- Used only by Quotation "Set as Lost" (§3.4). No seed; the action refuses an unknown reason ("Invalid lost reason {0}, please create a new lost reason").

### 2.9 Product Bundle → `product_bundle`

- **Kind:** submittable, not company-scoped. **Naming:** `PB-<item>-001`, next index among non-amended names for that parent item (`product_bundle.py: autoname`). **Perms:** Stock Manager rwcsxd, Sales User rwcsxd, Stock User r.
- **Migration:** `02nn_selling_product_bundle.sql`.
- Fields: `new_item_code` → item ✔, `description`, `is_active` default true, `disabled` default false, `amended_from`. Child `product_bundle_item`: `item_code` ✔, `qty` ✔ (non-zero), `uom` fetched from the item's stock UOM, `description`.
- Submit marks this version active and clears `is_active` on every other submitted bundle of the same parent item. Cancel sets `is_active = 0`. Only `is_active` and `disabled` are editable after submit. Delete is blocked when a submitted stock or selling document uses the parent item.
- `app.make_packing_list(doc)` (called on save of Quotation, Sales Order, Delivery Note, Sales Invoice) rebuilds `packed_item` from the active, non-disabled bundle of each item: one packed row per bundle component, `qty = bundle qty × parent qty`, warehouse copied from the parent row. A bundle item is not itself delivered; its packed rows are. Non-stock parents with a bundle that contains a stock item still require a warehouse and a delivery (§3.6).

### 2.10 Quotation → `quotation` + `quotation_item`

- **Kind:** submittable, company-scoped. **Naming:** `SAL-QTN-.YYYY.-`. A revision is named `<original>-R<n>` (§3.4), not the series. **Title:** `customer_name`. **Perms:** Sales User rwcsxd, Sales Manager rwcsxd.
- **Migration:** `05nn_selling_quotation.sql`.

Header fields we keep (shared money columns are the selling subset of 01-accounts §3.11: `total_qty`, `total`, `net_total`, `base_*`, `taxes`, `apply_discount_on` default `Grand Total`, `additional_discount_percentage`, `discount_amount`, `grand_total`, `rounding_adjustment`, `rounded_total`, `in_words`, `disable_rounded_total`, `payment_terms_template`, `payment_schedule`, `tc_name`, `terms`, `letter_head`, `group_same_items`):

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| naming_series | text | ✔ | `SAL-QTN-.YYYY.-` | |
| quotation_to | text | ✔ | `Customer` | only `Customer` is accepted (§9) |
| party_name | customer_id | ✔ | | |
| customer_name | text | | | from the customer |
| company | company_id | ✔ | | |
| transaction_date | date | ✔ | today | |
| valid_till | date | | | cannot be before `transaction_date` |
| is_active | boolean | | true | revisions deactivate the others (§3.4) |
| is_latest_revision | boolean | | false | maintained on submit |
| revision_of | quotation_id | | | |
| order_type | text check `Sales\|Maintenance\|Shopping Cart` | ✔ | `Sales` | only `Sales` is offered (§9) |
| customer_address, shipping_address_name, contact_person | uuid | | | displays rendered on save |
| company_address | address_id | | | |
| territory | territory_id | | | |
| currency | text | ✔ | | company currency, or the customer's `default_currency` with `conversion_rate` |
| conversion_rate | numeric | ✔ | 1 | forced to 1 when currencies match |
| selling_price_list | price_list_id | ✔ | | §3.9 |
| price_list_currency, plc_conversion_rate | | ✔ | | `plc_conversion_rate = 1` (price list currency = document currency) |
| items | `quotation_item` | ✔ | | |
| packed_items | `packed_item` | | | rebuilt, not typed |
| taxes_and_charges | template id | | | |
| status | text | ✔ | `Draft` | §5.1 |
| order_lost_reason | text | | | free text from Set as Lost |
| lost_reasons | `quotation_lost_reason_detail` | | | child: `quotation_lost_reason_id` |

`quotation_item` columns we keep: `item_code`, `item_name` ✔, `description`, `qty` ✔, `uom` ✔, `stock_uom`, `conversion_factor` ✔, `stock_qty`, `price_list_rate`, `margin_type` (`Percentage|Amount`), `margin_rate_or_amount`, `rate_with_margin`, `discount_percentage`, `discount_amount`, `rate`, `net_rate`, `amount`, `net_amount`, `base_*`, `warehouse`, `item_tax_template`, `item_tax_rate`, `is_free_item`, `is_alternative` default false, `has_alternative_item`, `weight_per_unit`, `total_weight`, `weight_uom`, `additional_notes`, `ordered_qty` (maintained from sales orders), `page_break`. Pricing-rule, blanket-order, coupon and UTM columns are omitted.

- **Validate:** selling-controller checks (§3.7); integer UOM (`must_be_whole_number`); `valid_till`; revision rules (§3.4); packing list; `set_status`.
- **Submit:** Authorization Rule (00-setup §2.10) on `base_grand_total`; deactivate other versions of the same quotation; recompute `is_latest_revision`.
- **Cancel:** status → Cancelled; recompute which version is latest. A quotation with a submitted sales order cannot be cancelled (link check).

### 2.11 Sales Order → `sales_order` + `sales_order_item`

- **Kind:** submittable, company-scoped. **Naming:** `SAL-ORD-.YYYY.-`. **Title:** `customer_name`. **Perms:** Sales User rwcsxd, Sales Manager rwcsxd, Accounts User r, Stock User r.
- **Migration:** `05nn_selling_sales_order.sql`.

Header adds, on top of the quotation money/address set: `customer` ✔ (not a dynamic link), `delivery_date`, `po_no`, `po_date`, `tax_id` fetched, `set_warehouse`, `project`, `cost_center`, `advance_paid` read-only, `per_delivered`, `per_billed`, `per_picked` (stored, stays 0 until Pick List in 04-stock §2.13), `delivery_status` (`Not Delivered|Fully Delivered|Partly Delivered|Closed|Not Applicable`), `billing_status` (`Not Billed|Fully Billed|Partly Billed|Closed`), `advance_payment_status` (`Not Requested|Requested|Partially Paid|Fully Paid`), `skip_delivery_note`, `reserve_stock` default false (no reservation entries, §9), `status` §5.2. Sales-partner, loyalty, UTM, inter-company and subcontracting columns are omitted.

`sales_order_item` adds, on top of the quotation item: `delivery_date`, `prevdoc_docname` → quotation, `quotation_item`, `billed_amt`, `delivered_qty`, `returned_qty`, `picked_qty` (unused), `work_order_qty` (P8 writes it), `closed`, `grant_commission` fetched from the item, `delivered_by_supplier` default false, `supplier` (drop ship, P6), `skip_delivery`, `warehouse`, `cost_center` default company cost center, `project`, `bom_no` (P8), `is_stock_item` fetched.

- **Validate (`sales_order.py: validate`):** §3.7; `set_skip_delivery` (§3.6); delivery date (§3.6); customer's PO number (§3.6); warehouse for stock items; drop-ship supplier when `delivered_by_supplier`; previous-doc match against the quotation; packing list; credit-limit pre-check; `set_status`.
- **Submit:** quotation `ordered_qty` + quotation status; credit limit (01-accounts §3.5); Authorization Rule; project `total_sales_amount` when `sales_update_frequency = Each Transaction`.
- **Cancel:** refused while status is Closed ("Closed order cannot be cancelled. Unclose to cancel."); refused while a draft sales invoice points at it ("Sales Invoice {0} must be deleted before cancelling this Sales Order"); reverses quotation qty; unlinks advances when `unlink_advance_payment_on_cancelation_of_order = 1` (01-accounts §3.8).
- **After submit, allowed writes:** `po_no`, `po_date`, per-row `delivery_date`, `supplier` (only while no purchase order exists for the row), sales team. Close / Hold: §5.2.

### 2.12 Delivery Note → `delivery_note` + `delivery_note_item`

- **Kind:** submittable, company-scoped. Owned here for the selling document; SLE and perpetual GL are 04-stock, summarised in §4. **Naming:** `MAT-DN-.YYYY.-`; returns use `MAT-DN-RET-.YYYY.-`. **Title:** `customer_name`. **Perms:** Stock User rwcsxd, Stock Manager rwcsxd, Sales User rwcsxd, Accounts User r (Delivery User/Manager folded into Stock User, §9 item 4).
- **Migration:** `05nn_stock_delivery_note.sql`.

Header adds: `posting_date` ✔ default today, `posting_time` ✔ default now, `set_posting_time`, `is_return`, `return_against`, `issue_credit_note` (offers "make credit note" after a return; the credit note itself is 01-accounts §3.4), `per_billed`, `per_returned`, `per_installed` (always 0), `print_without_amount`, `transporter` → supplier, `lr_no`, `lr_date` default today, `vehicle_no`, `instructions`, `set_target_warehouse`, `status` §5.3. Driver, delivery trip, installation and UTM columns are omitted.

`delivery_note_item` adds: `against_sales_order`, `so_detail`, `against_sales_invoice`, `si_detail`, `dn_detail` (return link), `billed_amt`, `returned_qty`, `received_qty`, `incoming_rate`, `expense_account`, `cost_center`, `warehouse` ✔ for stock items, `target_warehouse`, `serial_and_batch_bundle` / `serial_no` / `batch_no` / `use_serial_batch_fields` (04-stock), `allow_zero_valuation_rate`, `closed`, `packed_qty`.

- **Validate:** posting time vs fiscal year; §3.7; `so_required` (§3.8); source SO not On Hold or Closed ("Sales Order {0} is on hold" / "closed"); warehouse; expense account is a ledger of the company (default `companies.default_expense_account_id`); previous-doc match (customer, currency, item, UOM, conversion factor); packing list; returned-qty limits on a return (01-accounts §3.4 shape).
- **Submit:** SLE + GL (§4); SO `delivered_qty` / `per_delivered` / status; SI `delivered_qty` when the row cites `si_detail`; return updates source `returned_qty` / `per_returned`.
- **Cancel:** reverses SLE and GL; rolls the percentages back. A submitted sales invoice that cites the DN blocks cancel (link check). Closed notes must be reopened first.

### 2.13 Packed Item → `packed_item`

Child of Quotation, Sales Order, Delivery Note and Sales Invoice. Rebuilt by `app.make_packing_list`; users edit only `warehouse` (and, on a delivery note, serial/batch). Columns: `parent_item`, `item_code`, `product_bundle_id`, `item_name`, `description`, `qty`, `uom`, `warehouse`, `rate`, `serial_and_batch_bundle`, `batch_no`, `serial_no`. The delivery note posts stock for packed rows, not for the parent bundle item.

### 2.14 Selling Settings → `selling_settings`

Single, one row per org. Seeded in 00-setup A4 from the JSON defaults, then A20 applies the wizard overrides below. **Perms:** System Manager rwc, Sales Manager rwc. The form is P5; the row exists from P1.

| field | JSON default | After A20 | Effect |
|---|---|---|---|
| cust_master_name | `Customer Name` | `Customer Name` | §2.1 naming. Changing it does not rename existing customers |
| customer_group | null | null | not auto-filled on new customers |
| territory | null | null | |
| selling_price_list | null | null | not set by the wizard; the user picks `Standard Selling` (§3.9) |
| so_required | null | `No` | §3.8 |
| dn_required | null | `No` | §3.8 |
| skip_delivery_note_for_service_items | 0 | 0 | §3.6 |
| sales_update_frequency | `Daily` | `Each Transaction` | SO submit refreshes `project.total_sales_amount` |
| maintain_same_sales_rate | 0 | 0 | when 1, SO rate must equal the quotation rate |
| maintain_same_rate_action | `Stop` | `Stop` | `Stop` throws, `Warn` alerts; `role_to_override_stop_action` may bypass Stop |
| allow_multiple_items | 0 | **1** | duplicate item rows are allowed (§3.7) |
| allow_against_multiple_purchase_orders | 0 | 0 | §3.6 |
| validate_selling_price | 0 | 0 | §3.7 |
| editable_price_list_rate | 0 | 0 | `price_list_rate` stays read-only |
| allow_sales_order_creation_for_expired_quotation | 0 | 0 | §3.2 |
| allow_zero_qty_in_quotation / `_sales_order` | 0 | 0 | §3.7 |
| enable_discount_accounting | 0 | 0 | discounts reduce net total; they do not post a separate discount account (01-accounts §9 item 8) |
| hide_tax_id | 0 | 0 | |
| dont_reserve_sales_order_qty_on_sales_return | 0 | 0 | inert (reservation is out) |
| blanket_order_allowance | null | null | inert |
| allow_delivery_of_overproduced_qty | 0 | 0 | P8 |
| fallback_to_default_price_list | 0 | 0 | when 1 and the customer's list has no price, try `selling_price_list` |
| editable_bundle_item_rates | 0 | 0 | packed-item rates stay read-only |
| enable_tracking_sales_commissions | 0 | 0 | sales-partner commission; partner is out, flag stays 0 |
| enable_cutoff_date_on_bulk_delivery_note_creation | 0 | 0 | bulk DN tool is not built |
| set_zero_rate_for_expired_batch | 0 | 0 | 04-stock reads it |
| enable_proforma_invoice, enable_utm, deliver_secondary_items | 0 | 0 | not built (§9) |

---

## 3. Document flows & mappers

Mappers are `app.map_doc(source_doctype, source_id, target_doctype)` returning an unsaved draft. The form then runs `app.get_item_details` per row and the taxes pipeline (01-accounts §3.11). Save is `app.save_doc`, submit is `app.submit_doc`.

```
Quotation ─┬─► Sales Order ─┬─► Delivery Note ─► Sales Invoice
           │                 ├─► Sales Invoice
           └─► Sales Invoice └─► Payment Entry (advance)
Delivery Note (return) ─► Sales Invoice (credit note, when issue_credit_note)
```

### 3.1 Shared party defaults

New Quotation, Sales Order, Delivery Note and Sales Invoice call the same party fill as 01-accounts §3.1 (`party.get_party_details`): billing and shipping address, contact, `selling_price_list` (§3.9), `taxes_and_charges` from Tax Rule → tax category → company default template, `payment_terms_template` from customer → customer group → company, `tc_name` from `companies.default_selling_terms`, letter head, sales team copied from the customer when the document's team is empty. Currency is the customer's `default_currency` or the company currency. `conversion_rate` is 1 when they match, otherwise the rate the user types (no exchange-rate doctype fetch beyond Currency Exchange, P2).

### 3.2 Quotation → Sales Order (`quotation/mapper.py: make_sales_order`)

Refused when `valid_till` is before `transaction_date` or before today, unless `allow_sales_order_creation_for_expired_quotation` ("Validity period of this quotation has ended."). Source must be submitted and `is_active`.

Copied: company, currency, price list, addresses, taxes (amounts reset, then the pipeline reruns), sales team, items with `prevdoc_docname = quotation`, `quotation_item = row`. Item qty is the remaining stock qty (`stock_qty − ordered_qty`, converted back by `conversion_factor`); rows with nothing left are skipped. Alternative rows (`is_alternative`) are skipped unless the user selected them. Payment terms are copied only when `accounts_settings.automatically_fetch_payment_terms` (default 0).

### 3.3 Quotation → Sales Invoice

Same header copy. Items: every non-alternative row at its full qty (ordered qty is not subtracted). Cost center on each item is cleared so the invoice default applies. Source must be submitted and active.

### 3.4 Quotation revisions and Set as Lost

- **Revise** (`make_revision`): source submitted, status not Lost or Ordered ("Cannot revise a Quotation with status {0}."). The draft's `revision_of` is the original (the root, not the intermediate version). On submit, other versions with `is_active` become inactive, and exactly one version is `is_latest_revision` (latest `transaction_date`, then creation). A revision must keep the same company and customer ("A revision must have the same company…" / "…the same Customer…"). `transaction_date` must be after every newer version.
- **Set as Lost** (`declare_enquiry_lost`): refused when this version or another version is Partially Ordered or Ordered ("Cannot set as Lost as Sales Order is made."). Sets `status = Lost`, `is_active = 1`, stores the reason text and lost-reason rows, and sets every other non-ordered version to Lost and inactive.
- **Expire** (`app.expire_quotations`, daily, 03-posting-engine): submitted quotations with `valid_till < today`, status not Lost, and no submitted sales order, are set to `Expired` by a direct update. `set_status` does not know `Expired` (§5.1), so a later status refresh (for example cancelling the only sales order) moves the quotation back to Open.

### 3.5 Sales Order → Delivery Note (`sales_order/mapper.py: make_delivery_note`)

Source submitted. Each row is copied while `delivered_qty < qty`, the row is not `closed`, not `delivered_by_supplier`, and not `skip_delivery`. Qty on the note is the remainder. `so_detail` and `against_sales_order` are set. Rate is the order rate (pricing rules are not re-applied). Taxes are copied and recalculated. Company address is copied or filled from the company default.

Drop ship (`delivered_by_supplier` + `supplier`) does not create a delivery note row. The purchase order that receives those goods is P6 (`make_purchase_order`); until then the row simply never delivers, and the order stays short of `per_delivered = 100` unless every such row is closed.

### 3.6 Sales Order delivery rules

- **Delivery date:** for `order_type = Sales`, when any row needs delivery, `delivery_date` is required ("Please enter Delivery Date") and is kept equal to the latest item `delivery_date`. An item date before `transaction_date` throws "Expected Delivery Date should be after Sales Order Date". An item date before `po_date` throws "Row #{0}: Expected Delivery Date cannot be before Purchase Order Date".
- **Customer PO:** the same `po_no` on another non-cancelled order of the same customer throws "Sales Order {0} already exists against Customer's Purchase Order {1}…", unless `allow_against_multiple_purchase_orders`, which warns instead.
- **Warehouse:** a stock item, or a product bundle that contains a stock item, needs `warehouse` unless `delivered_by_supplier` ("Source warehouse required for stock item {0}"). `set_warehouse` fills empty row warehouses.
- **Skip delivery:** when `skip_delivery_note_for_service_items = 1`, a row that is not a stock item, not a fixed asset, and not a bundle containing a stock item gets `skip_delivery = 1`. If every row skips, the header `skip_delivery_note` is set, `per_delivered = 100`, `delivery_status = Not Applicable`, and no delivery note is required. Default 0, so service items are delivered (a delivery note with no stock movement).
- **Previous document:** quotation company must match; item code, UOM and conversion factor must match the quotation row. With `maintain_same_sales_rate`, the rate must match too (`Stop` or `Warn`).
- **Project:** "Customer {0} does not belong to project {1}" when the project has a different customer.

### 3.7 Selling controller checks (Quotation, Sales Order, Delivery Note, Sales Invoice)

From `selling_controller.py: validate`, in order, skipping returns where noted:

1. Customer not disabled and not frozen.
2. Item exists, is a sales item, and is not disabled.
3. UOM is allowed on the item and, when `must_be_whole_number`, qty is a whole number.
4. `max_discount`: "Maximum discount for Item {0} is {1}%" (not on returns).
5. `validate_selling_price` (only when the setting is on, not on returns): `base_net_rate` must be at least the item's last purchase rate in the sales UOM, and for stock items at least `valuation_rate` (orders and quotations) or `incoming_rate` (notes and invoices). "Row #{0}: Selling rate for item {1} is lower than its {2}…".
6. `stock_qty = qty × conversion_factor` ("Row {0}: Conversion Factor is mandatory").
7. Duplicate rows. With `allow_multiple_items = 1` (our default) this check is skipped. When it is 0, the same item + description + warehouse (plus batch and source document on notes and invoices) throws "Item {0} entered multiple times."
8. Price list country matches the billing address country when the price list has a country.
9. Gross profit on each row: `valuation_rate` from the bin (orders, quotations) or `incoming_rate` (notes), `gross_profit = (base_rate − valuation_rate) × stock_qty`. Display only.

Zero qty is rejected unless `allow_zero_qty_in_quotation` / `allow_zero_qty_in_sales_order` and the row is then a unit-price row (`has_unit_price_items`). Both settings default off, so qty must be non-zero.

### 3.8 When an order or a note is required

- **Delivery Note:** if `so_required = Yes`, every item row needs `against_sales_order` ("Sales Order required for Item {0}"). The customer bypass does not apply on the note.
- **Sales Invoice** (01-accounts, restated because the flags live here): returns skip the check. If `so_required = Yes` and the customer does **not** have "Allow sales invoice creation without sales order", every item needs a sales order ("Sales Order is mandatory for Item {1}"), unless the invoice is POS (not built). `dn_required` is the same for the delivery note, and `update_stock` on the invoice stands in for the note. Service items with `skip_delivery` do not need a note.

### 3.9 Price list and item rate

`app.get_item_details(...)` is specified with the stock module. The selling inputs are customer, company, price list, currency, qty, UOM, transaction/posting date and warehouse. The price list (`party.py: set_price_list`) is the customer's `default_price_list` when that list is enabled, else the customer group's, else the list already on the document, else `selling_settings.selling_price_list`. Nothing fills that settings field, so a new customer with no default leaves the field empty and the user selects `Standard Selling` (the P2 list). The rate is the Item Price for that list, UOM and date, at the qty break that applies. When `fallback_to_default_price_list` is on and the chosen list has no price, the settings list is tried once more. Item Price itself is a P2 stock master.

### 3.10 Sales Order → Sales Invoice, and returns

Quantity and amount rules for `make_sales_invoice` are 01-accounts §3.1 (`qty = qty − billed`, amount-based when the rate has changed). This doc adds the selling guards that function relies on: the order is submitted, not Closed or On Hold, the row is not `closed`, and `billed_amt` is the sum of submitted invoice amounts against `so_detail`. A delivery note's `make_sales_invoice` is the same section (`qty = qty − billed − returned`, `update_stock` forced off).

A delivery-note return is `app.make_return_doc('Delivery Note', id)` (01-accounts §3.4): `is_return`, `return_against`, naming series `MAT-DN-RET-.YYYY.-`, quantities negated for the not-yet-returned remainder, `dn_detail` kept. It posts a reversing SLE. `issue_credit_note` then offers the sales-invoice credit note against that return.

### 3.11 Close, hold, and row close

- **Sales Order → Close** (`update_status('Closed')`): submitted only. Undelivered remainder is no longer mapped. Status stays Closed until **Re-open**, which re-runs the credit-limit check and `set_status`.
- **Hold / Resume:** `On Hold` blocks new delivery notes and invoices ("Sales Order {0} is on hold"). Resume recalculates status.
- **Close a row:** `closed` on a sales-order or delivery-note item. A closed order row cannot be delivered, billed or, when reservation exists, closed while reserved ("Row #{0}: {1} has reserved stock…" — inert while reservation is out). Closing the last open row does not by itself set the header to Closed; the header action does.
- **Delivery Note → Close:** submitted only ("Only a submitted Delivery Note can be closed or reopened"). A closed note is not billed further.

---

## 4. Posting rules

Quotation and Sales Order post no ledger rows. `advance_paid` on the order is the sum of payment-ledger rows whose `advance_voucher` is the order (01-accounts §4.0 `refresh_outstanding`). It is what a Payment Entry offers against the order. `advance_payment_status` is a separate field: ERPNext sets it from Payment Request (`accounts/services/advances.py: set_advance_payment_status`), which is out of scope, so the field stays `Not Requested` and a sales order never becomes `To Pay` (§5.2).

Delivery Note submit calls `app.on_submit__delivery_note`, which calls the stock engine (04-stock) and then `app.update_prevdoc_status`:

- Outward SLE per stock row (and per packed row) from `warehouse`, valued at `incoming_rate`.
- Perpetual inventory GL, already in 03-posting-engine: Dr COGS (`expense_account`, default company expense account) / Cr the warehouse stock account, for `qty × valuation`. No party ledger.
- Sales order `delivered_qty` increases by the note qty (in the order UOM), `per_delivered` is recomputed over rows that are not `skip_delivery`, and the order status is refreshed (§5.2). Over-delivery beyond `stock_settings.over_delivery_receipt_allowance` (default 0) plus the item's own allowance throws.
- A return note posts the opposite SLE and GL and increases `returned_qty` on the source note and on the sales order.

Sales Invoice posting, including `update_stock`, stays in 01-accounts §4. Submitting an invoice updates `billed_amt` / `per_billed` on the order (by amount) and on the delivery note (by amount) and refreshes both statuses.

---

## 5. Statuses

`app.set_status` walks `status_map` from the bottom and keeps the first match (`status_updater.py`). A forced status (`Closed`, `On Hold`, `Lost`) is passed in by the action and then confirmed by its own row.

### 5.1 Quotation

| Status | When it wins |
|---|---|
| Cancelled | `docstatus = 2` |
| Ordered | every non-alternative row has `ordered_qty ≥ stock_qty` |
| Partially Ordered | at least one row is ordered and some qty remains |
| Lost | status is already Lost (the Set as Lost action) |
| Open | submitted, none of the above |
| Draft | not submitted |
| Expired | not in the map. The daily job writes it directly (§3.4). The list still shows it in grey when `valid_till` is in the past |

`Replied` is a selectable value ERPNext never assigns. We keep it in the check constraint and never write it.

### 5.2 Sales Order

Evaluated bottom-up, so On Hold, Closed, Cancelled and Completed beat the in-progress states. `To Pay` beats `To Deliver` / `To Bill` / `To Deliver and Bill`.

| Status | Condition |
|---|---|
| On Hold | status already On Hold |
| Closed | status already Closed, not cancelled |
| Cancelled | `docstatus = 2` |
| Completed | (`per_delivered ≥ 100` or `skip_delivery_note`) and `per_billed ≥ 100`, submitted |
| To Pay | `advance_payment_status = Requested`, submitted |
| To Deliver | `per_delivered < 100` and `per_billed ≥ 100` and not `skip_delivery_note` |
| To Bill | (`per_delivered ≥ 100` or `skip_delivery_note`) and `per_billed < 100` |
| To Deliver and Bill | both percentages under 100, submitted |
| Draft | otherwise |

`per_delivered` is `Σ min(|delivered_qty|, |qty|) / Σ |qty|` over rows with `skip_delivery = false` (`sales_order.py: set_delivery_progress`). `per_billed` is amount-based: `Σ billed_amt / Σ amount` (`StatusService.update_billing_percentage`). `delivery_status` and `billing_status` follow those percentages (`Not` / `Partly` / `Fully`, plus `Not Applicable` when nothing is deliverable). Closing a row stops the mapper from offering the remainder; it does not by itself change the header status.

List colours (ERPNext indicator): Draft and Cancelled red; On Hold, To Deliver and Bill, To Bill, To Deliver orange; Completed green; Closed blue.

### 5.3 Delivery Note

| Status | Condition |
|---|---|
| Closed | status already Closed, not cancelled |
| Cancelled | `docstatus = 2` |
| Return | `is_return` and `per_billed = 0`, submitted |
| Return Issued | `per_returned = 100`, submitted |
| Completed | `per_billed = 100`, submitted |
| Partially Billed | `0 < per_billed < 100` (ERPNext's label is "Partially", not "Partly") |
| To Bill | submitted and `per_billed = 0` |
| Draft | otherwise |

`per_billed` is the billed amount over the note amount. `per_returned` is returned stock qty over stock qty.

---

## 6. Settings & defaults

Wizard values are 00-setup A20, copied in §2.14. Customer groups, territories and the sales-person root are A8, A7 and A10 and are inserted by the P2 migrations that create those tables (the fixtures are specified in 00-setup and currently wait on the tables).

`Standard Selling` is the price list P2 creates (PLAN §5). Selling Settings does not point at it; the user selects it on the document (§3.9). New customers do not get a group or territory until the user picks one; the trees exist so the dropdowns are not empty.

Authorization Rule (00-setup, already built) applies to Quotation and Sales Order on submit, on `base_grand_total`, the same way it applies to Sales Invoice.

---

## 7. Reports & dashboard

### 7.1 Dashboard

`selling_dashboard/selling/selling.json`. Cards are company-scoped counts and sums, not the Home workspace cards in 00-setup.

| Card | ERPNext number card | Query |
|---|---|---|
| Annual Sales | Sum of `base_net_total` | submitted sales orders modified this calendar year, status not Draft, Cancelled or Closed |
| Sales Orders to Deliver | Count | submitted, status in `To Deliver and Bill`, `To Deliver` |
| Sales Orders to Bill | Count | submitted, status in `To Deliver and Bill`, `To Bill` |
| Active Customers | Count | `disabled = false` |

Charts, all Report charts rendered with Recharts:

| Chart | Report | Default filters |
|---|---|---|
| Sales Order Trends | Sales Analytics | `period = Monthly`, `based_on = Item`, doc type Sales Order |
| Top Customers | Sales Analytics | `period = Yearly`, `based_on = Customer` |
| Sales Order Analysis | `sales_order_analysis` | status `To Bill` and `To Deliver`; one row per order (`group_by_so = 0`) |
| Item-wise Annual Sales | item-wise sales history | from the start of the fiscal year |

`Average Sales Order Value`, `Sales Orders Count` and `Total Sales Amount` exist as number cards and are not on the default dashboard. The first of those is wired to Purchase Order in ERPNext; we do not surface it.

### 7.2 Sales Analytics

`app.report_sales_analytics(filters)`. Filters: `tree_type` (`Customer|Customer Group|Item|Item Group|Territory|Sales Person`), `doc_type` (`Quotation|Sales Order|Delivery Note|Sales Invoice|Sales Invoice (due)|Payment Entry|All`), `value_quantity` (`Value|Quantity`), `from_date`, `to_date`, `company`, `range` (`Weekly|Monthly|Quarterly|Yearly`). Value is `base_net_total` (Payment Entry: received amount). Quantity is stock qty. `Sales Invoice (due)` buckets by `due_date`. `doc_type = All` stacks Quotation, Sales Order, Delivery Note, Sales Invoice, Sales Invoice (due) and Payment Entry as separate series. Tree types roll up to ancestors via `path`. Subsidiary-company aggregation is omitted (one company tree is in scope, but the report does not cross companies).

### 7.3 Sales Register

`app.report_sales_register`. Port of `accounts/report/sales_register`: submitted Sales Invoices (and their returns) in a date range, with item rows when the user expands a voucher. Columns: voucher, posting date, customer, customer name, customer group, territory, tax id, receivable account, sales order, delivery note, cost center, warehouse, currency, net total, tax total, grand total, rounded total. Filters: company ✔, from/to date ✔, customer, customer group, territory, item, warehouse. Mode of payment and owner columns are omitted (POS and user-ownership filters).

### 7.4 Gross Profit

`app.report_gross_profit`. One row per sales-invoice item (returns included as negative qty). `buying_rate` is the valuation consumed by the linked delivery note or, when the invoice updated stock, by its own SLE; invoices without stock movement use the item's `valuation_rate` at posting time. `gross_profit = base_amount − buying_amount`, percent over `base_amount`. Group by invoice (default), item, item group, brand, warehouse, customer, customer group, territory or sales person. Filters: company ✔, from/to date ✔, the group-by, and the matching link. Sales-partner and project group-bys are omitted.

### 7.5 Accounts Receivable

The Selling sidebar links to the P7 reports specified in 01-accounts. No second query.

---

## 8. UI notes

- Customer form tabs follow the JSON tab breaks we keep: Details (name, type, group, territory, currency, price list), Contact & Address (primary contact and address, plus the address/contact lists from 00-setup), Tax (tax id, tax category, party accounts), Sales Team, Credit Limit, Settings (disabled, frozen, on hold, the two "allow invoice without…" checks). Internal customer, loyalty, portal and more-info CRM fields are not shown.
- Quotation, Sales Order and Delivery Note share one transaction layout: a details header (customer, dates, order type), an items child table with the margin and discount columns visible (`enable_discounts_and_margin` treated as on, 01-accounts §9 item 8), then Taxes, Totals, Payment Terms, Terms, and a packed-items table that appears when any row has a bundle. Address blocks are billing, shipping and company.
- Create menu: Quotation → Sales Order, Sales Invoice, Revise, Set as Lost. Sales Order → Delivery Note, Sales Invoice, Payment (01-accounts §3.3), Close, Hold. Delivery Note → Sales Invoice, Return, Close. Material Request, Work Order and Purchase Order appear on the sales order when those modules exist (P4, P8, P6) and are absent before that.
- Lists: status badge from §5, customer, date, grand total (tabular numerals), and for orders the two percentages. Filters: company, customer, status, date range, and for orders `delivery_status` / `billing_status`.
- Dashboard: four cards in one row, then the four charts at the widths in §7.1 (trends and item-wise full width, the other two half).
- Settings is a single DocForm of §2.14. Fields whose feature is not built (proforma, UTM, blanket order, commission tracking, secondary items, reservation) are hidden, not deleted, so a later module can show them.
- Empty, loading and error states on every list and on the dashboard when the company has no orders.

---

## 9. Deviations from ERPNext

1. **Deviation:** `quotation_to` is only `Customer`. Lead, Prospect and CRM Deal are not quotation parties, and `make_sales_order` never creates a customer. **Reason:** CRM is out of scope.
2. **Deviation:** `order_type` offered in the form is `Sales` only. `Maintenance` and `Shopping Cart` stay in the check constraint so imported rows still load, and no maintenance schedule or visit is created. **Reason:** Support and the website cart are out of scope.
3. **Deviation:** Pricing Rule, Coupon Code, POS, Sales Partner, UTM, Blanket Order, Installation Note, Delivery Trip, Party Specific Item and the bulk delivery-note tool are not built. Their columns are omitted rather than stored unused, except `per_picked` and `reserve_stock` on the sales order, which the status and mapper code already reads. Pick List itself is a Stock doctype (04-stock §2.13, P5); until it exists `per_picked` stays 0. **Reason:** PLAN §1 out-of-scope list; stock reservation defaults off (`enable_stock_reservation = 0`).
4. **Deviation:** Sales Master Manager is not a role (00-setup §2.7). Customer, Customer Group, Territory, Sales Person and Quotation Lost Reason grant that role's rwcd to Sales Manager. Delivery User and Delivery Manager are not roles; Delivery Note keeps Stock User and Stock Manager rwcsxd, which already match them. Maintenance roles are dropped. **Reason:** the seeded role list; Sales User stays create-without-delete on Customer, as in the JSON.
5. **Not a deviation (recorded for implementers):** `cust_master_name = Auto Name` follows ERPNext and uses the doctype autoname `naming_series:` (`CUST-.YYYY.-`), the same series as `Naming Series`. The wizard sets `Customer Name`.
6. **Deviation:** Territory and Sales Person target rows, and the target-variance reports, are not built. **Reason:** they need Monthly Distribution (P7) and are not on the Selling sidebar. `territory_manager` and `commission_rate` are kept because the sales team uses them.
7. **Deviation:** drop-ship (`delivered_by_supplier`) is stored and excluded from delivery-note mapping, and it does not create a purchase order until P6. **Reason:** the purchase order is a buying document; hiding the checkbox would lose the ERPNext field.
8. **Deviation:** Product Bundle is a real doctype even though it is not on the sidebar. **Reason:** `make_packing_list` is default behaviour for every selling transaction; without it a bundled item would post as a single stock item.
9. **Deviation:** Industry Type is a master and is not seeded. **Reason:** 00-setup skipped that fixture; the customer link still needs a target.
10. **Not a deviation (recorded for implementers):** quotation status `Replied` is never written, and `Expired` is only written by the daily job, not by `set_status`. That is what `status_map` and `set_expired_status` do; a later status refresh moves an expired quotation back to Open.
11. **Deviation:** sales-partner commission fields (`sales_partner`, `commission_rate`, `total_commission`) are omitted. Sales-team allocation and incentives stay, using `grant_commission` on the item. **Reason:** Sales Partner is not on the sidebar and `enable_tracking_sales_commissions` defaults off; the team itself is on the default customer and order forms.
12. **Deviation:** Selling sidebar entries for Sales Invoice, Delivery Note, Item and Price List open the canonical route in §1 rather than a second copy of the doctype. **Reason:** one table, one form; the current `navigation.ts` paths are placeholders until P5.

---

## 10. Implementation checklist

Migration numbers follow 02-database-conventions: P2 `02nn_selling_*`, P5 `05nn_selling_*` and `05nn_stock_delivery_note.sql`. Each item is one migration (RLS, `doctype_meta`, `role_permissions`), one descriptor, a Zod schema, client mutations, list/form, and a pgTAP or Vitest test.

### P2 — masters

- [x] `customer_group` tree + A8 seed — §2.3
- [ ] `territory` tree + A7 seed — §2.4
- [ ] `sales_person` tree + A10 seed — §2.5
- [ ] `industry_type` — §2.7
- [ ] `customer` + `customer_credit_limit` + `sales_team` + `party_account` rows — §2.1, §2.2, §2.6
- [ ] `product_bundle` + `product_bundle_item` — §2.9

### P5 — transactions

- [ ] `quotation_lost_reason` — §2.8
- [ ] `quotation` + `quotation_item` + lost-reason child; revise, set-as-lost, `app.expire_quotations` — §2.10, §3.2–§3.4, §5.1
- [ ] `sales_order` + `sales_order_item`; delivery-date, PO-number, skip-delivery and credit-limit checks; close / hold — §2.11, §3.6, §5.2
- [ ] `delivery_note` + `delivery_note_item` + `packed_item`; `app.make_packing_list` — §2.12, §2.13
- [ ] `app.map_doc` for quotation → order, quotation → invoice, order → note, order → invoice, note → invoice, note return — §3
- [ ] `app.update_prevdoc_status` for ordered qty, delivered qty, billed amount and the three status maps — §4, §5
- [ ] Delivery-note SLE and perpetual GL (with 04-stock) — §4
- [ ] Selling Settings form — §2.14
- [ ] Dashboard cards and the four charts — §7.1
- [ ] Sales Analytics, Sales Register, Gross Profit — §7.2–§7.4
- [ ] Retarget the Selling nav aliases (Sales Invoice, Delivery Note, Item, Price List) — §1, §9 item 12
