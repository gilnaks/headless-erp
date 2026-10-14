# 03 — Posting Engine (GL, Stock Ledger, Payment Ledger, Status Updater)

This is the heart of the port. ERPNext's behaviour lives in `erpnext/accounts/general_ledger.py`, `erpnext/stock/stock_ledger.py`, `erpnext/controllers/{accounts_controller,stock_controller,selling_controller,buying_controller,status_updater,taxes_and_totals}.py` and each doctype's `get_gl_entries()` / `update_stock_ledger()`. We port the *default* paths only.

Everything in this document runs in Postgres (`schema app`), inside the transaction opened by `app.submit_doc()` / `app.cancel_doc()`. Server Actions never write to ledger tables directly.

## Ledger tables

### `gl_entry` (from `GL Entry`)

```
id, org_id, company_id, posting_date, fiscal_year_id,
account_id, party_type, party_id, cost_center_id, project_id,
debit numeric, credit numeric,                      -- company currency
account_currency text, debit_in_account_currency, credit_in_account_currency,
against text,                                       -- human summary of counter accounts
against_voucher_type text, against_voucher_id uuid, -- invoice a payment settles
voucher_type text, voucher_id uuid, voucher_no text, voucher_detail_id uuid, voucher_subtype text,
remarks text, is_opening bool, is_advance bool, due_date date,
is_cancelled bool default false, created_at
```

### `stock_ledger_entry` (from `Stock Ledger Entry`)

```
id, org_id, company_id, item_id, warehouse_id, posting_date, posting_time, posting_datetime,
voucher_type, voucher_id, voucher_no, voucher_detail_id,
actual_qty, qty_after_transaction, incoming_rate, outgoing_rate, valuation_rate,
stock_value, stock_value_difference, stock_queue jsonb,     -- FIFO queue [[qty, rate], ...]
stock_uom_id, serial_and_batch_bundle_id, batch_id, has_serial_no, has_batch_no,
fiscal_year_id, project_id, is_cancelled bool, is_adjustment_entry bool,
creation_order bigserial                                   -- tie-break ordering within same datetime
```

### `payment_ledger_entry` (from `Payment Ledger Entry`)

```
id, org_id, company_id, posting_date, account_type ('Receivable'|'Payable'), account_id,
party_type, party_id, voucher_type, voucher_id, against_voucher_type, against_voucher_id,
amount, account_currency, amount_in_account_currency, due_date, cost_center_id, project_id,
delinked bool default false, voucher_detail_id, remarks
```

Outstanding of an invoice = `sum(amount)` of PLE rows where `(against_voucher_type, against_voucher_id)` = the invoice (invoice row positive, payments/credit notes negative). `app.refresh_outstanding(voucher_type, voucher_id)` writes `outstanding_amount` + status (Paid / Unpaid / Partly Paid / Overdue / Return / Credit Note Issued) back on the invoice.

### `bin` (from `Bin`)

`org_id, item_id, warehouse_id, actual_qty, reserved_qty, ordered_qty, indented_qty, planned_qty, projected_qty, reserved_qty_for_production, valuation_rate, stock_value, stock_uom_id`. `projected_qty = actual + ordered + indented + planned − reserved − reserved_for_production − reserved_for_sub_contract`. Updated by `app.update_bin_qty()` after every SLE and by order documents (SO → reserved_qty, PO → ordered_qty, MR → indented_qty, WO → planned_qty / reserved_qty_for_production).

## `app.make_gl_entries(entries jsonb, opts)` (port of `general_ledger.make_gl_entries`)

1. Validate: company + fiscal year open (posting_date inside a fiscal year, not before `companies.accounts_frozen_till_date` unless role allowed), accounts enabled and non-group, account belongs to the company, party required for Receivable/Payable accounts, cost center required for P&L accounts (default to company cost center).
2. Merge similar entries (same account, party, cost center, against voucher, project) unless `merge=false` (Journal Entry keeps rows).
3. Flip negative debit/credit into the other column.
4. Check `sum(debit) = sum(credit)` within rounding allowance; if off by less than `0.5 × 10^-precision × rows`, post the difference to `companies.round_off_account` / `round_off_cost_center`, else raise.
5. Budget check (`app.validate_budget`) for expense accounts against `budget` rows when budgeting is configured (action Stop/Warn/Ignore per budget, default from ERPNext: `Stop` on actual expense).
6. Insert `gl_entry` rows; for Receivable/Payable accounts also insert `payment_ledger_entry` rows; refresh outstanding of referenced invoices.
7. Cancellation (`app.reverse_gl_entries(voucher_type, voucher_id)`): mark original rows `is_cancelled=true`, insert mirrored rows (debit↔credit) also flagged `is_cancelled=true` (ERPNext's "immutable ledger" default-off behaviour still writes reversal rows; reports filter `is_cancelled=false`). Also delink PLE rows and refresh outstanding of invoices that the cancelled payment had settled.

## `app.make_sl_entries(entries jsonb)` (port of `stock_ledger.make_sl_entries` + `update_entries_after`)

For each entry (item, warehouse, posting datetime, actual_qty, incoming_rate | outgoing_rate, voucher refs):

1. Lock `(item, warehouse)` with `pg_advisory_xact_lock`.
2. Determine previous SLE (`posting_datetime <= new` ordered by `posting_datetime, creation_order`).
3. Valuation per `companies.valuation_method` (item override `items.valuation_method`):
   - **FIFO** (default): `stock_queue` list of `[qty, rate]`; inward appends (or merges with same rate at tail); outward consumes from head; if outward exceeds queue (negative stock allowed only when `stock_settings.allow_negative_stock`), the shortfall uses the last known rate. `valuation_rate = stock_value / qty_after`.
   - **Moving Average**: inward `rate = (prev_value + qty×incoming_rate) / (prev_qty + qty)`; outward keeps rate.
4. `qty_after_transaction`, `stock_value`, `stock_value_difference` computed; outward `outgoing_rate` set from valuation and **written back to the voucher item row** (`incoming_rate` on DN/SI items = COGS rate) so GL can use it.
5. Negative stock guard: if `allow_negative_stock = false` and qty_after < 0 at this or any *future* SLE for the item/warehouse → raise `Insufficient stock for <item> in <warehouse>` (ERPNext `NegativeStockError`).
6. If the entry is **back-dated** (future SLEs exist): recompute every later SLE for the (item, warehouse) in order — `app.repost_item_valuation(item, warehouse, from_datetime)` — and re-post the dependent GL stock-value differences for those vouchers. Done synchronously in the same transaction (ERPNext queues a "Repost Item Valuation"; we keep it synchronous and document the volume caveat).
7. `app.update_bin_qty(item, warehouse)` recomputes actual/valuation from the latest SLE, and the derived order quantities from open documents.
8. Cancellation: insert reversing SLE rows (`actual_qty × -1`, `is_cancelled=true` on both) and repost later entries — identical to ERPNext's `make_sl_entries(..., is_cancelled=True)` path.

Serial & Batch (basic scope): `serial_and_batch_bundle` + `serial_and_batch_entry(serial_no_id, batch_id, qty, incoming_rate, stock_value_difference)`; bundles are created automatically for outward entries (FIFO pick) when `stock_settings.auto_create_serial_and_batch_bundle_for_outward` (default true), and entered manually/auto-generated for inward entries. Batch-wise valuation is **not** replicated (ERPNext `do_not_use_batchwise_valuation` is 0, but we keep item-level FIFO for simplicity and document it as a deviation).

## Document → ledger matrix (default accounts; perpetual inventory on)

| Document | Stock Ledger | General Ledger (Dr / Cr) | Payment Ledger | Status side-effects |
|---|---|---|---|---|
| **Journal Entry** | — | As entered per row; party rows with `reference_type/name` settle invoices | rows on Receivable/Payable accounts | refresh outstanding of referenced invoices |
| **Payment Entry** (Receive) | — | Dr `paid_to` (Bank/Cash) ; Cr Debtors (party) split per allocation (`against_voucher` = invoice) ; unallocated remainder Cr Debtors with `is_advance` ; deductions Dr/Cr deduction account | negative amount per allocated invoice; advance row against the PE itself | invoice outstanding/status; SO/PO `advance_paid` when allocated to orders |
| **Payment Entry** (Pay) | — | Dr Creditors (party) per allocation ; Cr `paid_from` | same, payable | same |
| **Payment Entry** (Internal Transfer) | — | Dr `paid_to` ; Cr `paid_from` | — | — |
| **Sales Invoice** | only if `update_stock`: outward per item (warehouse) | Dr Debtors (party, `grand_total`, due_date) ; Cr Income account per item `base_net_amount` ; Cr tax `account_head` per tax row ; rounding to Round Off ; if `update_stock`: Dr COGS (item `expense_account`) / Cr Stock In Hand at valuation ; if `is_return`: all reversed, Cr Debtors against original invoice | +grand_total against itself (negative for returns, against original `return_against`) | SO `per_billed`/status; DN `per_billed`/status; timesheets `billed` ; if return against SI: original `status = Credit Note Issued` when fully returned |
| **Purchase Invoice** | only if `update_stock`: inward per item | Cr Creditors (party, `grand_total`) ; per item: Dr **Stock Received But Not Billed** if received via PR, else Dr item `expense_account` (or Dr Stock In Hand when `update_stock`) ; Dr tax accounts for `add_deduct_tax = Add` & category `Total`; `Valuation` taxes go to item valuation (Dr SRBNB/stock) instead ; rounding ; asset items: Dr CWIP / Asset Received But Not Billed path (Assets module) | +grand_total | PO `per_billed`; PR `per_billed`; `is_return` mirrors |
| **Delivery Note** | outward per item from `warehouse` at valuation (incoming_rate) | Dr COGS (`expense_account` per item, default company `default_expense_account`) ; Cr Stock In Hand (warehouse's account, default company `default_inventory_account`) | — | SO `per_delivered`, `delivered_qty`; `reserved_qty` in bin ; return against DN sets `per_returned` |
| **Purchase Receipt** | inward per item at `rate` + valuation taxes + landed cost (`valuation_rate` on item row); rejected qty goes to `rejected_warehouse` at zero value | Dr Stock In Hand (valuation amount) ; Cr Stock Received But Not Billed (`base_net_amount`) ; Cr tax `account_head` for `Valuation`/`Valuation and Total` rows (ERPNext books to "Expenses Included In Valuation" via the tax account) | — | PO `per_received`, `received_qty`; bin `ordered_qty` ; MR `per_received` |
| **Stock Entry** — Material Receipt | inward to `t_warehouse` at `basic_rate` (+ additional costs) | Dr Stock (target) ; Cr `difference account` (default **Stock Adjustment**; opening entries use **Temporary Opening**) | — | — |
| — Material Issue | outward from `s_warehouse` | Dr Stock Adjustment (or chosen expense) ; Cr Stock | — | MR (Material Issue) `per_ordered` |
| — Material Transfer | outward source, inward target at source valuation | Dr target warehouse account ; Cr source account (no GL if same account) | — | MR (Material Transfer) `per_ordered`; Transit when `add_to_transit` |
| — Material Transfer for Manufacture | source → WIP warehouse | as transfer | — | WO `material_transferred_for_manufacturing` |
| — Manufacture | outward RM from WIP (backflush by BOM × `fg_completed_qty`), inward FG to `fg_warehouse` at Σ RM value + operating cost + additional costs ; scrap inward at scrap rate | Dr FG warehouse ; Cr WIP warehouse ; operating cost: Dr FG / Cr `default_operating_cost_account` (default **Expenses Included In Valuation**) | — | WO `produced_qty`, status `Completed` when produced ≥ qty ; bin planned/reserved_for_production |
| — Repack | outward inputs, inward outputs with value distribution | Dr/Cr per warehouse accounts | — | — |
| **Stock Reconciliation** | per row: adjustment SLE bringing qty/valuation to the entered values (`is_adjustment_entry` for value-only changes) | Dr/Cr Stock vs `expense_account` (default Stock Adjustment; `Temporary Opening` when `purpose = Opening Stock`) | — | — |
| **Work Order** | — (stock moves via Stock Entries) | — | — | bin `planned_qty` (FG) and `reserved_qty_for_production` (RM) ; SO `work_order_qty` |
| **Asset** (capitalise / depreciation / disposal) | — | see `docs/modules/07-assets.md` (Dr Asset account / Cr CWIP or SRBNB ; depreciation Dr Depreciation / Cr Accumulated Depreciation via scheduled Journal Entries) | — | asset status |
| **Period/Opening** | — | Opening Invoice Creation is out of scope; openings via Journal Entry `is_opening = Yes` against **Temporary Opening** | yes for party rows | — |

## Status Updater (port of `controllers/status_updater.py`)

`app.update_prevdoc_status(doctype, id)` runs after submit **and** cancel. Per child row it sums target quantities/amounts from the *submitted* dependants and recomputes percentages on the source with ERPNext's over-allowance rules (`stock_settings.over_delivery_receipt_allowance`, `accounts_settings.over_billing_allowance`, item-level `over_delivery_receipt_allowance`). Then status is derived with the exact expressions from `status_map`:

- **Sales Order**: Draft → `To Deliver and Bill` (per_delivered<100 & per_billed<100) / `To Bill` / `To Deliver` / `Completed` / `Cancelled` / `Closed` / `On Hold`; `skip_delivery_note` (all items non-stock) shortcuts delivery.
- **Purchase Order**: `To Receive and Bill` / `To Bill` / `To Receive` / `Completed` / `Cancelled` / `Closed` / `On Hold` / `Delivered`.
- **Delivery Note**: `To Bill` / `Partially Billed` (ERPNext label) / `Completed` / `Return` / `Return Issued` / `Cancelled` / `Closed`.
- **Purchase Receipt**: `To Bill` / `Partly Billed` / `Completed` / `Return` / `Return Issued` / `Cancelled` / `Closed`.
- **Material Request**: `Pending` / `Partially Ordered` / `Ordered` / `Transferred` / `Issued` / `Partially Received` / `Received` / `Stopped` / `Cancelled` — by `material_request_type`.
- **Quotation**: `Draft` / `Open` / `Lost` / `Partially Ordered` / `Ordered` / `Expired` (valid_till passed, via nightly job) / `Cancelled`.
- **Invoices**: `Draft`, `Unpaid`, `Partly Paid`, `Paid`, `Overdue` (nightly job compares due_date), `Return`, `Credit Note Issued` / `Debit Note Issued`, `Internal Transfer`, `Cancelled`.
- **Work Order**: `Draft`, `Not Started`, `In Process`, `Completed`, `Stopped`, `Closed`, `Cancelled`.
- **Project/Task/Asset/Timesheet**: in module docs.

Percent fields written back: `per_delivered`, `per_billed`, `per_received`, `per_ordered`, `per_returned`, `billing_status`, `delivery_status`, `advance_payment_status`.

## Taxes & Totals (`src/lib/calc/taxes-and-totals.ts`, port of `controllers/taxes_and_totals.py`)

Deterministic pipeline, identical on client and server:

1. Item rows: `amount = qty × rate`; `rate` derived from `price_list_rate`, `discount_percentage`/`discount_amount` (margins out of scope); `stock_qty = qty × conversion_factor`; `base_*` = × `conversion_rate`.
2. `total`, `base_total`, `net_total` (after item-level discount distribution of `discount_amount` when `apply_discount_on = Net Total`).
3. Tax rows in order with `charge_type`: `Actual`, `On Net Total`, `On Previous Row Amount`, `On Previous Row Total`, `On Item Quantity`; `included_in_print_rate` (inclusive tax back-calculation); item-wise tax from `item_tax_template` when `add_taxes_from_item_tax_template` and no explicit tax rows; cumulative `total` per row; `base_` mirrors.
4. `grand_total`, `rounding_adjustment` (round to currency precision per `disable_rounded_total` default false → `rounded_total`), `in_words`.
5. Buying extras: `add_deduct_tax`, `category` (`Valuation`, `Total`, `Valuation and Total`); `taxes_and_charges_added/deducted`, item `valuation_rate` (landed cost = share of valuation taxes by net amount).
6. Payment schedule from Payment Terms Template (`due_date`, `invoice_portion`, `payment_amount`); default single term `due_date = posting_date` (or template credit days).

Rounding: `app.round(value, precision)` in SQL = banker's-free half-away-from-zero, same as `flt(v, p)` in Frappe. The TS port must match bit-for-bit on the regression fixtures in `src/lib/calc/__fixtures__/erpnext-cases.json` (hand-extracted from ERPNext tests `test_taxes_and_totals.py` / `test_sales_invoice.py`).

## Scheduled jobs (Supabase `pg_cron` → SQL functions; Edge Function only when email/network needed)

| Job | Schedule | ERPNext origin |
|---|---|---|
| `app.mark_overdue_invoices()` | daily 00:30 org-local | `accounts_controller.update_invoice_status` |
| `app.expire_quotations()` | daily | `quotation.set_expired_status` |
| `app.post_depreciation_entries(date)` | daily | `assets.depreciation.post_depreciation_entries` (when `book_asset_depreciation_entry_automatically`) |
| `app.reorder_items()` | daily | `stock.reorder_item` (when `stock_settings.auto_indent`) → creates Material Requests |
| `app.refresh_dashboard_cache()` | hourly | number cards / charts materialized views |
| Email digest / notifications | daily | Edge Function `send-email` |

## Testing the engine

- pgTAP suites under `supabase/tests/` seeded with the standard CoA; one file per document type with ERPNext-derived expectations (e.g. SI with 2 items + 1 tax → 4 GL rows balanced; PR + PI → SRBNB nets to zero; SE Manufacture valuation; back-dated DN repost).
- Property tests in Vitest for `taxes-and-totals.ts` vs the SQL `app.calc_taxes_and_totals()` on random documents (the SQL version exists only to re-verify client totals before posting; both must match).
