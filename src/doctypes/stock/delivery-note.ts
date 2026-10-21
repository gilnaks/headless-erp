import { fillDeliveryNoteItem } from "@/lib/stock/item-details";
import { defineChildDoctype, defineDoctype, type FieldValues } from "../define";

function today(): string {
    const date = new Date();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

function statusOf(values: FieldValues): string {
    return typeof values.status === "string" ? values.status : "";
}

export const deliveryNoteItem = defineChildDoctype({
    doctype: "Delivery Note Item",
    table: "delivery_note_item",
    fields: {
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        item_name: { type: "Data", label: "Item Name", readOnly: true },
        qty: { type: "Float", label: "Qty", required: true },
        uom_id: { type: "Link", label: "UOM", target: "UOM" },
        stock_uom_id: { type: "Link", label: "Stock UOM", target: "UOM", readOnly: true },
        conversion_factor: { type: "Float", label: "UOM Conversion Factor", readOnly: true },
        stock_qty: { type: "Float", label: "Qty in Stock UOM", readOnly: true },
        price_list_rate: { type: "Currency", label: "Price List Rate" },
        discount_percentage: { type: "Percent", label: "Discount (%)" },
        rate: { type: "Currency", label: "Rate" },
        amount: { type: "Currency", label: "Amount", readOnly: true },
        net_rate: { type: "Currency", label: "Net Rate", readOnly: true },
        net_amount: { type: "Currency", label: "Net Amount", readOnly: true },
        warehouse_id: { type: "Link", label: "Warehouse", target: "Warehouse" },
        target_warehouse_id: { type: "Link", label: "Target Warehouse", target: "Warehouse" },
        expense_account_id: { type: "Link", label: "Expense Account", target: "Account" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center", readOnly: true },
        against_sales_order_id: { type: "Link", label: "Against Sales Order", target: "Sales Order" },
        so_detail_id: { type: "Link", label: "Sales Order Item", target: "Sales Order Item" },
    },
    columns: [
        "item_id",
        "qty",
        "uom_id",
        "rate",
        "amount",
        "warehouse_id",
        "target_warehouse_id",
        "expense_account_id",
        "against_sales_order_id",
    ],
});

export const packedItem = defineChildDoctype({
    doctype: "Packed Item",
    table: "packed_item",
    fields: {
        parent_item_id: { type: "Link", label: "Parent Item", target: "Item", readOnly: true },
        item_id: { type: "Link", label: "Item", target: "Item", readOnly: true },
        item_name: { type: "Data", label: "Item Name", readOnly: true },
        qty: { type: "Float", label: "Qty", readOnly: true },
        uom_id: { type: "Link", label: "UOM", target: "UOM", readOnly: true },
        warehouse_id: { type: "Link", label: "Warehouse", target: "Warehouse" },
        rate: { type: "Currency", label: "Rate", readOnly: true },
    },
    columns: ["item_id", "qty", "uom_id", "warehouse_id", "rate"],
});

/** ERPNext Delivery Note. Totals are the item amount until the tax engine exists. Stock posting is a later line. */
export const deliveryNote = defineDoctype<"delivery_note", "items" | "packed_items">({
    doctype: "Delivery Note",
    table: "delivery_note",
    module: "stock",
    slug: "delivery-note",
    titleField: "customer_name",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        customer_name: { type: "Data", label: "Customer Name", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "MAT-DN-.YYYY.-" },
        customer_id: { type: "Link", label: "Customer", target: "Customer", required: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        posting_date: { type: "Date", label: "Posting Date", required: true, default: today() },
        posting_time: { type: "Data", label: "Posting Time" },
        set_posting_time: { type: "Check", label: "Edit Posting Date and Time", default: false },
        is_return: { type: "Check", label: "Is Return", default: false },
        return_against: { type: "Link", label: "Return Against", target: "Delivery Note" },
        currency: { type: "Data", label: "Currency" },
        conversion_rate: { type: "Float", label: "Exchange Rate", default: 1 },
        selling_price_list_id: { type: "Link", label: "Selling Price List", target: "Price List", required: true },
        tax_id: { type: "Data", label: "Tax Id", readOnly: true },
        set_warehouse_id: { type: "Link", label: "Set Warehouse", target: "Warehouse" },
        set_target_warehouse_id: { type: "Link", label: "Set Target Warehouse", target: "Warehouse" },
        transporter_id: { type: "Link", label: "Transporter", target: "Supplier" },
        lr_no: { type: "Data", label: "LR No" },
        lr_date: { type: "Date", label: "LR Date" },
        vehicle_no: { type: "Data", label: "Vehicle No" },
        instructions: { type: "Text", label: "Instructions" },
        print_without_amount: { type: "Check", label: "Print Without Amount", default: false },
        status: { type: "Data", label: "Status", readOnly: true },
        per_billed: { type: "Percent", label: "% Billed", readOnly: true },
        per_returned: { type: "Percent", label: "% Returned", readOnly: true },
        per_installed: { type: "Percent", label: "% Installed", readOnly: true },
        total: { type: "Currency", label: "Total", readOnly: true },
        net_total: { type: "Currency", label: "Net Total", readOnly: true },
        grand_total: { type: "Currency", label: "Grand Total", readOnly: true },
        base_grand_total: { type: "Currency", label: "Grand Total (Company Currency)", readOnly: true },
        items: { type: "Table", label: "Items", target: "Delivery Note Item", required: true },
        packed_items: { type: "Table", label: "Packed Items", target: "Packed Item" },
    },
    children: { items: deliveryNoteItem, packed_items: packedItem },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["customer_id", "company_id", "posting_date", "posting_time", "set_posting_time", "is_return", "return_against"],
                        ["currency", "conversion_rate", "selling_price_list_id", "set_warehouse_id", "set_target_warehouse_id", "tax_id"],
                    ],
                },
                {
                    label: "Shipping",
                    columns: [
                        ["transporter_id", "lr_no", "lr_date"],
                        ["vehicle_no", "instructions", "print_without_amount"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
                { label: "Packed Items", columns: [["packed_items"]] },
                {
                    label: "Totals",
                    columns: [
                        ["total", "net_total", "grand_total", "base_grand_total"],
                        ["status", "per_billed", "per_returned", "per_installed"],
                        ["customer_name", "naming_series", "name"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["customer_name", "status", "posting_date", "grand_total", "company_id"],
        searchFields: ["name", "customer_name", "lr_no"],
        defaultSort: { field: "posting_date", desc: true },
    },
    errorFields: {
        dn_customer: "customer_id",
        dn_company: "company_id",
        dn_price_list: "selling_price_list_id",
        dn_rate: "conversion_rate",
        fiscal_year: "posting_date",
        dn_return: "return_against",
        dn_warehouse: "items",
        dn_expense: "items",
        dn_item: "items",
        dn_uom: "items",
        dn_qty: "items",
        dn_discount: "items",
        dn_items: "items",
        dn_so: "items",
        dn_credit_limit: "grand_total",
        dn_closed: "status",
        dn_status: "status",
    },
    triggers: { items: fillDeliveryNoteItem },
    actions: [
        {
            id: "close",
            label: "Close",
            when: "submitted",
            visible: (values) => statusOf(values) !== "Closed",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Delivery Note first.");
                const { updateDeliveryNoteStatus } = await import("@/lib/actions/stock/delivery-note");
                await updateDeliveryNoteStatus(orgSlug, id, "Closed");
                return {};
            },
        },
        {
            id: "reopen",
            label: "Re-open",
            when: "submitted",
            visible: (values) => statusOf(values) === "Closed",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Delivery Note first.");
                const { updateDeliveryNoteStatus } = await import("@/lib/actions/stock/delivery-note");
                await updateDeliveryNoteStatus(orgSlug, id, "Draft");
                return {};
            },
        },
    ],
});
