import { defineDoctype } from "../define";

/**
 * Selling Settings (ERPNext selling_settings.json). One row per organization, seeded by
 * supabase/migrations/0507_selling_settings.sql with the A20 defaults. Proforma, UTM,
 * commission, reservation, blanket orders, the bulk delivery-note cutoff, and overproduced
 * delivery stay at their defaults and are not on this form. Submit does not read the row yet.
 */
export const sellingSettings = defineDoctype({
    doctype: "Selling Settings",
    table: "selling_settings",
    module: "selling",
    slug: "settings",
    single: true,
    fields: {
        cust_master_name: {
            type: "Select",
            label: "Customer Naming By",
            options: ["Customer Name", "Naming Series", "Auto Name"],
            required: true,
            default: "Customer Name",
        },
        customer_group_id: { type: "Link", label: "Default Customer Group", target: "Customer Group" },
        territory_id: { type: "Link", label: "Default Territory", target: "Territory" },
        selling_price_list_id: { type: "Link", label: "Default Price List", target: "Price List" },
        fallback_to_default_price_list: {
            type: "Check",
            label: "Use prices from Default Price List as fallback",
        },
        editable_price_list_rate: { type: "Check", label: "Allow editing Price List rate in transactions" },
        maintain_same_sales_rate: { type: "Check", label: "Maintain same rate throughout sales cycle" },
        maintain_same_rate_action: {
            type: "Select",
            label: "Action if same rate is not maintained throughout sales cycle",
            options: ["Stop", "Warn"],
            required: true,
            default: "Stop",
            dependsOn: (values) => values.maintain_same_sales_rate === true,
        },
        role_to_override_stop_action: {
            type: "Link",
            label: "Role allowed to override stop action",
            target: "Role",
            dependsOn: (values) => values.maintain_same_sales_rate === true && values.maintain_same_rate_action === "Stop",
        },
        validate_selling_price: {
            type: "Check",
            label: "Validate selling price for Item against purchase or valuation rate",
        },
        editable_bundle_item_rates: {
            type: "Check",
            label: "Calculate Product Bundle price based on child Item's rates",
        },
        allow_negative_rates_for_items: { type: "Check", label: "Allow negative rates for Items" },
        enable_discount_accounting: { type: "Check", label: "Enable discount accounting for selling" },
        so_required: {
            type: "Select",
            label: "Is Sales Order required to create Sales Invoice/Delivery Note?",
            options: ["No", "Yes"],
            required: true,
            default: "No",
        },
        dn_required: {
            type: "Select",
            label: "Is Delivery Note required to create Sales Invoice?",
            options: ["No", "Yes"],
            required: true,
            default: "No",
        },
        skip_delivery_note_for_service_items: {
            type: "Check",
            label: "Skip Delivery Note Creation for Service Items",
        },
        sales_update_frequency: {
            type: "Select",
            label: "How often should sales data be updated in Company/Project?",
            options: ["Monthly", "Each Transaction", "Daily"],
            required: true,
            default: "Each Transaction",
        },
        allow_multiple_items: {
            type: "Check",
            label: "Allow same Item to be added multiple times in a transaction",
            default: true,
        },
        allow_against_multiple_purchase_orders: {
            type: "Check",
            label: "Allow multiple Sales Orders against a customer's Purchase Order",
        },
        hide_tax_id: { type: "Check", label: "Hide Customer's Tax ID from sales transactions" },
        allow_sales_order_creation_for_expired_quotation: {
            type: "Check",
            label: "Allow Sales Order creation for expired Quotation",
        },
        set_zero_rate_for_expired_batch: {
            type: "Check",
            label: "Set incoming rate as zero for expired Batch",
        },
        allow_zero_qty_in_quotation: { type: "Check", label: "Allow Quotation with zero quantity" },
        allow_zero_qty_in_sales_order: { type: "Check", label: "Allow Sales Order with zero quantity" },
    },
    tabs: [
        {
            label: "Customer Defaults",
            sections: [
                {
                    columns: [["cust_master_name", "customer_group_id", "territory_id"]],
                },
            ],
        },
        {
            label: "Pricing",
            sections: [
                {
                    columns: [
                        [
                            "selling_price_list_id",
                            "fallback_to_default_price_list",
                            "editable_price_list_rate",
                            "maintain_same_sales_rate",
                            "maintain_same_rate_action",
                            "role_to_override_stop_action",
                        ],
                        [
                            "validate_selling_price",
                            "editable_bundle_item_rates",
                            "allow_negative_rates_for_items",
                            "enable_discount_accounting",
                        ],
                    ],
                },
            ],
        },
        {
            label: "Transaction",
            sections: [
                {
                    label: "Transaction Settings",
                    columns: [
                        ["so_required", "dn_required", "skip_delivery_note_for_service_items", "sales_update_frequency"],
                        [
                            "allow_multiple_items",
                            "allow_against_multiple_purchase_orders",
                            "hide_tax_id",
                            "allow_sales_order_creation_for_expired_quotation",
                            "set_zero_rate_for_expired_batch",
                        ],
                    ],
                },
                {
                    label: "Zero-Quantity Line Items",
                    columns: [["allow_zero_qty_in_quotation", "allow_zero_qty_in_sales_order"]],
                },
            ],
        },
    ],
    errorFields: { selling_price_list: "selling_price_list_id" },
});
