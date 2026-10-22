import { fillSalesOrderItem } from "@/lib/stock/item-details";
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

export const salesOrderItem = defineChildDoctype({
    doctype: "Sales Order Item",
    table: "sales_order_item",
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
        delivery_date: { type: "Date", label: "Delivery Date" },
        delivered_by_supplier: { type: "Check", label: "Delivered by Supplier", default: false },
        supplier_id: { type: "Link", label: "Supplier", target: "Supplier" },
    },
    columns: [
        "item_id",
        "qty",
        "uom_id",
        "rate",
        "discount_percentage",
        "amount",
        "warehouse_id",
        "delivery_date",
        "delivered_by_supplier",
        "supplier_id",
    ],
});

/** ERPNext Sales Order. Totals are the item amount until the tax engine and the payment schedule exist. */
export const salesOrder = defineDoctype<"sales_order", "items">({
    doctype: "Sales Order",
    table: "sales_order",
    module: "selling",
    slug: "sales-order",
    titleField: "customer_name",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        customer_name: { type: "Data", label: "Customer Name", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "SAL-ORD-.YYYY.-" },
        customer_id: { type: "Link", label: "Customer", target: "Customer", required: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        transaction_date: { type: "Date", label: "Transaction Date", required: true, default: today() },
        delivery_date: { type: "Date", label: "Delivery Date", default: today() },
        order_type: { type: "Select", label: "Order Type", options: ["Sales"], required: true, default: "Sales" },
        currency: { type: "Data", label: "Currency" },
        conversion_rate: { type: "Float", label: "Exchange Rate", default: 1 },
        selling_price_list_id: { type: "Link", label: "Selling Price List", target: "Price List", required: true },
        po_no: { type: "Data", label: "Customer's Purchase Order" },
        po_date: { type: "Date", label: "Customer's Purchase Order Date" },
        tax_id: { type: "Data", label: "Tax Id", readOnly: true },
        set_warehouse_id: { type: "Link", label: "Set Warehouse", target: "Warehouse" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center", readOnly: true },
        status: { type: "Data", label: "Status", readOnly: true },
        total: { type: "Currency", label: "Total", readOnly: true },
        net_total: { type: "Currency", label: "Net Total", readOnly: true },
        grand_total: { type: "Currency", label: "Grand Total", readOnly: true },
        base_grand_total: { type: "Currency", label: "Grand Total (Company Currency)", readOnly: true },
        delivery_status: { type: "Data", label: "Delivery Status", readOnly: true },
        billing_status: { type: "Data", label: "Billing Status", readOnly: true },
        per_delivered: { type: "Percent", label: "% Delivered", readOnly: true },
        per_billed: { type: "Percent", label: "% Billed", readOnly: true },
        per_picked: { type: "Percent", label: "% Picked", readOnly: true },
        advance_paid: { type: "Currency", label: "Advance Paid", readOnly: true },
        advance_payment_status: { type: "Data", label: "Advance Payment Status", readOnly: true },
        skip_delivery_note: { type: "Check", label: "Skip Delivery Note", readOnly: true, default: false },
        reserve_stock: { type: "Check", label: "Reserve Stock", readOnly: true, default: false },
        items: { type: "Table", label: "Items", target: "Sales Order Item", required: true },
    },
    children: { items: salesOrderItem },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["customer_id", "company_id", "transaction_date", "delivery_date", "po_no", "po_date"],
                        ["order_type", "currency", "conversion_rate", "selling_price_list_id", "set_warehouse_id", "cost_center_id"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
                {
                    label: "Totals",
                    columns: [
                        ["total", "net_total", "grand_total", "base_grand_total", "advance_paid"],
                        ["status", "delivery_status", "billing_status", "per_delivered", "per_billed", "per_picked"],
                        [
                            "advance_payment_status",
                            "skip_delivery_note",
                            "reserve_stock",
                            "tax_id",
                            "customer_name",
                            "naming_series",
                            "name",
                        ],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["customer_name", "status", "transaction_date", "grand_total", "delivery_status", "billing_status", "company_id"],
        searchFields: ["name", "customer_name", "po_no"],
        defaultSort: { field: "transaction_date", desc: true },
    },
    errorFields: {
        so_customer: "customer_id",
        so_company: "company_id",
        so_price_list: "selling_price_list_id",
        so_rate: "conversion_rate",
        so_order: "order_type",
        so_delivery_date: "delivery_date",
        so_po: "po_no",
        so_warehouse: "items",
        so_item: "items",
        so_uom: "items",
        so_qty: "items",
        so_discount: "items",
        so_items: "items",
        so_quotation: "items",
        so_rows_closed: "items",
        so_credit_limit: "grand_total",
        so_closed: "status",
        so_status: "status",
        not_authorized: "grand_total",
    },
    triggers: { items: fillSalesOrderItem },
    actions: [
        {
            id: "delivery-note",
            label: "Delivery Note",
            when: "submitted",
            visible: (values) => {
                const status = statusOf(values);
                return status !== "Closed" && status !== "On Hold";
            },
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Sales Order first.");
                const { makeDeliveryNoteFromSalesOrder } = await import("@/lib/actions/selling/sales-order");
                await makeDeliveryNoteFromSalesOrder(orgSlug, id);
                return {};
            },
        },
        {
            id: "close",
            label: "Close",
            when: "submitted",
            visible: (values) => statusOf(values) !== "Closed",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Sales Order first.");
                const { updateSalesOrderStatus } = await import("@/lib/actions/selling/sales-order");
                await updateSalesOrderStatus(orgSlug, id, "Closed");
                return {};
            },
        },
        {
            id: "reopen",
            label: "Re-open",
            when: "submitted",
            visible: (values) => statusOf(values) === "Closed",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Sales Order first.");
                const { updateSalesOrderStatus } = await import("@/lib/actions/selling/sales-order");
                await updateSalesOrderStatus(orgSlug, id, "Draft");
                return {};
            },
        },
        {
            id: "hold",
            label: "Hold",
            when: "submitted",
            visible: (values) => {
                const status = statusOf(values);
                return status !== "Closed" && status !== "On Hold";
            },
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Sales Order first.");
                const { updateSalesOrderStatus } = await import("@/lib/actions/selling/sales-order");
                await updateSalesOrderStatus(orgSlug, id, "On Hold");
                return {};
            },
        },
        {
            id: "resume",
            label: "Resume",
            when: "submitted",
            visible: (values) => statusOf(values) === "On Hold",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Sales Order first.");
                const { updateSalesOrderStatus } = await import("@/lib/actions/selling/sales-order");
                await updateSalesOrderStatus(orgSlug, id, "Draft");
                return {};
            },
        },
    ],
});
