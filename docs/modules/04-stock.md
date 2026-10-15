# 04 — Stock module

Port of ERPNext v16 (`develop`) **default** stock: items, warehouses, units and prices, the stock ledger (FIFO and moving average), bins, stock entry, stock reconciliation, material request, and basic serial and batch tracking. Delivery Note and Purchase Receipt are specified in Selling and Buying; this doc owns the ledger rows they post.

Read with: `docs/PLAN.md` (§5, §7 P2/P4), `docs/architecture/03-posting-engine.md` (SLE steps, the document matrix), `docs/modules/00-setup.md` (A5, A6, A16, A19, B5, C1, C4), `docs/modules/02-selling.md` (Delivery Note), `docs/modules/03-buying.md` (Purchase Receipt, Material Request type Purchase). Perpetual-inventory GL uses the company stock accounts from 00-setup.

`app.make_stock_ledger_entries` is the only writer of `stock_ledger_entry` and `bin`. TypeScript never posts stock.

One doctype, one route. Selling and Buying sidebar entries for Item, Item Group, Price List, Delivery Note, Purchase Receipt and Material Request open the routes below.

| Doctype | Canonical route | Also linked from |
|---|---|---|
| Item, Item Group, Warehouse, UOM, Brand, Price List, Item Price, Stock Entry, Stock Reconciliation, Material Request, Serial No, Batch, Serial and Batch Bundle, Stock Settings | `/[org]/stock/…` | Selling (Item, Price List), Buying (Item, Item Group, Price List, Material Request) |
| Delivery Note | `/[org]/stock/delivery-note` | Selling (02-selling owns the document) |
| Purchase Receipt | `/[org]/stock/purchase-receipt` | Buying (03-buying owns the document) |

ERPNext sources read (repo-relative to `C:\Users\John\Desktop\erpnext`):

- Masters: `erpnext/stock/doctype/item/item.{json,py}`, `item_default/`, `erpnext/setup/doctype/item_group/`, `uom/`, `brand/`, `erpnext/stock/doctype/warehouse/warehouse.py`, `price_list/`, `item_price/`, `stock_entry_type/`, `warehouse_type/`, `stock_settings/stock_settings.json`.
- Ledger: `erpnext/stock/stock_ledger.py`, `erpnext/stock/valuation.py`, `erpnext/stock/doctype/bin/bin.json`, `erpnext/stock/get_item_details.py`.
- Transactions: `stock_entry/stock_entry.py`, `stock_reconciliation/stock_reconciliation.py`, `material_request/material_request.py`, `serial_and_batch_bundle/`, `batch/`, `serial_no/`, `landed_cost_voucher/landed_cost_voucher.py`, `pick_list/`.
- Reports and dashboard: `erpnext/stock/stock_dashboard/stock/stock.json`, `erpnext/stock/report/{stock_ledger,stock_balance,stock_projected_qty,stock_ageing,stock_analytics}/`.
- Seed: `erpnext/setup/setup_wizard/operations/install_fixtures.py` (`update` of stock settings is 00-setup C4), `company.py` `create_default_warehouses`.

---

## 1. Scope & sidebar mapping

Module id `stock`, label **Stock**. `src/config/navigation.ts` already lists this sidebar and already omits Item Attribute, Inventory Dimension and Quality Inspection.

| Sidebar group › item | Route / target | Kind | Phase |
|---|---|---|---|
| Home | `/[org]/stock` | workspace | P4 |
| Dashboard | `/[org]/stock/dashboard` | DashboardView (§7.1) | P4 |
| Item | `stock/item` | doctype | P2 |
| Warehouse | `stock/warehouse` | tree | P2 |
| Material Request | `stock/material-request` | submittable | P4 |
| Stock Entry | `stock/stock-entry` | submittable | P4 |
| Stock Reconciliation | `stock/stock-reconciliation` | submittable | P4 |
| Purchase Receipt | `stock/purchase-receipt` | alias of 03-buying | P6 |
| Delivery Note | `stock/delivery-note` | alias of 02-selling | P5 |
| Reports › Stock Ledger, Stock Balance, Stock Projected Qty, Stock Ageing, Stock Analytics | `stock/report/<slug>` | ReportView | P4 |
| Tools › Pick List | `stock/pick-list` | submittable | P5 |
| Tools › Landed Cost Voucher | `stock/landed-cost-voucher` | submittable | P6 |
| Tools › Packing Slip | `stock/packing-slip` | submittable | P5 |
| Tools › Quality Inspection | — | not built (§9) | — |
| Serial & Batch › Serial No, Batch, Serial and Batch Bundle | `stock/serial-no`, `stock/batch`, `stock/serial-and-batch-bundle` | doctypes | P4 |
| Setup › Item Group, Brand, UOM | `stock/item-group`, `stock/brand`, `stock/uom` | doctypes | P2 |
| Setup › Price List, Item Price | `stock/price-list`, `stock/item-price` | doctypes (not in the stock sidebar; Selling and Buying link Price List) | P2 |
| Setup › Settings | `stock/settings` | single | P4 (row seeded in A4/C4) |
| *(not in nav)* Stock Entry Type, Warehouse Type, Item Barcode, UOM Conversion Detail, Item Reorder, Item Supplier | children / small masters | with their parent | P2/P4 |

Out of scope: item variants and Item Attribute, Inventory Dimension, batch-wise and serial-wise valuation, stock reservation (`enable_stock_reservation` defaults to 0), Putaway Rule, Quality Inspection, repost-as-a-background-job (repost runs in the same transaction, 03-posting-engine).

---

## 2. Doctype inventory

Conventions match 01-accounts §2. Perms are ERPNext JSON `permlevel 0` after the role fold in §9 item 7.

### 2.1 Item Group → `item_group`

- **Kind:** tree, org-level. **Naming:** `field:item_group_name`. **Perms:** Item Manager rwcd, Stock User r, Stock Manager r, Sales User r, Purchase User r, Accounts User r.
- **Migration:** `02nn_stock_item_group.sql`. Parent of a new non-root defaults to the root.
- Fields: `item_group_name` ✔, `parent_id`, `is_group` default false, `item_group_defaults` (same columns as Item Default, §2.2), `taxes` (item tax rows: `item_tax_template_id`, `tax_category_id`, `valid_from`, `minimum_net_rate`, `maximum_net_rate`), `path`.
- A group with children, or a group selected on an item, cannot become a leaf.
- **Seed (00-setup A5):** `All Item Groups` (group) → `Products`, `Raw Material`, `Services`, `Sub Assemblies`, `Consumable`.

### 2.2 Item → `item`

- **Kind:** master, org-level (company defaults live on the child). **Naming:** `item_naming_by` (C4 = `Item Code`): the name is the user-entered `item_code`, unique per org. `Naming Series` uses `STO-ITEM-.YYYY.-`. **Title:** `item_name`. **Perms:** Item Manager rwcd. Stock Manager, Stock User, Sales User, Purchase User, Accounts User and Manufacturing User have read. Maintenance User is not seeded.
- **Migration:** `02nn_stock_item.sql`.

| fieldname | column | req | default | notes |
|---|---|---|---|---|
| item_code | text | ✔ | | unique per org |
| item_name | text | | | defaults to `item_code` when blank |
| item_group | item_group_id | ✔ | | must be a leaf |
| stock_uom | uom_id | ✔ | `stock_settings.stock_uom` (`Nos`) | cannot change once an SLE exists |
| description | text | | | HTML, sanitized |
| is_stock_item | boolean | | true | false skips the ledger |
| is_sales_item | boolean | | true | selling docs reject a false row |
| is_purchase_item | boolean | | true | buying docs reject a false row |
| disabled | boolean | | false | |
| brand | brand_id | | | |
| valuation_method | text | | null | null means the company method (`FIFO`). `FIFO\|Moving Average`. `LIFO` and `Standard Cost` are rejected (§9) |
| valuation_rate | numeric | | | opening hint; the ledger overwrites it |
| standard_rate | numeric | | | |
| last_purchase_rate | numeric | | | read-only, set from purchase receipts and invoices |
| weight_per_unit, weight_uom | | | | |
| has_batch_no | boolean | | false | cannot turn off once a batch exists |
| create_new_batch | boolean | | false | inward posts create the batch id |
| batch_number_series | text | | | |
| has_expiry_date | boolean | | false | |
| has_serial_no | boolean | | false | cannot turn off once a serial exists |
| serial_no_series | text | | | |
| end_of_life | date | | `2099-12-31` | transactions after this date are refused |
| default_material_request_type | text | | `Purchase` | |
| min_order_qty | numeric | | 0 | 03-buying §3.6 |
| safety_stock | numeric | | | reorder |
| lead_time_days | int | | | |
| max_discount | numeric | | | 02-selling §3.7 |
| grant_commission | boolean | | true | sales team |
| over_delivery_receipt_allowance | numeric | | | overrides the stock setting for this item |
| over_billing_allowance | numeric | | | overrides Accounts Settings |
| allow_negative_stock | boolean | | false | this item may go negative even when the setting is off |
| delivered_by_supplier | boolean | | false | default for new sales-order rows |
| is_fixed_asset | boolean | | false | P10; asset category required when on |
| include_item_in_manufacturing | boolean | | true | P8 |
| shelf_life_in_days | int | | | batch expiry = manufacturing date + days |
| uoms | `uom_conversion_detail` | | | one row per alternate UOM, `conversion_factor` to stock UOM; the stock UOM row is always 1 |
| reorder_levels | `item_reorder` | | | §3.8 |
| supplier_items | `item_supplier` | | | `supplier_id`, `supplier_part_no` |
| barcodes | `item_barcode` | | | `barcode` unique per org |
| item_defaults | `item_default` | | | one row per company |
| taxes | `item_tax` | | | same shape as the group |

`item_default` columns we keep, per company: `default_warehouse`, `default_price_list`, `income_account`, `expense_account`, `buying_cost_center`, `selling_cost_center`, `default_supplier`. Empty means the company default (inventory account, COGS, expense, cost center, Stores). Deferred-revenue accounts, provisional accounts and variance accounts are omitted.

- **Validate:** leaf item group; stock UOM enabled; conversion factor 1 for the stock UOM; a stock item needs a valuation method resolvable to FIFO or Moving Average; serial and batch cannot both be turned off after stock exists; `end_of_life` is not before today on a new item. Variant fields (`has_variants`, `variant_of`, attributes) are hidden and a save with `has_variants` throws (§9).
- **Delete:** blocked when any SLE, serial or batch points at the item.

### 2.3 UOM → `uom`

- **Naming:** `field:uom_name`. **Perms:** Item Manager rwcd; Stock Manager, Stock User, Sales User and Sales Manager read. System Manager also reads (the JSON omits that role and lists Desk User select, which is not seeded). UOM Category uses the same roles. UOM Conversion Factor grants System Manager rwcd, as in its JSON, plus those same roles.
- Fields: `uom_name` ✔ unique, `must_be_whole_number` default false, `enabled` default true, `symbol`, `common_code`, `description`, `category`.
- **Seed (00-setup A19):** the curated subset (Nos, Unit, Box, Kg, Gram, Litre, Meter, Hour, Day, Set, Pair, Dozen, and the rest of that list) plus their conversions. "Import all UOMs" copies the global template. `Nos` has `must_be_whole_number = 1`.
- `uom_conversion_factor` (org-level, from the template) is the default factor when an item has no row for that pair. An item row wins.

### 2.4 Brand → `brand`

- **Naming:** `field:brand`. **Perms:** Item Manager rwcd, Stock User r, Sales User r, Purchase User r, Accounts User r.
- Fields: `brand` ✔ unique, `description`, `brand_defaults` (same company default columns as the item, used when the item default is empty).

### 2.5 Warehouse → `warehouse`

- **Kind:** tree, company-scoped. **Naming:** `"<warehouse_name> - <ABBR>"` (`warehouse.py`). **Perms:** Item Manager rwcd. Stock User, Stock Manager, Sales User, Purchase User, Accounts User and Manufacturing User have read. Delivery roles are not seeded; Stock User already has read.
- **Migration:** `02nn_stock_warehouse.sql`.
- Fields: `warehouse_name` ✔, `is_group` default false, `company_id` ✔, `parent_id`, `account_id` (stock ledger account; empty uses `companies.default_inventory_account_id`), `warehouse_type_id`, `is_rejected_warehouse` default false, `disabled` default false, address lines, `path`.
- A group with children or with SLE rows cannot become a leaf. A warehouse with SLE cannot be deleted or moved to another company. The account, when set, must be a Stock-type ledger of the same company.
- **Warehouse Type:** `warehouse_type` master, seeded with `Transit` (00-setup A16).
- **Seed (00-setup B5):** `All Warehouses` (group) → `Stores`, `Work In Progress`, `Finished Goods`, `Goods In Transit` (`warehouse_type = Transit`). `companies.default_warehouse_id = Stores`. Goods In Transit is not the company's `default_in_transit_warehouse` (ERPNext leaves that null).

### 2.6 Price List and Item Price

- **`price_list`:** naming `field:price_list_name`. Fields: `price_list_name` ✔, `currency` ✔, `enabled` default true, `buying` default false, `selling` default false, `price_not_uom_dependent` default false. At least one of buying or selling. **Perms:** Sales Manager rwcd and Purchase Manager rwcd (JSON says Sales Master Manager and Purchase Master Manager — folded). Sales User and Purchase User read.
- **Seed (00-setup C1):** `Standard Selling` (selling, company currency), `Standard Buying` (buying, company currency).
- **`item_price`:** `item_code` ✔, `uom` ✔ (item stock UOM), `price_list` ✔, `price_list_rate` ✔, `valid_from` default today, `valid_upto`, `customer_id` or `supplier_id` (a party-specific price beats the list price), `batch_id`, `packing_unit` default 0, `lead_time_days`. Currency is the price list's. Unique on `(item, price_list, uom, customer, supplier, valid_from, batch)` per org. **Perms:** Sales Manager and Purchase Manager rwcd.
- `app.get_item_details` (§3.1) reads these rows. When `auto_insert_price_list_rate_if_missing` is on (C4 sets it), saving a selling or buying document inserts an Item Price at the row rate if none exists (`update_price_list_based_on = Rate`).

### 2.7 Stock Entry Type → `stock_entry_type`

- **Naming:** the purpose name, set by the seed. Fields: `name`, `purpose` (same as the name), `is_standard`, `add_to_transit` default false.
- **Seed (00-setup A6):** Material Issue, Material Receipt, Material Transfer, Manufacture, Repack, Material Transfer for Manufacture, Material Consumption for Manufacture, Send to Subcontractor. ERPNext's extra types (Disassemble, Receive from Customer, Return Raw Material to Customer, Subcontracting Delivery, Subcontracting Return, Batch Split) stay out, as A6 already says.

### 2.8 Stock Settings → `stock_settings`

Single, one row per org. A4 seeds JSON defaults; C4 applies the wizard overrides. **Perms:** Stock Manager rwc, Sales User r.

| field | JSON default | After C4 | Effect |
|---|---|---|---|
| item_naming_by | `Item Code` | `Item Code` | §2.2 |
| stock_uom | null | `Nos` | default on new items |
| valuation_method | null | `FIFO` | company fallback when the item and the company row are null; company row is already FIFO (B2) |
| allow_negative_stock | 0 | 0 | §3.2 |
| auto_indent | 0 | **1** | daily reorder (§3.8) |
| auto_insert_price_list_rate_if_missing | 0 | **1** | §2.6 |
| update_price_list_based_on | `Rate` | `Rate` | the inserted price uses the row rate |
| over_delivery_receipt_allowance | null | null | percent; 0 means no over-delivery. Item row overrides |
| mr_qty_allowance | null | null | extra fraction when ordering a material request |
| over_picking_allowance | null | null | Pick List (§2.13) |
| role_allowed_to_over_deliver_receive | null | null | that role may pass the allowance |
| stock_frozen_upto, stock_frozen_upto_days | null | null | SLE on or before the freeze date throws unless the user has `stock_auth_role` |
| enable_stock_reservation | 0 | 0 | reservation entries are not built |
| auto_create_serial_and_batch_bundle_for_outward | 1 | 1 | §3.5 |
| pick_serial_and_batch_based_on | `FIFO` | `FIFO` | outward auto-pick |
| use_serial_batch_fields | 1 | 1 | serial and batch sit on the item row when there is one batch; a bundle is used for many |
| allow_existing_serial_no | 1 | 1 | an inward row may reuse a serial that is not in stock |
| do_not_use_batchwise_valuation | 0 | 0 | we still value at item + warehouse (§9) |
| allow_to_edit_stock_uom_qty_for_sales / `_purchase` / `_stock_entry` | 0 | 0 | `stock_qty` stays `qty × conversion_factor` |
| validate_material_transfer_warehouses | 0 | 0 | when 1, a transfer's source and target must both be set on the header |
| show_barcode_field | 1 | 1 | |
| clean_description_html | 1 | 1 | description is sanitized |

`set_qty_in_transactions_based_on_serial_no_input = 1` is the C4 value: when the user types serials, qty becomes the serial count.

Quality-inspection settings stay at their JSON defaults and the fields are hidden. `action_if_quality_inspection_is_not_submitted` default `Stop` never runs because inspection is not built.

### 2.9 Stock Ledger Entry → `stock_ledger_entry`

Append-only. Written only by `app.make_stock_ledger_entries`. Cancel inserts a reversing row and sets `is_cancelled` on both (03-posting-engine). No update of qty or rate in place.

Columns: `item_id`, `warehouse_id`, `posting_datetime`, `voucher_type`, `voucher_id`, `voucher_detail_id`, `actual_qty` (signed), `incoming_rate`, `outgoing_rate`, `qty_after_transaction`, `valuation_rate`, `stock_value`, `stock_value_difference`, `stock_queue` (jsonb, FIFO buckets `[qty, rate]`), `serial_and_batch_bundle_id`, `batch_id`, `is_cancelled`, `fiscal_year_id`, `company_id`. Unique order is `(item, warehouse, posting_datetime, id)`.

### 2.10 Bin → `bin`

One row per `(item, warehouse)`, created on the first SLE or the first open order. Recomputed, not edited.

| column | source |
|---|---|
| actual_qty, valuation_rate, stock_value | latest non-cancelled SLE |
| ordered_qty | submitted purchase-order qty not yet received |
| indented_qty | submitted material-request qty not yet ordered (Purchase, Material Transfer, Material Issue) |
| reserved_qty | 0 while reservation is off |
| planned_qty, reserved_qty_for_production | P8 work orders; 0 until then |
| projected_qty | `actual_qty + ordered_qty + indented_qty + planned_qty − reserved_qty − reserved_qty_for_production − reserved_qty_for_sub_contract − reserved_qty_for_production_plan` (`bin.py`) |

### 2.11 Stock Entry → `stock_entry` + `stock_entry_detail`

- **Naming:** `MAT-STE-.YYYY.-`. **Title:** the stock entry type. **Perms:** Stock User rwcsxd, Stock Manager rwcsxd, Manufacturing User rwcsxd, Manufacturing Manager rwcsxd.
- **Migration:** `04nn_stock_stock_entry.sql`.
- Header: `stock_entry_type` ✔, `company` ✔, `posting_date` default today, `posting_time` default now, `set_posting_time`, `from_warehouse`, `to_warehouse`, `add_to_transit` (fetched from the type, default false), `total_outgoing_value`, `total_incoming_value`, `value_difference`, `additional_costs` (amount + account, distributed onto incoming rows), `is_opening` (`No|Yes`), `remarks`, `project`, `cost_center`, `bom_no`, `fg_completed_qty`, `use_multi_level_bom` default true, `work_order`. Manufacture fields are accepted and the Manufacture purpose is specified in §4; the BOM explosion that fills the rows is P8. Until then the user types the rows.
- Detail ✔: `item_code` ✔, `qty` ✔, `uom` ✔, `conversion_factor` ✔, `transfer_qty` (`qty × factor`), `s_warehouse`, `t_warehouse`, `basic_rate`, `basic_amount`, `additional_cost`, `valuation_rate`, `amount`, `expense_account`, `cost_center`, `allow_zero_valuation_rate`, `material_request`, `material_request_item`, `serial_and_batch_bundle`, `batch_no`, `serial_no`, `use_serial_batch_fields`, `is_finished_item`.
- **Warehouses by purpose:** Material Receipt needs `t_warehouse` only. Material Issue needs `s_warehouse` only. Material Transfer and Material Transfer for Manufacture need both, and they must differ. Repack and Manufacture need a source on outgoing rows and a target on incoming rows. Send to Subcontractor and Material Consumption for Manufacture are accepted as transfers onto the WIP or supplier warehouse; the subcontracting documents that create them are P8.
- **Rates:** an incoming row with no rate uses `valuation_rate` of the item, then `last_purchase_rate`, then `standard_rate`. A zero rate throws unless `allow_zero_valuation_rate`. An outgoing row's rate is ignored; the ledger sets it (§3.2).
- **Transit:** `add_to_transit` on a Material Transfer receives into the transit warehouse (`warehouse_type = Transit`, else `Goods In Transit`). A second transfer with `outgoing_stock_entry` pointing at the first moves it out of transit. The first entry stays open until the second is submitted (`per` transferred on the row).
- **Submit:** SLE + perpetual GL (§4), material-request `ordered_qty` for Issue and Transfer, `app.update_bin_qty`. **Cancel:** reversing SLE and GL. A transit entry that has been received further cannot be cancelled first.

### 2.12 Stock Reconciliation → `stock_reconciliation`

- **Naming:** `MAT-RECO-.YYYY.-`. **Perms:** Stock Manager rwcsxd only.
- **Migration:** `04nn_stock_stock_reconciliation.sql`.
- Header: `company` ✔, `purpose` ✔ (`Opening Stock|Stock Reconciliation|Adjustment Entry`), `posting_date` ✔, `posting_time` ✔, `expense_account` (Opening Stock → Temporary Opening; otherwise Stock Adjustment), `cost_center`, `difference_amount`, `set_warehouse`.
- Items ✔: `item_code` ✔, `warehouse` ✔, `qty` (the new on-hand qty for Opening Stock and Stock Reconciliation), `valuation_rate`, `current_qty` and `current_valuation_rate` and `current_amount` filled on save from the bin, `quantity_difference`, `amount_difference`, `batch_no`, `serial_and_batch_bundle`, `allow_zero_valuation_rate`.
- **Opening Stock** posts the whole qty inward. **Stock Reconciliation** posts `qty − current_qty`. **Adjustment Entry** posts a value-only difference: qty stays, `valuation_rate` is the new rate (`is_adjustment_entry`). Serial and batch items must list the serials or the batch; a qty change without them throws.
- Opening Stock is the stock opening against Temporary Opening (01-accounts §3.13). It is not a substitute for an opening journal on the GL of non-stock accounts.

### 2.13 Serial, Batch, Pick List, Packing Slip, Landed Cost

- **Batch** (`batch`): `batch_id` ✔, `item` ✔, `manufacturing_date`, `expiry_date`, `batch_qty` (sum of SLE for that batch, display only), `disabled`, `supplier`. Naming: the id the user or the series produces. **Perms:** Stock User rwcd, Item Manager rwcd. A batch past `expiry_date` is not picked for outward auto-selection. `set_zero_rate_for_expired_batch` (Selling Settings, default 0) is read by the delivery note.
- **Serial No** (`serial_no`): `serial_no` ✔, `item_code` ✔, `company` ✔, `warehouse` read-only (the warehouse of the latest inward that is not yet outward), `batch_no`, `purchase_rate`, `customer` (set by the delivery note), `warranty_expiry_date`. **Perms:** Item Manager rwcd, Stock Manager rwcd, Stock User rwc, Purchase User rwcd, Sales User rwcd. A serial that is already in a warehouse cannot be received again unless `allow_existing_serial_no` and it is currently out of stock.
- **Serial and Batch Bundle** (`serial_and_batch_bundle`): submittable, naming `SABB-.########` unless the settings say to use the series. `item_code` ✔, `warehouse`, `voucher_type` ✔, `voucher_id`, `type_of_transaction` (`Inward|Outward`) ✔, `posting_datetime`, child `serial_and_batch_entry` (`serial_no_id`, `batch_id`, `qty`, `incoming_rate`). Qty on the parent equals the sum of the entries. Created by the voucher save, not as a standalone document the user hunts for. **Perms:** Stock User and Stock Manager rwcsxd; Purchase User and Manufacturing User the same.
- **Pick List** (P5): submittable, naming `STO-PICK-.YYYY.-`. **Perms:** Stock Manager rwcsxd, Stock User rwcsxd, Manufacturing Manager rwcsxd, Manufacturing User rwcsxd. `purpose` is `Material Transfer for Manufacture` (the JSON default), `Material Transfer`, or `Delivery`. Delivery rows point at a sales-order item. Each row has warehouse, `qty`, `picked_qty`, and a serial/batch bundle. Submit does not post SLE; a Stock Entry (transfer purposes) or a Delivery Note (Delivery) consumes `picked_qty`. 02-selling leaves sales-order `per_picked` at 0 until this doctype exists; building it writes that column. Status from `status_map`: Draft, Open (submitted), Partially Transferred, Completed, Partly Delivered, Cancelled. Over-pick beyond `over_picking_allowance` throws. Stock reservation is not required.
- **Packing Slip** (P5): submittable. Packages delivery-note items into `packing_slip_item` rows (`item_code`, `qty`, `dn_detail`). The sum per item cannot exceed the note. No ledger.
- **Landed Cost Voucher** (P6): submittable, naming `MAT-LCV-.YYYY.-`. **Perms:** Stock Manager rwcsxd. Header: `company`, `posting_date`, `distribute_charges_based_on` ✔ (`Qty|Amount|Distribute Manually`). Children: `purchase_receipts` (the receipt) and `taxes` (description, account, amount). Submit distributes the amount onto the receipt items' `landed_cost_voucher_amount` and reposts those SLE rows from the receipt's posting time, which moves the extra value into stock (Dr Stock / Cr the charge account). A receipt that is already fully billed can still take a landed cost; the difference stays in stock value. Cancel reverses it.

### 2.14 Material Request

Specified for every stock purpose. The Purchase path's create-menu is 03-buying §2.9. **Naming:** `MAT-MR-.YYYY.-`. **Perms:** Purchase Manager rwcsxd, Stock Manager rwcsxd, Stock User rwcsxd, Purchase User rwcsxd, Manufacturing Manager r.

`material_request_type`: `Purchase`, `Material Transfer`, `Material Issue`, `Manufacture`, `Customer Provided`. `Subcontracting` is rejected until P8.

Items: `item_code` ✔, `qty` ✔, `uom`, `stock_qty`, `schedule_date` ✔, `warehouse` ✔, `from_warehouse` (transfer), `ordered_qty`, `received_qty`, `rate`, `amount`, `project`, `cost_center`.

Status (03-posting-engine, `status_map`): Draft, Pending, Stopped, Partially Ordered, Ordered (Purchase and Manufacture at `per_ordered = 100`), Transferred (Material Transfer at 100), Issued (Material Issue at 100), Partially Received, Received, Cancelled. Stop is an action. A stopped request is not ordered.

Transfer and Issue submit does not move stock. The Stock Entry mapped from the request does, and it updates `ordered_qty` (the status updater's name for the fulfilled qty on a request).

---

## 3. How stock moves

### 3.1 Item details

`app.get_item_details(args)` is what Selling and Buying call when a row's item, qty, UOM or warehouse changes. It returns `item_name`, `description`, `stock_uom`, `conversion_factor`, `stock_qty`, `price_list_rate`, `rate` (price list, then last purchase rate on buying docs when Buying Settings allow it), `income_account` or `expense_account`, `cost_center`, `warehouse` (item default, else company default), `actual_qty`, `projected_qty`, `has_serial_no`, `has_batch_no`, `item_tax_template` (the item or group tax row valid for the date, net rate and tax category), and `weight`. Barcode scan resolves to `item_code` through `item_barcode`.

### 3.2 Ledger

`app.make_stock_ledger_entries(voucher_type, voucher_id)` follows 03-posting-engine, in order: lock the item and warehouse, find the previous SLE, value at FIFO or moving average, write the row, reject negative qty unless the setting or the item allows it, repost every later SLE for that pair in the same transaction, then `app.update_bin_qty`.

FIFO buckets live in `stock_queue`. An inward appends. An outward consumes from the front. Moving average recomputes the rate on inward and keeps it on outward. The outward `outgoing_rate` is written back onto the voucher row (`incoming_rate` on a delivery note or sales invoice) so the GL uses the same number.

Back-dated entries are allowed. `stock_frozen_upto` blocks them unless the user has `stock_auth_role`. There is no separate Repost Item Valuation document.

### 3.3 Perpetual inventory GL

When `companies.enable_perpetual_inventory` is on (the wizard default), every SLE with a non-zero `stock_value_difference` posts GL in the same transaction. The account is the warehouse's `account_id`, else the company inventory account. The other side:

| Voucher | Stock side | Other side |
|---|---|---|
| Purchase Receipt | Dr | Cr Stock Received But Not Billed (03-buying §4) |
| Delivery Note, Sales Invoice `update_stock` | Cr | Dr COGS (`expense_account`, else company COGS) |
| Stock Entry receipt | Dr | Cr the row `expense_account`, else Stock Adjustment. Opening (`is_opening = Yes`) uses Temporary Opening |
| Stock Entry issue | Cr | Dr the row expense account, else Stock Adjustment |
| Stock Entry transfer | Dr target, Cr source | no GL when both warehouses share an account |
| Stock Reconciliation | Dr or Cr the difference | the document expense account (Temporary Opening for Opening Stock, else Stock Adjustment) |
| Landed Cost Voucher | Dr the extra | Cr the charge account |

Company `valuation_method` cannot change once an SLE exists for an item that has no method of its own (`cant_change_valuation_method`, 00-setup). Perpetual inventory cannot be turned off once SLE rows exist.

### 3.4 Material request reorder

`app.reorder_items`, daily (03-posting-engine). For each `item_reorder` row (`warehouse`, `warehouse_group_id` optional, `reorder_level`, `reorder_qty`, `material_request_type` default Purchase): if `actual_qty + indented + ordered − reserved` in that warehouse is below `reorder_level`, and `auto_indent` is on, create one draft Material Request per company and type with `qty = reorder_qty`. An open request for the same item and warehouse suppresses a second one. `reorder_email_notify` stays off; no email.

### 3.5 Serial and batch

On inward, a serialized item needs one serial per stock qty, and a batched item needs a batch. `create_new_batch` makes the batch from `batch_number_series` when the row has none. The bundle's qty must equal the row's stock qty ("Total quantity in Serial and Batch Bundle {0} is {1}, it should be {2}").

On outward, when `auto_create_serial_and_batch_bundle_for_outward` is on and the row has no bundle, the oldest in-stock serials and batches are picked (`pick_serial_and_batch_based_on = FIFO`). Expired batches are skipped. The user can replace the pick before submit.

Valuation ignores the batch and the serial. The rate is the item-warehouse FIFO or moving-average rate. The bundle stores `incoming_rate` so the serial's `purchase_rate` can be shown. This is the deviation already recorded in 03-posting-engine.

---

## 4. Stock entry purposes

| Purpose | SLE | GL | Also updates |
|---|---|---|---|
| Material Receipt | inward at `basic_rate` + additional cost | Dr Stock, Cr expense / Stock Adjustment | — |
| Material Issue | outward at valuation | Dr expense / Stock Adjustment, Cr Stock | Material Request (Issue) fulfilled qty |
| Material Transfer | out of source at valuation, in to target at that rate | Dr target account, Cr source account | Material Request (Transfer); transit warehouse when `add_to_transit` |
| Material Transfer for Manufacture | as transfer, target is the WIP warehouse | as transfer | Work Order `material_transferred_for_manufacturing` (P8) |
| Manufacture | out of WIP for the raw rows, in to FG warehouse at the sum of raw value + additional cost | Dr FG, Cr WIP | Work Order `produced_qty` (P8). Rows are entered by hand until the BOM tool exists |
| Material Consumption for Manufacture | outward from WIP | Dr the row expense account, Cr WIP | Work Order consumed qty (P8) |
| Repack | outward inputs, inward outputs; output value splits by `basic_amount` share | Dr each target, Cr each source | — |
| Send to Subcontractor | outward to the supplier warehouse | as transfer | P8 creates it; the type exists so the seed matches A6 |

`from_warehouse` and `to_warehouse` on the header copy onto empty row warehouses.

---

## 5. Statuses

Material Request: §2.14. Pick List: §2.13. Stock Entry and Stock Reconciliation have no status field beyond docstatus. Delivery Note and Purchase Receipt statuses are 02-selling §5.3 and 03-buying §5.4.

A material request's `per_ordered` is fulfilled qty over requested qty. For Purchase that qty is the purchase order. For Transfer and Issue it is the stock entry. `per_received` on a Purchase request counts purchase-receipt qty.

---

## 6. Settings & defaults

00-setup already lists the seeds this module's migrations must insert: A5 item groups, A6 stock entry types, A16 Transit, A19 UOMs, B5 warehouses, C1 price lists, C4 stock settings. Those steps are specified there and wait on these tables. This doc does not repeat the row lists.

`companies.valuation_method = FIFO` and `enable_perpetual_inventory = true` are company columns (00-setup), not stock settings. Stock settings `valuation_method` is a second fallback and C4 sets it to FIFO as well.

---

## 7. Reports & dashboard

### 7.1 Dashboard

`stock_dashboard/stock/stock.json`.

| Card | Query |
|---|---|
| Total Active Items | Count of items with `disabled = false` |
| Total Warehouses | Count of warehouses with `disabled = false`, this company |
| Total Stock Value | Sum of `bin.stock_value` for warehouses of this company |

| Chart | Width | Query |
|---|---|---|
| Warehouse wise Stock Value | Full | `bin.stock_value` grouped by warehouse, top warehouses |
| Purchase Receipt Trends | Half | receipt `base_net_total` by month |
| Delivery Trends | Half | delivery note `base_net_total` by month |
| Oldest Items | Half | items with SLE, oldest `posting_datetime` still in stock (qty_after > 0) |
| Item Shortage Summary | Half | items whose `projected_qty` is below `safety_stock` or `reorder_level` |

### 7.2 Reports

- **Stock Ledger** (`app.report_stock_ledger`): one row per SLE in the date range. Columns: date, item, item group, warehouse, voucher type, voucher, qty, incoming rate, balance qty, valuation rate, stock value, stock value difference. Filters: company ✔, from/to date ✔, item, warehouse, voucher type. Cancelled rows are excluded.
- **Stock Balance** (`app.report_stock_balance`): opening qty and value, in qty, out qty, balance qty, valuation rate, balance value, per item and warehouse. Opening is the SLE balance before `from_date`. Filters: company ✔, from/to date ✔, item, item group, warehouse, include zero balance (default off).
- **Stock Projected Qty** (`app.report_stock_projected_qty`): actual, ordered, indented, reserved, planned, projected, reorder level, shortage. Filters: company, item, warehouse.
- **Stock Ageing** (`app.report_stock_ageing`): FIFO buckets of remaining qty by age of the inward (`0–30`, `31–60`, `61–90`, `91+`, using `accounts_settings` ranges when set, else 30/60/90). Average age. Filters: company, to date, item, warehouse.
- **Stock Analytics** (`app.report_stock_analytics`): the stock twin of Sales Analytics. `tree_type` Warehouse, Item, Item Group or Brand; value is stock value movement or quantity; range weekly, monthly, quarterly, yearly.

---

## 8. UI notes

- Item form tabs: Details (code, name, group, UOM, stock/sales/purchase flags, brand, description), Inventory (warehouse default, serial, batch, shelf life, reorder, negative stock), Accounting (item defaults: income, expense, cost centers), Purchasing (min order qty, supplier items, lead time), Sales (max discount, grant commission, sales UOM), Tax (item tax rows). Variants, quality, deferred accounting and asset tabs are hidden until their module exists; Asset shows when `is_fixed_asset` is on (P10).
- Warehouse is a tree with balance when the user asks for it (sum of `bin.stock_value` under the node).
- Stock Entry: purpose first, then warehouses, then the item table. Receipt rows show rate; issue and transfer rows show the rate as read-only after save (the preview calls the same valuation function for the current bin, and the server overwrites it).
- Stock Reconciliation: purpose, then a table that fills current qty on item + warehouse selection. Opening Stock labels the expense account "Temporary Opening".
- Lists: item code, name, group, stock qty in the default warehouse (from bin), valuation rate. Stock entry list: type, date, value difference. Status badges on material request and pick list.
- Dashboard: three cards, then the five charts at the widths in §7.1.
- Empty, loading and error states. A company with no opening reconciliation shows an empty stock balance, not an error.

---

## 9. Deviations from ERPNext

1. **Deviation:** valuation is item + warehouse only. `do_not_use_batchwise_valuation` stays 0 in settings, and serial-wise valuation (`use_serial_no_wise_valuation`) is ignored. Batches and serials are tracked on the bundle. **Reason:** 03-posting-engine already records this; batch queues multiply the repost cost and are not required for the default FIFO demonstration.
2. **Deviation:** `LIFO` and `Standard Cost` are rejected on the item and on stock settings. The company check allows FIFO and Moving Average only. **Reason:** PLAN names those two methods; LIFO is not the ERPNext default.
3. **Deviation:** Item variants, Item Attribute and Inventory Dimension are not built. `has_variants` cannot be saved. **Reason:** PLAN §1.
4. **Deviation:** Quality Inspection is not built. Inspection-required flags on the item are hidden, and the stock-settings inspection actions never run. **Reason:** Quality is out of scope.
5. **Deviation:** stock reservation entries are not built. `reserved_qty` stays 0. Pick List still records `picked_qty` without reserving. **Reason:** `enable_stock_reservation` defaults to 0.
6. **Deviation:** a back-dated SLE reposts later rows in the same transaction. There is no Repost Item Valuation queue. **Reason:** 03-posting-engine; one transaction, with the volume caveat already written there.
7. **Deviation:** Sales Master Manager and Purchase Master Manager on Price List and Item Price are folded onto Sales Manager and Purchase Manager. **Reason:** those roles are not seeded (00-setup §2.7).
8. **Not a deviation (recorded for implementers):** Warehouse write is Item Manager, not Stock Manager, because that is the JSON. Stock Manager submits stock entries and reconciliations. `auto_indent` is on only because C4 sets it; the JSON default is off. Rejected quantity on a purchase receipt is not valued unless `set_valuation_rate_for_rejected_materials` (Buying Settings, default off).

---

## 10. Implementation checklist

Migration numbers: P2 `02nn_stock_*`, P4 `04nn_stock_*`, P5 pick list and packing slip with delivery notes, P6 landed cost with purchase receipts. Each item is one migration (RLS, `doctype_meta`, `role_permissions`), one descriptor, a Zod schema, client mutations, list/form, and a test. Ledger behaviour is pgTAP.

### P2 — masters

- [x] `uom`, `uom_category`, `uom_conversion_factor` + A19 — §2.3
- [ ] `item_group` + A5 — §2.1
- [ ] `brand` — §2.4
- [ ] `warehouse`, `warehouse_type` + A16 + B5 — §2.5
- [ ] `item` + defaults, taxes, reorder, suppliers, barcodes, UOM conversions — §2.2
- [ ] `price_list`, `item_price` + C1 — §2.6
- [ ] `stock_entry_type` + A6 — §2.7

### P4 — ledger

- [ ] `stock_settings` form, C4 values — §2.8
- [ ] `stock_ledger_entry`, `bin`, `app.make_stock_ledger_entries`, FIFO and moving average, negative stock, synchronous repost — §2.9, §2.10, §3.2
- [ ] Perpetual GL for receipt, issue, transfer, reconciliation — §3.3, §4
- [ ] `stock_entry` for the A6 purposes — §2.11, §4
- [ ] `stock_reconciliation`, including Opening Stock against Temporary Opening — §2.12
- [ ] `material_request` for Purchase, Transfer, Issue, Customer Provided; Manufacture rows accepted, BOM fill is P8 — §2.14
- [ ] `batch`, `serial_no`, `serial_and_batch_bundle`, auto-pick on outward — §2.13, §3.5
- [ ] `app.get_item_details` — §3.1
- [ ] `app.reorder_items` — §3.4
- [ ] Dashboard and the five reports — §7
- [ ] Company checks `cant_change_valuation_method` and `validate_perpetual_inventory` once SLE exists — §3.3

### P5 / P6 — with the documents that use them

- [ ] Pick List and Packing Slip — §2.13
- [ ] Landed Cost Voucher and the receipt repost — §2.13
