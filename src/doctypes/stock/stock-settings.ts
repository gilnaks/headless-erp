import { defineDoctype } from "../define";

/**
 * Stock Settings (ERPNext stock_settings.json). One row per organization, seeded by
 * supabase/migrations/0400_stock_settings.sql with the C4 defaults. Quality-inspection
 * columns stay at their JSON defaults and are not on this form.
 */
export const stockSettings = defineDoctype({
    doctype: "Stock Settings",
    table: "stock_settings",
    module: "stock",
    slug: "settings",
    single: true,
    fields: {
        item_naming_by: {
            type: "Select",
            label: "Item Naming By",
            options: ["Item Code", "Naming Series"],
            required: true,
            default: "Item Code",
        },
        stock_uom_id: { type: "Link", label: "Default Stock UOM", target: "UOM" },
        valuation_method: {
            type: "Select",
            label: "Default Valuation Method",
            options: ["FIFO", "Moving Average", "LIFO", "Standard Cost"],
            required: true,
            default: "FIFO",
        },
        allow_negative_stock: { type: "Check", label: "Allow negative stock" },
        auto_indent: { type: "Check", label: "Raise Material Request when stock reaches re-order level", default: true },
        auto_insert_price_list_rate_if_missing: {
            type: "Check",
            label: "Auto insert Item Price if missing",
            default: true,
        },
        update_price_list_based_on: {
            type: "Select",
            label: "Update Price List based on",
            options: ["Rate", "Price List Rate"],
            required: true,
            default: "Rate",
            dependsOn: (values) => values.auto_insert_price_list_rate_if_missing === true,
        },
        over_delivery_receipt_allowance: { type: "Percent", label: "Over Delivery/Receipt Allowance (%)" },
        mr_qty_allowance: { type: "Percent", label: "Over Transfer Allowance (%)" },
        over_picking_allowance: { type: "Percent", label: "Over Picking Allowance (%)" },
        role_allowed_to_over_deliver_receive: {
            type: "Link",
            label: "Role Allowed to Over Deliver/Receive",
            target: "Role",
        },
        stock_frozen_upto: { type: "Date", label: "Stock frozen up to" },
        stock_frozen_upto_days: { type: "Int", label: "Freeze stocks older than (days)" },
        stock_auth_role: {
            type: "Link",
            label: "Role allowed to edit frozen stock",
            target: "Role",
            dependsOn: (values) => Boolean(values.stock_frozen_upto) || Boolean(values.stock_frozen_upto_days),
        },
        enable_stock_reservation: { type: "Check", label: "Enable stock reservation" },
        auto_create_serial_and_batch_bundle_for_outward: {
            type: "Check",
            label: "Auto create Serial and Batch Bundle for outward",
            default: true,
        },
        pick_serial_and_batch_based_on: {
            type: "Select",
            label: "Pick Serial / Batch Based On",
            options: ["FIFO", "LIFO", "Expiry"],
            required: true,
            default: "FIFO",
            dependsOn: (values) => values.auto_create_serial_and_batch_bundle_for_outward === true,
        },
        use_serial_batch_fields: { type: "Check", label: "Use Serial / Batch fields", default: true },
        allow_existing_serial_no: {
            type: "Check",
            label: "Allow existing Serial No to be Manufactured/Received again",
            default: true,
        },
        do_not_use_batchwise_valuation: { type: "Check", label: "Do not use Batch-wise Valuation" },
        allow_to_edit_stock_uom_qty_for_sales: { type: "Check", label: "Allow to edit stock UOM qty for Sales documents" },
        allow_to_edit_stock_uom_qty_for_purchase: { type: "Check", label: "Allow to edit stock UOM qty for Purchase documents" },
        allow_to_edit_stock_uom_qty_for_stock_entry: { type: "Check", label: "Allow to edit stock UOM qty for Stock Entry" },
        validate_material_transfer_warehouses: { type: "Check", label: "Validate Material Transfer warehouses" },
        show_barcode_field: { type: "Check", label: "Show barcode field in stock transactions", default: true },
        clean_description_html: { type: "Check", label: "Convert Item description to clean HTML in transactions", default: true },
        set_qty_in_transactions_based_on_serial_no_input: {
            type: "Check",
            label: "Set Qty in Transactions based on Serial No Input",
            default: true,
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    label: "Defaults",
                    columns: [["item_naming_by", "stock_uom_id", "valuation_method", "show_barcode_field", "clean_description_html"]],
                },
                {
                    label: "Stock Planning",
                    columns: [["allow_negative_stock", "auto_indent"]],
                },
                {
                    label: "Price List",
                    columns: [["auto_insert_price_list_rate_if_missing", "update_price_list_based_on"]],
                },
                {
                    label: "Allowances",
                    columns: [
                        [
                            "over_delivery_receipt_allowance",
                            "mr_qty_allowance",
                            "over_picking_allowance",
                            "role_allowed_to_over_deliver_receive",
                        ],
                    ],
                },
                {
                    label: "Stock Frozen",
                    columns: [["stock_frozen_upto", "stock_frozen_upto_days", "stock_auth_role"]],
                },
                {
                    label: "Serial and Batch",
                    columns: [
                        [
                            "enable_stock_reservation",
                            "auto_create_serial_and_batch_bundle_for_outward",
                            "pick_serial_and_batch_based_on",
                            "use_serial_batch_fields",
                            "allow_existing_serial_no",
                            "do_not_use_batchwise_valuation",
                            "set_qty_in_transactions_based_on_serial_no_input",
                        ],
                    ],
                },
                {
                    label: "Stock UOM Qty",
                    columns: [
                        [
                            "allow_to_edit_stock_uom_qty_for_sales",
                            "allow_to_edit_stock_uom_qty_for_purchase",
                            "allow_to_edit_stock_uom_qty_for_stock_entry",
                            "validate_material_transfer_warehouses",
                        ],
                    ],
                },
            ],
        },
    ],
});
