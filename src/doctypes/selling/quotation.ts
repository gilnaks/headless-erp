import { fillQuotationItem } from "@/lib/stock/item-details";
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

export const quotationItem = defineChildDoctype({
    doctype: "Quotation Item",
    table: "quotation_item",
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
        is_alternative: { type: "Check", label: "Is Alternative", default: false },
        is_free_item: { type: "Check", label: "Is Free Item", default: false },
        ordered_qty: { type: "Float", label: "Ordered Qty", readOnly: true },
    },
    columns: ["item_id", "qty", "uom_id", "rate", "discount_percentage", "amount", "warehouse_id"],
});

/** ERPNext Quotation. Totals are the item amount until the tax engine and the payment schedule exist. */
export const quotation = defineDoctype<"quotation", "items">({
    doctype: "Quotation",
    table: "quotation",
    module: "selling",
    slug: "quotation",
    titleField: "customer_name",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        customer_name: { type: "Data", label: "Customer Name", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "SAL-QTN-.YYYY.-" },
        customer_id: { type: "Link", label: "Customer", target: "Customer", required: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        transaction_date: { type: "Date", label: "Transaction Date", required: true, default: today() },
        valid_till: { type: "Date", label: "Valid Till" },
        order_type: { type: "Select", label: "Order Type", options: ["Sales"], required: true, default: "Sales" },
        currency: { type: "Data", label: "Currency" },
        conversion_rate: { type: "Float", label: "Exchange Rate", default: 1 },
        selling_price_list_id: { type: "Link", label: "Selling Price List", target: "Price List", required: true },
        status: { type: "Data", label: "Status", readOnly: true },
        order_lost_reason: { type: "Data", label: "Lost Reason Detail", readOnly: true },
        total: { type: "Currency", label: "Total", readOnly: true },
        net_total: { type: "Currency", label: "Net Total", readOnly: true },
        grand_total: { type: "Currency", label: "Grand Total", readOnly: true },
        base_grand_total: { type: "Currency", label: "Grand Total (Company Currency)", readOnly: true },
        is_active: { type: "Check", label: "Active", readOnly: true },
        is_latest_revision: { type: "Check", label: "Latest Revision", readOnly: true },
        revision_of: { type: "Link", label: "Revision Of", target: "Quotation", readOnly: true },
        items: { type: "Table", label: "Items", target: "Quotation Item", required: true },
    },
    children: { items: quotationItem },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["customer_id", "company_id", "transaction_date", "valid_till"],
                        ["order_type", "currency", "conversion_rate", "selling_price_list_id"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
                {
                    label: "Totals",
                    columns: [
                        ["total", "net_total", "grand_total", "base_grand_total"],
                        ["status", "customer_name", "order_lost_reason", "is_active", "is_latest_revision"],
                        ["revision_of", "naming_series", "name"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["customer_name", "status", "transaction_date", "grand_total", "company_id"],
        searchFields: ["name", "customer_name"],
        defaultSort: { field: "transaction_date", desc: true },
    },
    errorFields: {
        quotation_date: "valid_till",
        quotation_revision: "transaction_date",
        quotation_customer: "customer_id",
        quotation_company: "company_id",
        quotation_price_list: "selling_price_list_id",
        quotation_rate: "conversion_rate",
        quotation_item: "items",
        quotation_uom: "items",
        quotation_qty: "items",
        quotation_discount: "items",
        quotation_items: "items",
        quotation_revise: "status",
        quotation_lost: "status",
        quotation_order: "order_type",
        not_authorized: "grand_total",
    },
    triggers: { items: fillQuotationItem },
    actions: [
        {
            id: "sales-order",
            label: "Sales Order",
            when: "submitted",
            visible: (values) => statusOf(values) !== "Lost" && values.is_active !== false,
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Quotation first.");
                const { makeSalesOrderFromQuotation } = await import("@/lib/actions/selling/quotation");
                await makeSalesOrderFromQuotation(orgSlug, id);
                return {};
            },
        },
        {
            id: "revise",
            label: "Revise",
            when: "submitted",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Quotation first.");
                const { reviseQuotation } = await import("@/lib/actions/selling/quotation");
                await reviseQuotation(orgSlug, id);
                return {};
            },
        },
        {
            id: "set-lost",
            label: "Set as Lost",
            when: "submitted",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Quotation first.");
                const { setQuotationLost } = await import("@/lib/actions/selling/quotation");
                await setQuotationLost(orgSlug, id);
                return {};
            },
        },
    ],
});
