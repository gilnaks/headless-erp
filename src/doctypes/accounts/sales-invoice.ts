import { fillSalesInvoiceItem } from "@/lib/stock/item-details";
import { createClient } from "@/lib/supabase/client";
import { defineChildDoctype, defineDoctype, type FieldValues } from "../define";

function today(): string {
    const date = new Date();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

function text(value: unknown): string {
    return typeof value === "string" ? value : "";
}

/** Debit To follows the customer receivable. An empty due date follows the posting date. */
async function fillSalesInvoiceHeader(values: FieldValues): Promise<FieldValues> {
    const patch: FieldValues = {};
    const posting = text(values.posting_date);
    if (!text(values.due_date) && posting) patch.due_date = posting;
    const customerId = text(values.customer_id);
    const companyId = text(values.company_id);
    if (!text(values.debit_to_id) && customerId && companyId) {
        const { data } = await createClient().rpc("get_party_account", {
            p_party_type: "Customer",
            p_party: customerId,
            p_company: companyId,
        });
        if (data) patch.debit_to_id = data;
    }
    return patch;
}

export const salesInvoiceItem = defineChildDoctype({
    doctype: "Sales Invoice Item",
    table: "sales_invoice_item",
    fields: {
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        item_name: { type: "Data", label: "Item Name", readOnly: true },
        qty: { type: "Float", label: "Qty", required: true },
        rate: { type: "Currency", label: "Rate" },
        amount: { type: "Currency", label: "Amount", readOnly: true },
        income_account_id: { type: "Link", label: "Income Account", target: "Account" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
    },
    columns: ["item_id", "qty", "rate", "amount", "income_account_id", "cost_center_id"],
});

/** ERPNext Sales Invoice. Totals are the item amount until taxes exist. */
export const salesInvoice = defineDoctype<"sales_invoice", "items">({
    doctype: "Sales Invoice",
    table: "sales_invoice",
    module: "accounts",
    slug: "sales-invoice",
    titleField: "customer_name",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        customer_name: { type: "Data", label: "Customer Name", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "ACC-SINV-.YYYY.-" },
        customer_id: { type: "Link", label: "Customer", target: "Customer", required: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        posting_date: { type: "Date", label: "Posting Date", required: true, default: today() },
        due_date: { type: "Date", label: "Due Date", default: today() },
        currency: { type: "Data", label: "Currency" },
        conversion_rate: { type: "Float", label: "Exchange Rate", default: 1 },
        selling_price_list_id: { type: "Link", label: "Selling Price List", target: "Price List", required: true },
        debit_to_id: { type: "Link", label: "Debit To", target: "Account" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center", readOnly: true },
        status: { type: "Data", label: "Status", readOnly: true },
        total: { type: "Currency", label: "Total", readOnly: true },
        net_total: { type: "Currency", label: "Net Total", readOnly: true },
        grand_total: { type: "Currency", label: "Grand Total", readOnly: true },
        base_grand_total: { type: "Currency", label: "Grand Total (Company Currency)", readOnly: true },
        outstanding_amount: { type: "Currency", label: "Outstanding Amount", readOnly: true },
        items: { type: "Table", label: "Items", target: "Sales Invoice Item", required: true },
    },
    children: { items: salesInvoiceItem },
    triggers: {
        customer_id: fillSalesInvoiceHeader,
        company_id: fillSalesInvoiceHeader,
        posting_date: fillSalesInvoiceHeader,
        items: fillSalesInvoiceItem,
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["customer_id", "company_id", "posting_date", "due_date"],
                        ["currency", "conversion_rate", "selling_price_list_id", "debit_to_id", "cost_center_id"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
                {
                    label: "Totals",
                    columns: [
                        ["total", "net_total", "grand_total", "base_grand_total", "outstanding_amount"],
                        ["status", "customer_name", "naming_series", "name"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["customer_name", "status", "posting_date", "due_date", "grand_total", "company_id"],
        searchFields: ["name", "customer_name"],
        defaultSort: { field: "posting_date", desc: true },
    },
    errorFields: {
        si_customer: "customer_id",
        si_company: "company_id",
        si_due_date: "due_date",
        si_price_list: "selling_price_list_id",
        si_conversion: "conversion_rate",
        si_receivable: "debit_to_id",
        si_income: "items",
        si_item: "items",
        si_qty: "items",
        si_rate: "items",
        si_cost_center: "items",
        si_items: "items",
        si_total: "grand_total",
        si_totals: "grand_total",
        not_authorized: "grand_total",
    },
});
