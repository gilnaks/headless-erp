import { defineChildDoctype, defineDoctype } from "../define";

const requestTypes = ["Purchase", "Material Transfer", "Material Issue", "Manufacture", "Customer Provided"] as const;

export const itemUom = defineChildDoctype({
    doctype: "UOM Conversion Detail",
    table: "item_uom",
    fields: {
        uom_id: { type: "Link", label: "UOM", target: "UOM", required: true },
        conversion_factor: { type: "Float", label: "Conversion Factor", required: true },
    },
    columns: ["uom_id", "conversion_factor"],
});

export const itemReorder = defineChildDoctype({
    doctype: "Item Reorder",
    table: "item_reorder",
    fields: {
        warehouse_group_id: { type: "Link", label: "Check in (group) Warehouse", target: "Warehouse" },
        warehouse_id: { type: "Link", label: "Request for Warehouse", target: "Warehouse" },
        warehouse_reorder_level: { type: "Float", label: "Reorder Level", default: 0 },
        warehouse_reorder_qty: { type: "Float", label: "Reorder Qty", default: 0 },
        material_request_type: { type: "Select", label: "Material Request Type", options: requestTypes, default: "Purchase" },
    },
    columns: ["warehouse_id", "warehouse_reorder_level", "warehouse_reorder_qty", "material_request_type", "warehouse_group_id"],
});

export const itemSupplier = defineChildDoctype({
    doctype: "Item Supplier",
    table: "item_supplier",
    fields: {
        supplier_id: { type: "Link", label: "Supplier", target: "Supplier", required: true },
        supplier_part_no: { type: "Data", label: "Supplier Part No" },
    },
    columns: ["supplier_id", "supplier_part_no"],
});

export const itemBarcode = defineChildDoctype({
    doctype: "Item Barcode",
    table: "item_barcode",
    fields: { barcode: { type: "Data", label: "Barcode", required: true } },
    columns: ["barcode"],
});

export const itemDefault = defineChildDoctype({
    doctype: "Item Default",
    table: "item_default",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        default_warehouse_id: { type: "Link", label: "Default Warehouse", target: "Warehouse" },
        default_price_list_id: { type: "Link", label: "Default Price List", target: "Price List" },
        income_account_id: { type: "Link", label: "Income Account", target: "Account" },
        expense_account_id: { type: "Link", label: "Expense Account", target: "Account" },
        buying_cost_center_id: { type: "Link", label: "Buying Cost Center", target: "Cost Center" },
        selling_cost_center_id: { type: "Link", label: "Selling Cost Center", target: "Cost Center" },
        default_supplier_id: { type: "Link", label: "Default Supplier", target: "Supplier" },
    },
    columns: [
        "company_id",
        "default_warehouse_id",
        "default_price_list_id",
        "income_account_id",
        "expense_account_id",
        "buying_cost_center_id",
        "selling_cost_center_id",
        "default_supplier_id",
    ],
});

export const itemTax = defineChildDoctype({
    doctype: "Item Tax",
    table: "item_tax",
    fields: {
        item_tax_template_id: { type: "Link", label: "Item Tax Template", target: "Item Tax Template" },
        tax_category_id: { type: "Link", label: "Tax Category", target: "Tax Category" },
        valid_from: { type: "Date", label: "Valid From" },
        minimum_net_rate: { type: "Currency", label: "Minimum Net Rate" },
        maximum_net_rate: { type: "Currency", label: "Maximum Net Rate" },
    },
    columns: ["item_tax_template_id", "tax_category_id", "valid_from", "minimum_net_rate", "maximum_net_rate"],
});

/** ERPNext Item. The name is the item code. Variants are not built. */
export const item = defineDoctype<"item", "uoms" | "reorder_levels" | "supplier_items" | "barcodes" | "item_defaults" | "taxes">({
    doctype: "Item",
    table: "item",
    module: "stock",
    slug: "item",
    titleField: "item_name",
    fields: {
        item_code: { type: "Data", label: "Item Code", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        item_name: { type: "Data", label: "Item Name" },
        item_group_id: { type: "Link", label: "Item Group", target: "Item Group", required: true },
        stock_uom_id: { type: "Link", label: "Default Unit of Measure", target: "UOM", required: true },
        description: { type: "Text", label: "Description", html: true },
        brand_id: { type: "Link", label: "Brand", target: "Brand" },
        is_stock_item: { type: "Check", label: "Maintain Stock", default: true },
        is_sales_item: { type: "Check", label: "Allow Sales", default: true },
        is_purchase_item: { type: "Check", label: "Allow Purchase", default: true },
        disabled: { type: "Check", label: "Disabled" },
        grant_commission: { type: "Check", label: "Grant Commission", default: true },
        is_fixed_asset: { type: "Check", label: "Is Fixed Asset" },
        include_item_in_manufacturing: { type: "Check", label: "Include Item In Manufacturing", default: true },
        valuation_method: { type: "Select", label: "Valuation Method", options: ["", "FIFO", "Moving Average"] },
        valuation_rate: { type: "Currency", label: "Valuation Rate", readOnly: true },
        standard_rate: { type: "Currency", label: "Standard Selling Rate" },
        last_purchase_rate: { type: "Currency", label: "Last Purchase Rate", readOnly: true },
        end_of_life: { type: "Date", label: "End of Life", default: "2099-12-31" },
        has_batch_no: { type: "Check", label: "Has Batch No" },
        create_new_batch: { type: "Check", label: "Automatically Create New Batch" },
        batch_number_series: { type: "Data", label: "Batch Number Series" },
        has_expiry_date: { type: "Check", label: "Has Expiry Date" },
        has_serial_no: { type: "Check", label: "Has Serial No" },
        serial_no_series: { type: "Data", label: "Serial Number Series" },
        shelf_life_in_days: { type: "Int", label: "Shelf Life in Days" },
        weight_per_unit: { type: "Float", label: "Weight Per Unit" },
        weight_uom_id: { type: "Link", label: "Weight UOM", target: "UOM" },
        allow_negative_stock: { type: "Check", label: "Allow Negative Stock" },
        default_material_request_type: {
            type: "Select",
            label: "Default Material Request Type",
            options: requestTypes,
            default: "Purchase",
        },
        min_order_qty: { type: "Float", label: "Minimum Order Qty", default: 0 },
        safety_stock: { type: "Float", label: "Safety Stock" },
        lead_time_days: { type: "Int", label: "Lead Time Days" },
        over_delivery_receipt_allowance: { type: "Float", label: "Over Delivery/Receipt Allowance" },
        delivered_by_supplier: { type: "Check", label: "Delivered by Supplier" },
        max_discount: { type: "Float", label: "Max Discount" },
        over_billing_allowance: { type: "Float", label: "Over Billing Allowance" },
        uoms: { type: "Table", label: "UOMs", target: "UOM Conversion Detail" },
        reorder_levels: { type: "Table", label: "Reorder", target: "Item Reorder" },
        supplier_items: { type: "Table", label: "Supplier Items", target: "Item Supplier" },
        barcodes: { type: "Table", label: "Barcodes", target: "Item Barcode" },
        item_defaults: { type: "Table", label: "Item Defaults", target: "Item Default" },
        taxes: { type: "Table", label: "Taxes", target: "Item Tax" },
    },
    children: {
        uoms: itemUom,
        reorder_levels: itemReorder,
        supplier_items: itemSupplier,
        barcodes: itemBarcode,
        item_defaults: itemDefault,
        taxes: itemTax,
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["item_code", "name", "item_name", "item_group_id", "stock_uom_id", "brand_id"],
                        [
                            "is_stock_item",
                            "is_sales_item",
                            "is_purchase_item",
                            "disabled",
                            "grant_commission",
                            "is_fixed_asset",
                            "include_item_in_manufacturing",
                        ],
                    ],
                },
                { columns: [["description"]] },
            ],
        },
        {
            label: "Inventory",
            sections: [
                {
                    columns: [
                        ["valuation_method", "valuation_rate", "standard_rate", "last_purchase_rate", "end_of_life"],
                        ["has_batch_no", "create_new_batch", "batch_number_series", "has_expiry_date", "shelf_life_in_days"],
                        ["has_serial_no", "serial_no_series", "weight_per_unit", "weight_uom_id", "allow_negative_stock"],
                    ],
                },
                { label: "UOMs", columns: [["uoms"]] },
                { label: "Reorder", columns: [["reorder_levels"]] },
            ],
        },
        {
            label: "Purchasing",
            sections: [
                {
                    columns: [
                        [
                            "default_material_request_type",
                            "min_order_qty",
                            "safety_stock",
                            "lead_time_days",
                            "over_delivery_receipt_allowance",
                            "delivered_by_supplier",
                        ],
                    ],
                },
                { columns: [["supplier_items"], ["barcodes"]] },
            ],
        },
        {
            label: "Accounting",
            sections: [{ columns: [["max_discount", "over_billing_allowance"]] }, { columns: [["item_defaults"], ["taxes"]] }],
        },
    ],
    listView: {
        columns: ["item_code", "item_name", "item_group_id", "stock_uom_id", "disabled"],
        searchFields: ["item_code", "item_name"],
        defaultSort: { field: "item_code" },
    },
    errorFields: {
        duplicate: "item_code",
        item_group_leaf: "item_group_id",
        item_uom: "stock_uom_id",
        item_end_of_life: "end_of_life",
        item_uom_factor: "uoms",
        item_serial: "has_serial_no",
        item_series: "serial_no_series",
        item_tax_duplicate: "taxes",
        item_tax_range: "taxes",
        item_reorder: "reorder_levels",
        item_default_company: "item_defaults",
    },
});
