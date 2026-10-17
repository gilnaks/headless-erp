# 03 — Buying module

Port of ERPNext v16 (`develop`) **default** buying: suppliers and supplier groups, the purchase chain from material request through request for quotation, supplier quotation, purchase order and purchase receipt, Buying Settings, the buying dashboard and the reports on the Buying sidebar. Supplier Scorecard is the seeded configuration only.

Read with: `docs/PLAN.md` (§5, §7 phases P2/P4/P6), `docs/architecture/03-posting-engine.md` (status updater, purchase-receipt and purchase-invoice rows), `docs/modules/00-setup.md` (fixtures A9, A21), `docs/modules/01-accounts.md` (Purchase Invoice, taxes §3.11, party account, payment schedule, returns §3.4, Stock Received But Not Billed), `docs/modules/02-selling.md` (drop-ship rows on a sales order). Stock-ledger detail for the Purchase Receipt, and material-request types other than Purchase, belong in `docs/modules/04-stock.md` (not written yet).

This doc **does not repeat** the invoice GL/PLE recipes or the taxes pipeline. It **owns** the buying documents those recipes read (`per_received`, `per_billed`, `purchase_order`, `purchase_receipt`, supplier hold, `po_required` / `pr_required`).

One doctype, one route. Sidebar items in other modules are aliases:

| Doctype | Canonical route | Also linked from |
|---|---|---|
| Supplier, Supplier Group, Request for Quotation, Supplier Quotation, Purchase Order, Buying Settings, Supplier Scorecard | `/[org]/buying/…` | — |
| Purchase Invoice | `/[org]/accounts/purchase-invoice` | Buying sidebar (nav currently says `buying/purchase-invoice`; P6 points it here) |
| Purchase Receipt | `/[org]/stock/purchase-receipt` | Buying sidebar (nav currently says `buying/purchase-receipt`; P6 points it here) |
| Material Request | `/[org]/stock/material-request` | Buying sidebar (nav currently says `buying/material-request`; P6 points it here) |
| Item, Item Group, Price List | `/[org]/stock/…` | Buying sidebar |

ERPNext sources read (repo-relative to `C:\Users\John\Desktop\erpnext`):

- Masters: `erpnext/buying/doctype/supplier/supplier.{json,py}`, `erpnext/setup/doctype/supplier_group/`, `erpnext/buying/doctype/buying_settings/buying_settings.json`, `erpnext/buying/doctype/supplier_scorecard/supplier_scorecard.py` (`make_default_records`).
- Transactions: `request_for_quotation/request_for_quotation.py`, `request_for_quotation/mapper.py`, `supplier_quotation/supplier_quotation.py`, `supplier_quotation/mapper.py`, `purchase_order/purchase_order.py`, `purchase_order/mapper.py`, `erpnext/stock/doctype/material_request/mapper.py`, `erpnext/stock/doctype/purchase_receipt/purchase_receipt.py`, `purchase_receipt/mapper.py`.
- Shared: `erpnext/controllers/buying_controller.py`, `erpnext/controllers/status_updater.py` (`status_map`), `erpnext/setup/setup_wizard/operations/install_fixtures.py` (`update_buying_defaults`).
- Reports and dashboard: `erpnext/buying/buying_dashboard/buying/buying.json`, `erpnext/buying/number_card/*`, `erpnext/buying/dashboard_chart/*`, `erpnext/buying/report/{purchase_analytics,purchase_order_analysis,supplier_quotation_comparison}/`, `erpnext/accounts/report/purchase_register/`.

---

## 1. Scope & sidebar mapping

Module id `buying`, label **Buying**. `src/config/navigation.ts` already lists this sidebar.

| Sidebar group › item | Route / target | Kind | Phase |
|---|---|---|---|
| Home | `/[org]/buying` | workspace | P6 |
| Dashboard | `/[org]/buying/dashboard` | DashboardView (§7.1) | P6 |
| Supplier | `buying/supplier` | doctype | P2 |
| Material Request | `stock/material-request` | submittable (alias) | P4 |
| Request for Quotation | `buying/request-for-quotation` | submittable | P6 |
| Supplier Quotation | `buying/supplier-quotation` | submittable | P6 |
| Purchase Order | `buying/purchase-order` | submittable | P6 |
| Purchase Receipt | `stock/purchase-receipt` | submittable (alias) | P6 |
| Purchase Invoice | `accounts/purchase-invoice` | alias of 01-accounts | P6 |
| Reports › Purchase Analytics, Purchase Order Analysis, Purchase Register, Supplier Quotation Comparison | `buying/report/<slug>` | ReportView | P6 |
| Reports › Accounts Payable, Accounts Payable Summary | `accounts/report/<slug>` | alias of 01-accounts | P7 |
| Items › Item, Item Group, Price List | `stock/item`, `stock/item-group`, `stock/price-list` | aliases | P2 |
| Setup › Supplier Group | `buying/supplier-group` | tree | P2 |
| Setup › Supplier Scorecard | `buying/supplier-scorecard` | doctype (basic, §2.8) | P6 |
| Setup › Settings | `buying/settings` | single | P6 (row seeded in A4/A21) |

Out of scope: Pricing Rule, Blanket Order, subcontracting (`is_subcontracted` is stored and left false; the subcontracting order is P8), inter-company purchase orders, supplier portal, Landed Cost Voucher (04-stock), Putaway Rule, Quality Inspection.

---

## 2. Doctype inventory

Conventions match 01-accounts §2. Perms are ERPNext JSON `permlevel 0` after the role fold in §9 item 2.

### 2.1 Supplier → `supplier`

- **Kind:** master. **Naming** (`supplier.py: autoname`, `buying_settings.supp_master_name`, wizard value `Supplier Name`):
  - `Supplier Name`: `name = supplier_name`. A duplicate name fails the unique check. Unlike Customer, ERPNext does not append `" - 2"`.
  - `Naming Series`: `SUP-.YYYY.-`.
  - `Auto Name`: the doctype autoname is `naming_series:`, so this is also `SUP-.YYYY.-`. The wizard never selects it.
- **Perms:** Purchase User r, Purchase Manager rwcd (JSON gives delete to Purchase Master Manager only — folded, §9 item 2), Stock User r, Stock Manager r, Accounts User r, Accounts Manager r.
- **Migration:** `02nn_buying_supplier.sql`.

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| supplier_name | text | ✔ | | |
| supplier_group | supplier_group_id | | | must be a leaf |
| supplier_type | text check `Company\|Individual\|Partnership` | ✔ | `Company` | |
| country | text | | | |
| tax_id | text | | | |
| tax_category | tax_category_id | | | |
| tax_withholding_category | tax_withholding_category_id | | | P7; the link exists, TDS runs on the invoice (01-accounts §3.10) |
| default_currency | text | | | document currency; the party account stays company currency |
| default_price_list | price_list_id | | | must be a buying list |
| payment_terms | payment_terms_template_id | | | |
| language | text | | | |
| website | text | | | |
| supplier_details | text | | | |
| supplier_primary_contact | contact_id | | | must already be linked to this supplier |
| supplier_primary_address | address_id | | | same |
| is_transporter | boolean | | false | Delivery Note `transporter` (02-selling) links here |
| disabled | boolean | | false | blocks buying documents |
| is_frozen | boolean | | false | "Supplier {0} is frozen" |
| on_hold | boolean | | false | clears `release_date` when off |
| hold_type | text check `All\|Invoices\|Payments` | | `All` | set when hold is turned on with no type |
| release_date | date | | | hold applies while this is empty or still in the future (`is_blocked_for`) |
| allow_purchase_invoice_creation_without_purchase_order | boolean | | false | bypass when `po_required = Yes` |
| allow_purchase_invoice_creation_without_purchase_receipt | boolean | | false | bypass when `pr_required = Yes` |
| default_bank_account | bank_account_id | | | P7 |
| alias | text | | | unique per org |
| accounts | `party_account` | | | company payable override (01-accounts) |
| warn_rfqs, prevent_rfqs, warn_pos, prevent_pos | boolean | | false | read-only; only a scorecard period would set them, and that job is not built (§2.8) |

- **Validate:** `validate_party_accounts`; buying price list; primary contact and address must have a Dynamic Link to this supplier ("{0} {1} is not linked to Supplier {2}"). Internal supplier, portal users and customer-number rows are not ported.
- **Hold:** `All` blocks purchase orders, receipts and invoices. `Invoices` blocks purchase invoices. `Payments` blocks payment entries. The block lifts on `release_date`.
- **Connections:** Request for Quotation, Supplier Quotation, Purchase Order, Purchase Receipt, Purchase Invoice, Payment Entry, addresses and contacts.
- **Built (0237):** A saved supplier is named from the trimmed supplier name, and a duplicate name is rejected. A group supplier group, a selling price list, and a non-payable account are rejected. A primary contact or address that is not linked to the supplier is rejected. Turning hold off clears the release date, and turning hold on with no type sets `All`. `app.get_party_account` walks the supplier, then the supplier group, then the company payable. `app.get_supplier_group_details` copies the group's payment terms and accounts. System Manager and Purchase User can read. Purchase Manager can create and delete. Stock and Accounts roles can read. Naming Series waits for Buying Settings.

### 2.2 Supplier Group → `supplier_group`

- **Kind:** tree, org-level. **Naming:** `field:supplier_group_name`. **Perms:** Purchase Manager rwcd; Purchase User and Accounts User read. System Manager also reads (the JSON omits that role). Purchase Manager holds the rwcd that the JSON gives Purchase Master Manager, which is not seeded (§9).
- **Migration:** `0207_buying_supplier_group.sql`. Parent of a new non-root defaults to the root (`All Supplier Groups`).
- Fields in this migration: `supplier_group_name` ✔, `parent_id`, `is_group` default false, `path`. `payment_terms` and `accounts` wait for Payment Terms and Account.
- A group with children cannot become a leaf. A leaf selected on a supplier cannot become a group; that check lands with Supplier.
- **Seed (00-setup A9):** `All Supplier Groups` (group) → `Services`, `Local`, `Raw Material`, `Electrical`, `Hardware`, `Pharmaceutical`, `Distributor`.

### 2.3 Request for Quotation → `request_for_quotation`

- **Kind:** submittable, company-scoped. **Naming:** `PUR-RFQ-.YYYY.-`. **Title:** company. **Perms:** Purchase Manager rwcsxd, Purchase User rwc (no submit), Stock User r. Manufacturing Manager is a seeded role and keeps rwcsxd.
- **Migration:** `06nn_buying_request_for_quotation.sql`.
- Header: `company` ✔, `transaction_date` ✔ default today, `schedule_date`, `subject` ✔ default `Request for Quotation`, `message_for_supplier` default `Please supply the specified items at the best possible rates`, `email_template`, `billing_address`, `shipping_address`, `tc_name`, `terms`, `letter_head`, `status` (`Draft|Submitted|Cancelled`).
- Suppliers child `request_for_quotation_supplier` ✔: `supplier` ✔, `contact`, `email_id` fetched, `send_email` default true, `quote_status` (`Pending|Received`, set on submit to Pending and to Received when a supplier quotation is submitted), `email_sent`.
- Items child `request_for_quotation_item` ✔: `item_code` ✔, `qty` ✔, `uom` ✔, `stock_uom`, `conversion_factor`, `stock_qty`, `schedule_date` ✔ default today, `warehouse`, `material_request`, `material_request_item`, `project`, `cost_center`.
- **Validate:** no duplicate supplier ("Same supplier has been entered multiple times"); supplier not disabled or frozen; `prevent_rfqs` throws "RFQs are not allowed for {0} due to a scorecard standing of {1}" and `warn_rfqs` warns (both stay false, §2.8); qty non-zero unless `allow_zero_qty_in_request_for_quotation` (default 0).
- **Submit:** status `Submitted`. ERPNext then emails each supplier with `send_email`. We create the email through the existing outbound path (00-setup) and do not block submit when no email account is configured: the message is skipped and the form says so.
- **Create:** Supplier Quotation, one draft per supplier (§3.2).

### 2.4 Supplier Quotation → `supplier_quotation` + `supplier_quotation_item`

- **Kind:** submittable, company-scoped. **Naming:** `PUR-SQTN-.YYYY.-`. **Title:** `supplier_name`. **Perms:** Purchase Manager rwcsxd, Purchase User rwcs (no cancel), Stock User r, Manufacturing Manager rwcsxd.
- **Migration:** `06nn_buying_supplier_quotation.sql`.
- Header is the buying money document: `supplier` ✔, `transaction_date` ✔, `valid_till`, `quotation_number`, `currency` ✔, `conversion_rate` ✔, `buying_price_list`, taxes (`Purchase Taxes and Charges`, with `taxes_and_charges_added` / `_deducted`), discount, rounded total, `status` §5.2, `cost_center`, `project`, addresses. `is_subcontracted` is stored and forced false (§9).
- Items: the standard buying row (item, qty, uom, conversion, rate, discount, margin, amount, net, warehouse, `item_tax_template`) plus `request_for_quotation`, `request_for_quotation_item`, `prevdoc_docname` (material request), `prevdoc_detail_docname`, `project`.
- **Validate:** buying-controller checks (§3.6); `valid_till` not before `transaction_date` ("Valid till Date cannot be before Transaction Date"); material-request company, item and UOM match; `set_status`.
- **Submit / cancel:** refresh status. Submitting sets the matching RFQ supplier row to `quote_status = Received`; cancelling the last quotation for that supplier sets it back to `Pending`.
- **Create:** Purchase Order (§3.3), Purchase Invoice (01-accounts §3.2).

### 2.5 Purchase Order → `purchase_order` + `purchase_order_item`

- **Kind:** submittable, company-scoped. **Naming:** `PUR-ORD-.YYYY.-`. **Title:** `supplier_name`. **Perms:** Purchase Manager rwcsxd, Purchase User rwcsxd, Stock User r.
- **Migration:** `06nn_buying_purchase_order.sql`.
- Header adds, on the supplier-quotation money set: `schedule_date`, `set_warehouse`, `advance_paid` read-only, `per_received`, `per_billed`, `advance_payment_status` (`Not Initiated|Initiated|Partially Paid|Fully Paid`), `status` §5.3, `project`, `cost_center`, `payment_terms_template`, `payment_schedule`. Inter-company, subcontracting warehouse and MPS columns are omitted. `is_subcontracted` stays false.
- Items add: `schedule_date`, `expected_delivery_date`, `supplier_quotation`, `supplier_quotation_item`, `material_request`, `material_request_item`, `sales_order`, `sales_order_item` (drop ship, §3.5), `received_qty`, `returned_qty`, `billed_amt`, `closed`, `warehouse`, `expense_account`, `cost_center`, `project`, `last_purchase_rate`.
- **Validate:** §3.6; supplier scorecard block (§2.1, inert); schedule date (§3.6); previous-doc match against supplier quotation and material request; `maintain_same_rate` (default on, §2.7) against the supplier quotation; item `min_order_qty` ("Item {0}: Ordered qty {1} cannot be less than minimum order qty {2}"); `set_status`.
- **Submit:** material-request `ordered_qty` and supplier-quotation status; bin `ordered_qty`; budget check (01-accounts §4.7, P7 — skipped until budgets exist); Authorization Rule on `base_grand_total`; project purchase cost when `project_update_frequency = Each Transaction`.
- **Cancel:** refused while Closed. Reverses ordered qty on the material request, the supplier quotation and the bin. Unlinks advances when `unlink_advance_payment_on_cancelation_of_order = 1` (01-accounts §3.8).
- **Close / Hold:** §5.3.

### 2.6 Purchase Receipt → `purchase_receipt` + `purchase_receipt_item`

- **Kind:** submittable, company-scoped. Owned here for the buying document; SLE and the Stock Received But Not Billed GL are 04-stock, summarised in §4. **Naming:** `MAT-PRE-.YYYY.-`; returns use `MAT-PR-RET-.YYYY.-`. **Title:** `supplier_name`. **Perms:** Stock Manager rwcsxd, Stock User rwcsxd, Purchase User rwcsxd, Accounts User r.
- **Migration:** `06nn_stock_purchase_receipt.sql`.
- Header adds: `posting_date` ✔, `posting_time` ✔, `set_posting_time`, `supplier_delivery_note`, `is_return`, `return_against`, `set_warehouse`, `rejected_warehouse`, `per_billed`, `per_returned`, `status` §5.4, `lr_no`, `lr_date`, `transporter_name`, `instructions`, `remarks`. Subcontracting supplied-items and putaway are omitted.
- Items add: `purchase_order`, `purchase_order_item`, `received_qty`, `qty` (accepted), `rejected_qty`, `returned_qty`, `billed_amt`, `warehouse`, `rejected_warehouse`, `expense_account`, `cost_center`, `project`, serial/batch columns (04-stock), `allow_zero_valuation_rate`, `closed`.
- **Validate:** posting time vs fiscal year; §3.6; accepted + rejected = received; a rejected qty needs `rejected_warehouse`; `po_required` (§3.7); previous-doc match (supplier, currency, item, UOM, conversion factor); over-receipt against `stock_settings.over_delivery_receipt_allowance` (default 0) plus the item allowance; return qty limits (01-accounts §3.4 shape).
- **Submit:** inward SLE for accepted qty into `warehouse` and, when rejected qty is valued (`set_valuation_rate_for_rejected_materials`, default 0, so rejected qty does not enter stock value), rejected qty into `rejected_warehouse`; perpetual GL Dr Stock / Cr Stock Received But Not Billed (§4); purchase-order `received_qty` / `per_received`.
- **Cancel:** reverses SLE and GL and rolls the order back. A submitted purchase invoice that cites the receipt blocks cancel.

### 2.7 Buying Settings → `buying_settings`

Single, one row per org. A4 seeds JSON defaults; A21 applies the wizard overrides. **Perms:** System Manager rwc, Purchase Manager rwc, Purchase User r, Accounts User r, Accounts Manager r, Stock User r, Stock Manager r.

| field | JSON default | After A21 | Effect |
|---|---|---|---|
| supp_master_name | `Supplier Name` | `Supplier Name` | §2.1 |
| supplier_group | null | null | not auto-filled |
| buying_price_list | null | null | not set by the wizard; the user picks `Standard Buying` (§3.8) |
| po_required | null | `No` | §3.7 |
| pr_required | null | `No` | §3.7 |
| maintain_same_rate | 0 | **1** | PO rate must equal the supplier-quotation rate |
| maintain_same_rate_action | `Stop` | `Stop` | `Warn` alerts; `role_to_override_stop_action` may bypass Stop |
| allow_multiple_items | 0 | **1** | duplicate item rows allowed (§3.6) |
| bill_for_rejected_quantity_in_purchase_invoice | 1 | 1 | rejected qty is included in the billed qty (01-accounts §3.2) |
| set_landed_cost_based_on_purchase_invoice_rate | 0 | 0 | valuation taxes use the receipt rate |
| disable_last_purchase_rate | 0 | 0 | last purchase rate may fill an empty item rate |
| project_update_frequency | `Each Transaction` | `Each Transaction` | PO submit refreshes project purchase cost |
| allow_zero_qty_in_purchase_order / `_request_for_quotation` / `_supplier_quotation` | 0 | 0 | qty must be non-zero |
| allow_negative_rates_for_items | 0 | 0 | rate must be ≥ 0 |
| over_order_allowance | null | null | extra fraction allowed when ordering against a material request; null means the stock over-delivery allowance |
| set_valuation_rate_for_rejected_materials | 0 | 0 | rejected qty is recorded and not valued |
| auto_create_purchase_receipt | 0 | 0 | submitting a PO does not create a receipt |
| blanket_order_allowance | 0 | 0 | inert |
| backflush_raw_materials_of_subcontract_based_on | `BOM` | `BOM` | P8 |
| auto_create_subcontracting_order | 0 | 0 | P8 |
| use_transaction_date_exchange_rate | 0 | 0 | single-currency path ignores it |
| show_pay_button | 1 | 1 | Payment button on the purchase order |

### 2.8 Supplier Scorecard (basic)

PLAN P6 asks for a read-only basic scorecard. P6 ships the configuration ERPNext installs, and does not run the period scorer.

- **Seed** (`supplier_scorecard.py: make_default_records`, the fixture 00-setup left for this doc):
  - Variables, each `param_name` / `variable_label` / `path`: total accepted items and amount, total rejected items and amount, total received items and amount, RFQ response days, SQ total items, SQ total number, RFQ total number, RFQ total items, total item days, number of on-time shipments, cost of delayed shipments, cost of on-time shipments, total working days, total cost of shipments, total days late, total shipments, total ordered, total invoiced.
  - Standings: Very Poor 0–30 (prevent RFQs and POs, red), Poor 30–50 (warn RFQs and POs, yellow), Average 50–80 (green), Excellent 80–100 (blue).
- **`supplier_scorecard`:** one row per supplier. `supplier` unique, `period` (`Per Week|Per Month|Per Year`) default `Per Month`, `weighting_function` default `{total_score} * max( 0, min ( 1 , (12 - {period_number}) / 12) )`, `standings` copied from the seed, `criteria` (variable, weight, formula). **Perms:** System Manager rwcd. Purchase Manager gets read (§9 item 2).
- **Not built:** `supplier_scorecard_period`, the scheduled scorer, and writing `warn_*` / `prevent_*` on the supplier. The RFQ and PO checks stay in the code and do not fire. **Reason:** PLAN's "read-only basic"; the scoring job depends on a full receipt history and sends mail.

### 2.9 Material Request (purchase type)

The doctype is specified with 04-stock. This doc owns the Purchase path only.

- **Naming:** `MAT-MR-.YYYY.-`. **Type kept here:** `Purchase`. `Material Transfer`, `Material Issue`, `Manufacture`, `Customer Provided` are 04-stock. `Subcontracting` is P8.
- Purchase rows: `item_code` ✔, `qty` ✔, `uom`, `stock_qty`, `schedule_date` ✔, `warehouse` ✔, `ordered_qty`, `received_qty`, `rate`, `amount`, `project`, `cost_center`, `sales_order` (when raised from a sales order).
- **Status** for `Purchase` (03-posting-engine, from `status_map`): `Pending` (nothing ordered), `Partially Ordered`, `Ordered` (`per_ordered = 100`), `Partially Received`, `Received` (`per_received = 100`), `Stopped`, `Cancelled`, `Draft`.
- **Create:** Request for Quotation (§3.1), Supplier Quotation, Purchase Order (§3.4). Stopped and ordered-in-full rows are not offered.

---

## 3. Document flows & mappers

`app.map_doc` returns an unsaved draft. The form runs `app.get_item_details` and the taxes pipeline (01-accounts §3.11, buying branch: `add_deduct_tax`, `category`).

```
Material Request (Purchase) ─┬─► Request for Quotation ─► Supplier Quotation ─┬─► Purchase Order ─┬─► Purchase Receipt ─► Purchase Invoice
                             ├─► Supplier Quotation                           └─► Purchase Invoice ├─► Purchase Invoice
                             └─► Purchase Order                                                 └─► Payment Entry (advance)
Sales Order (delivered_by_supplier) ─► Purchase Order
```

### 3.1 Material Request → Request for Quotation

`material_request/mapper.py: make_request_for_quotation`. Source submitted, type Purchase, not Stopped. Items with remaining qty (`ordered_qty < stock_qty`) are copied with `material_request` and `material_request_item`, warehouse and schedule date. Suppliers are empty; the user adds them. One RFQ can collect several requests.

### 3.2 Request for Quotation → Supplier Quotation

`request_for_quotation/mapper.py: make_supplier_quotation_from_rfq`. One draft per selected supplier (default: every supplier on the RFQ). Copies items, terms, addresses and the message. `supplier` is the row's supplier. Qty is the RFQ qty. The quotation is not submitted automatically.

### 3.3 Supplier Quotation → Purchase Order

`supplier_quotation/mapper.py: make_purchase_order`. Refused when the quotation's computed status is Expired ("Supplier Quotation {0} has expired."). Source submitted. Item qty is the remaining stock qty (`stock_qty − ordered_qty`). `transaction_date` is not copied (the order is dated today). Taxes are copied and recalculated. With `maintain_same_rate` (our default), saving the order throws if the rate was changed (`Stop`).

### 3.4 Material Request → Purchase Order

`material_request/mapper.py: make_purchase_order`. Rows with `ordered_qty < stock_qty`. The user must set `supplier` (the mapper takes it as an argument; the form asks). `material_request` and `material_request_item` are set. Rate comes from the buying price list, then last purchase rate when `disable_last_purchase_rate` is off.

`make_purchase_orders_by_supplier` (one order per item-default supplier) is not built. The form makes one order and the user picks the supplier.

### 3.5 Purchase Order → Receipt, invoice, and drop ship

- **Receipt** (`purchase_order/mapper.py: make_purchase_receipt`): submitted order, row not closed. Qty is `qty − received_qty`, or the remainder of the over-receipt allowance when the ordered qty is already received. `purchase_order` and `purchase_order_item` are set. Rate is the order rate.
- **Invoice** (`make_purchase_invoice`): 01-accounts §3.2. Qty is `qty − billed`. A receipt's invoice uses `received − billed − returned`, and adds `rejected_qty` when `bill_for_rejected_quantity_in_purchase_invoice` is on.
- **Drop ship:** a sales-order row with `delivered_by_supplier` and a supplier (02-selling §3.5) maps through `sales_order/mapper.py: make_purchase_order`. The order item keeps `sales_order` / `sales_order_item`. Receipt updates the sales order's `delivered_qty` from received purchase-order qty (`sales_order` status service `get_drop_ship_delivered_qty`) and does not require a delivery note for that row.
- **Payment:** 01-accounts §3.3, shown because `show_pay_button = 1`.

### 3.6 Buying controller checks

From `buying_controller.py` and `purchase_order.py`, skipping subcontracting, landed cost and returns-only steps:

1. Supplier not disabled, frozen, or held for this document (§2.1).
2. Item is a purchase item and is not disabled. UOM is allowed. Whole-number UOMs reject fractions.
3. `stock_qty = qty × conversion_factor`.
4. Duplicate rows. Skipped while `allow_multiple_items = 1` (our default). When it is 0, the same item + description + warehouse throws the buying equivalent of the selling duplicate message.
5. Warehouse is required on stock items for the receipt and for an invoice that updates stock. The order requires a warehouse when the item is a stock item.
6. **Schedule date:** the header becomes the earliest item date; empty item dates copy the header. An item date before `transaction_date` throws "Row #{idx}: Required By cannot be before Date." No date at all throws "Please enter the Required By."
7. **Rate:** negative rates throw unless `allow_negative_rates_for_items`. Last purchase rate fills an empty rate unless `disable_last_purchase_rate`.
8. **Same rate:** when `maintain_same_rate` and the row cites a supplier quotation, the rate must match. `Stop` throws; `Warn` alerts.

### 3.7 When an order or a receipt is required

Purchase Invoice only (01-accounts §3.2, flags live here). Returns skip the check.

- `po_required = Yes` and the supplier does **not** have "Allow purchase invoice creation without purchase order": every item needs a purchase order ("Purchase Order Required for item {0}").
- `pr_required = Yes` and the supplier does **not** have the receipt bypass: every item needs a purchase receipt, unless the invoice itself has `update_stock` ("Purchase Receipt Required for item {0}").

The receipt does not require a purchase order when `po_required` is Yes. That flag is an invoice rule. `auto_create_purchase_receipt` stays 0, so submitting an order never makes a receipt.

### 3.8 Price list

Same shape as selling §3.9, on the buying side (`party.py: set_price_list`): the supplier's `default_price_list` when enabled, else the list already on the document, else `buying_settings.buying_price_list`. Supplier groups have no default price list. The settings field stays null, so the user selects `Standard Buying`.

### 3.9 Returns

`app.make_return_doc('Purchase Receipt', id)` and the purchase-invoice debit note (01-accounts §3.4). The receipt return uses `MAT-PR-RET-.YYYY.-`, negates the not-yet-returned accepted qty, and posts a reversing SLE out of the warehouse. Rejected qty is returned from `rejected_warehouse` by the same document when the user includes it.

### 3.10 Close and hold

- **Purchase Order → Close** (`close_or_unclose_purchase_orders`): submitted, not already closed, and `per_received < 100` or `per_billed < 100`. A closed order is not received or billed further. **Re-open** runs `set_status` again. Cancel is refused while Closed.
- **Hold:** `On Hold` blocks new receipts and invoices. Resume recalculates status.
- **Close a row:** `closed` on an order or receipt item. A closed order row is skipped by the receipt and invoice mappers. The header does not become Closed just because every row is closed.

---

## 4. Posting rules

Request for Quotation, Supplier Quotation and Purchase Order post no ledger rows. Submitting an order increases bin `ordered_qty` for each stock item and warehouse (04-stock). Cancelling removes it. `advance_paid` is the payment-ledger sum whose `advance_voucher` is the order (01-accounts §4.0). `advance_payment_status` is driven by Payment Request, which is out of scope, so it stays `Not Initiated` and the order never becomes `To Pay`.

Purchase Receipt submit calls `app.on_submit__purchase_receipt`:

- Inward SLE per accepted row at the incoming rate (qty × net rate, plus valuation-category taxes). Rejected qty gets an SLE only when `set_valuation_rate_for_rejected_materials = 1` (default off): the qty is stored on the row and excluded from valuation.
- Perpetual GL, already in 03-posting-engine: Dr warehouse stock account / Cr **Stock Received But Not Billed**. No party ledger. The purchase invoice later clears Stock Received But Not Billed (01-accounts §4.4) or, when there was no receipt, debits the item expense account directly.
- Purchase order `received_qty` and `per_received`, then the order status (§5.3).

Purchase Invoice posting stays in 01-accounts §4. Submitting it updates `billed_amt` / `per_billed` on the order and the receipt.

---

## 5. Statuses

`app.set_status` walks `status_map` from the bottom and keeps the first match.

### 5.1 Request for Quotation

`Draft`, `Submitted`, `Cancelled`. There is no partial status. Each supplier row is `Pending` until one of its supplier quotations is submitted, then `Received`.

### 5.2 Supplier Quotation

| Status | When it wins |
|---|---|
| Cancelled | `docstatus = 2` |
| Ordered | every row has ordered qty covering `stock_qty` |
| Partially Ordered | some of the qty is ordered |
| Expired | submitted, `valid_till` before today |
| Stopped | status is already Stopped |
| Submitted | submitted, none of the above |
| Draft | not submitted |

Stop is an action on a submitted quotation. A stopped quotation cannot be ordered. Expired is in the map, unlike the sales quotation, so a later `set_status` keeps it.

### 5.3 Purchase Order

Bottom-up, so Closed, On Hold, Cancelled, Delivered and Completed beat the in-progress states. `To Pay` beats them only when `advance_payment_status = Initiated`, which we never set (§4).

| Status | Condition |
|---|---|
| Closed | status already Closed, not cancelled |
| On Hold | status already On Hold |
| Cancelled | `docstatus = 2` |
| Delivered | status already Delivered. Nothing in the default flow assigns it |
| Completed | `per_received ≥ 100` and `per_billed = 100`, submitted |
| To Pay | `advance_payment_status = Initiated` |
| To Receive and Bill | both percentages under 100, submitted |
| To Receive | `per_received < 100` and `per_billed = 100` |
| To Bill | `per_received ≥ 100` and `per_billed < 100` |
| Draft | otherwise |

`per_received` is qty-based over rows that are not closed. `per_billed` is amount-based (`Σ billed_amt / Σ amount`). Completed requires `per_billed = 100`, not `≥ 100` (the sales order uses `≥`).

### 5.4 Purchase Receipt

| Status | Condition |
|---|---|
| Closed | status already Closed, not cancelled |
| Cancelled | `docstatus = 2` |
| Completed | `per_billed ≥ 100`, or submitted with `grand_total = 0` and not a full return |
| Return Issued | `per_returned = 100` |
| Return | `is_return` and `per_billed = 0` |
| Partly Billed | `0 < per_billed < 100` (the receipt says "Partly"; the delivery note says "Partially") |
| To Bill | submitted and `per_billed = 0` |
| Draft | otherwise |

---

## 6. Settings & defaults

Wizard values are 00-setup A21, copied in §2.7. Supplier groups are A9, inserted by the P2 migration. `Standard Buying` is the price list P2 creates; Buying Settings does not point at it.

Authorization Rule applies to Purchase Order on submit, on `base_grand_total`.

Supplier-scorecard variables and standings are seeded in P6 (§2.8), not during onboarding. 00-setup lists them under skipped fixtures for that reason.

---

## 7. Reports & dashboard

### 7.1 Dashboard

`buying_dashboard/buying/buying.json`.

| Card | Query |
|---|---|
| Annual Purchase | Sum of `base_net_total` on submitted purchase orders dated this calendar year, status not Draft, Cancelled or Closed |
| Purchase Orders to Receive | Count, submitted, status in `To Receive and Bill`, `To Receive` |
| Purchase Orders to Bill | Count, submitted, status in `To Receive and Bill`, `To Bill` |
| Active Suppliers | Count, `disabled = false` |

| Chart | Source | Default filters |
|---|---|---|
| Purchase Order Trends | Purchase Order Trends report | monthly, based on item, by posting date |
| Material Request Analysis | group-by on Material Request | type Purchase, submitted, not Draft/Cancelled/Stopped, last quarter |
| Purchase Order Analysis | Purchase Order Analysis report | one row per order |
| Top Suppliers | Purchase Receipt Trends report | monthly, based on supplier |

`Average Order Values`, `Purchase Orders Count` and `Total Purchase Amount` exist as number cards and are not on the default dashboard. All three exclude `is_subcontracted`.

### 7.2 Purchase Analytics

`app.report_purchase_analytics`. The buying twin of Sales Analytics (02-selling §7.2): `tree_type` is Supplier, Supplier Group, Item, Item Group or Warehouse; `doc_type` is Material Request, Request for Quotation, Supplier Quotation, Purchase Order, Purchase Receipt, Purchase Invoice or All; value is `base_net_total`, quantity is stock qty. Date field is `transaction_date` for the order and the quotation, `posting_date` for the receipt and the invoice, `schedule_date` for the material request.

### 7.3 Purchase Order Analysis

`app.report_purchase_order_analysis`. One row per order, or one row per item when `group_by_po = 0` is off. Columns: order, date, supplier, required by, received %, billed %, qty, received qty, billed amount, pending qty, amount. Filters: company, from/to date, supplier, item, status. The dashboard chart uses `group_by_po = 0`.

### 7.4 Purchase Register

`app.report_purchase_register`. Port of `accounts/report/purchase_register`: submitted purchase invoices and debit notes in a date range. Columns mirror the sales register (02-selling §7.3) with supplier, supplier invoice no, payable account, purchase order and purchase receipt. Filters: company, from/to date, supplier, supplier group, item, warehouse.

### 7.5 Supplier Quotation Comparison

`app.report_supplier_quotation_comparison`. Rows are items; columns are the supplier quotations that quote them, with qty, rate and amount. The lowest rate in a row is marked. Filters: company ✔, from/to date, item, supplier, supplier quotation, request for quotation, group by (supplier or item), quotation status, include expired (default off).

### 7.6 Accounts Payable

The Buying sidebar links to the P7 reports in 01-accounts. No second query.

---

## 8. UI notes

- Supplier form: Details (name, group, type, country, currency, price list), Contact & Address, Tax (tax id, tax category, party accounts, tax withholding category shown but calculated in P7), Settings (disabled, frozen, hold type, release date, the two "allow invoice without…" checks). Scorecard flags are hidden.
- Request for Quotation is a header, a suppliers table and an items table, plus terms. Supplier Quotation, Purchase Order and Purchase Receipt share the transaction layout from 02-selling §8, with supplier instead of customer and Required By instead of delivery date. Purchase taxes show Added and Deducted totals.
- Create menu: Material Request → Request for Quotation, Purchase Order. Request for Quotation → Supplier Quotation. Supplier Quotation → Purchase Order, Purchase Invoice. Purchase Order → Purchase Receipt, Purchase Invoice, Payment, Close, Hold. Purchase Receipt → Purchase Invoice, Return, Close.
- Lists: status badge, party, date, grand total. Orders also show received % and billed %.
- Dashboard: four cards, then the charts at the widths in §7.1 (trends and top suppliers full width, the other two half).
- Settings is the §2.7 form. Subcontracting and blanket-order fields are hidden.
- Scorecard: a list of suppliers, opening a form of standings (read-only, from the seed) and criteria weights. No period history and no "recalculate" button.
- Empty, loading and error states on every list and on the dashboard.

---

## 9. Deviations from ERPNext

1. **Deviation:** subcontracting, inter-company orders, blanket orders, supplier portal, putaway and quality inspection are not built. `is_subcontracted` is stored as false and the form hides it. **Reason:** subcontracting is P8; the rest are outside PLAN §1.
2. **Deviation:** Purchase Master Manager is not a role (00-setup §2.7). Supplier and Supplier Group grant that role's rwcd to Purchase Manager. Purchase User stays read-only on Supplier, as in the JSON. Quality Manager and Delivery User/Manager are dropped; the receipt already grants Stock User rwcsxd. **Reason:** the seeded role list.
3. **Deviation:** Supplier Scorecard does not generate periods or set `prevent_rfqs` / `prevent_pos` / `warn_*`. The checks in the RFQ and the purchase order stay and do not fire. **Reason:** PLAN P6 "read-only basic".
4. **Deviation:** `make_purchase_orders_by_supplier` and the RFQ email send are reduced. One purchase order is created per action, and submit of an RFQ does not fail when outbound email is not configured. **Reason:** the bulk splitter is a desk tool with no extra accounting; email must not block a document that has no mail account.
5. **Deviation:** last-purchase-rate fallback and `maintain_same_rate = 1` are kept (they are the wizard defaults). Pricing rules that would also change the rate are not. **Reason:** Pricing Rule is out of scope; the rate checks are buying settings, not pricing rules.
6. **Deviation:** Buying sidebar entries for Purchase Invoice, Purchase Receipt, Material Request, Item, Item Group and Price List open the canonical route in §1. **Reason:** one table, one form; the current `navigation.ts` paths are placeholders until P6.
7. **Not a deviation (recorded for implementers):** `supp_master_name = Auto Name` uses `naming_series:` (`SUP-.YYYY.-`). A duplicate supplier name is rejected, unlike Customer, which suffixes `" - n"`. The wizard sets `Supplier Name`. `advance_payment_status` stays `Not Initiated` because Payment Request is out of scope, so `To Pay` is never selected. Purchase-receipt status uses "Partly Billed"; the delivery note uses "Partially Billed".

---

## 10. Implementation checklist

Migration numbers: P2 `02nn_buying_*`, P4 material request with 04-stock, P6 `06nn_buying_*` and `06nn_stock_purchase_receipt.sql`. Each item is one migration (RLS, `doctype_meta`, `role_permissions`), one descriptor, a Zod schema, client mutations, list/form, and a test.

### P2 — masters

- [x] `supplier_group` tree + A9 seed — §2.2
- [x] `supplier` + `party_account` rows — §2.1

### P4 — with stock

- [ ] `material_request` Purchase type, `ordered_qty` / `received_qty`, status — §2.9 (other types in 04-stock)

### P6 — transactions

- [ ] `request_for_quotation` + supplier and item children — §2.3, §3.1, §3.2
- [ ] `supplier_quotation` + items; stop; expiry in `set_status` — §2.4, §5.2
- [ ] `purchase_order` + items; schedule date, min order qty, same-rate, close / hold; bin `ordered_qty` — §2.5, §3.6, §4, §5.3
- [ ] `purchase_receipt` + items; accepted/rejected qty; return series — §2.6, §3.9, §5.4
- [ ] `app.map_doc` for the chain in §3, including drop-ship from the sales order — §3.5
- [ ] `app.update_prevdoc_status` for ordered qty, received qty, billed amount and the status maps — §4, §5
- [ ] Receipt SLE and Stock Received But Not Billed (with 04-stock) — §4
- [ ] Buying Settings form — §2.7
- [ ] Supplier scorecard variables, standings and the per-supplier form, without the period job — §2.8
- [ ] Dashboard and Purchase Analytics, Purchase Order Analysis, Purchase Register, Supplier Quotation Comparison — §7
- [ ] Retarget the Buying nav aliases — §1, §9 item 6
