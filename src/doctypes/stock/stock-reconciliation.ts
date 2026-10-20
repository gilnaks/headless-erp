import { defineChildDoctype, defineDoctype } from "../define";

function today(): string {
    const date = new Date();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

export const stockReconciliationItem = defineChildDoctype({
    doctype: "Stock Reconciliation Item",
    table: "stock_reconciliation_item",
    fields: {
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        warehouse_id: { type: "Link", label: "Warehouse", target: "Warehouse", required: true },
        qty: { type: "Float", label: "Qty", required: true },
        valuation_rate: { type: "Currency", label: "Valuation Rate" },
        current_qty: { type: "Float", label: "Current Qty", readOnly: true },
        current_valuation_rate: { type: "Currency", label: "Current Valuation Rate", readOnly: true },
        current_amount: { type: "Currency", label: "Current Amount", readOnly: true },
        quantity_difference: { type: "Float", label: "Quantity Difference", readOnly: true },
        amount_difference: { type: "Currency", label: "Amount Difference", readOnly: true },
        allow_zero_valuation_rate: { type: "Check", label: "Allow Zero Valuation Rate" },
        batch_no: { type: "Data", label: "Batch No" },
        serial_no: { type: "Data", label: "Serial No" },
        serial_and_batch_bundle: { type: "Data", label: "Serial and Batch Bundle", readOnly: true },
    },
    columns: [
        "item_id",
        "warehouse_id",
        "qty",
        "valuation_rate",
        "current_qty",
        "quantity_difference",
        "amount_difference",
        "serial_no",
        "batch_no",
        "allow_zero_valuation_rate",
    ],
});

/** ERPNext Stock Reconciliation. Submit sets the balance for the three purposes. */
export const stockReconciliation = defineDoctype<"stock_reconciliation", "items">({
    doctype: "Stock Reconciliation",
    table: "stock_reconciliation",
    module: "stock",
    slug: "stock-reconciliation",
    titleField: "name",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "MAT-RECO-.YYYY.-" },
        purpose: {
            type: "Select",
            label: "Purpose",
            options: ["Opening Stock", "Stock Reconciliation", "Adjustment Entry"],
            required: true,
        },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        posting_date: { type: "Date", label: "Posting Date", required: true, default: today() },
        posting_time: { type: "Data", label: "Posting Time" },
        set_warehouse_id: { type: "Link", label: "Warehouse", target: "Warehouse" },
        expense_account_id: { type: "Link", label: "Difference Account", target: "Account" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
        items: { type: "Table", label: "Items", target: "Stock Reconciliation Item", required: true },
        difference_amount: { type: "Currency", label: "Difference Amount", readOnly: true },
    },
    children: { items: stockReconciliationItem },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["purpose", "company_id", "posting_date", "posting_time"],
                        ["set_warehouse_id", "expense_account_id", "cost_center_id"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
                { columns: [["difference_amount"], ["naming_series", "name"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "purpose", "posting_date", "difference_amount", "company_id"],
        searchFields: ["name", "purpose"],
        defaultSort: { field: "posting_date", desc: true },
    },
    errorFields: {
        reco_items: "items",
        reco_qty: "items",
        reco_item: "items",
        reco_warehouse: "items",
        reco_rate: "items",
        reco_duplicate: "items",
        reco_empty: "items",
        reco_account: "expense_account_id",
        reco_opening: "purpose",
        reco_purpose: "purpose",
    },
});
