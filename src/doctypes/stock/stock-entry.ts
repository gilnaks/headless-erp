import { defineChildDoctype, defineDoctype } from "../define";

function today(): string {
    const date = new Date();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

export const stockEntryDetail = defineChildDoctype({
    doctype: "Stock Entry Detail",
    table: "stock_entry_detail",
    fields: {
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        qty: { type: "Float", label: "Qty", required: true },
        uom_id: { type: "Link", label: "UOM", target: "UOM" },
        conversion_factor: { type: "Float", label: "Conversion Factor", default: 1 },
        transfer_qty: { type: "Float", label: "Qty as per Stock UOM", readOnly: true },
        s_warehouse_id: { type: "Link", label: "Source Warehouse", target: "Warehouse" },
        t_warehouse_id: { type: "Link", label: "Target Warehouse", target: "Warehouse" },
        basic_rate: { type: "Currency", label: "Rate" },
        basic_amount: { type: "Currency", label: "Basic Amount", readOnly: true },
        additional_cost: { type: "Currency", label: "Additional Cost", readOnly: true },
        valuation_rate: { type: "Currency", label: "Valuation Rate", readOnly: true },
        amount: { type: "Currency", label: "Amount", readOnly: true },
        expense_account_id: { type: "Link", label: "Difference Account", target: "Account" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
        allow_zero_valuation_rate: { type: "Check", label: "Allow Zero Valuation Rate" },
        is_finished_item: { type: "Check", label: "Is Finished Item" },
        per_transferred: { type: "Float", label: "Transferred", readOnly: true },
        material_request_id: { type: "Data", label: "Material Request", readOnly: true },
        material_request_item: { type: "Data", label: "Material Request Item", readOnly: true },
        serial_and_batch_bundle: { type: "Data", label: "Serial and Batch Bundle", readOnly: true },
        batch_no: { type: "Data", label: "Batch No", readOnly: true },
        serial_no: { type: "Data", label: "Serial No", readOnly: true },
        use_serial_batch_fields: { type: "Check", label: "Use Serial / Batch Fields", readOnly: true },
    },
    columns: [
        "item_id",
        "qty",
        "uom_id",
        "s_warehouse_id",
        "t_warehouse_id",
        "basic_rate",
        "amount",
        "is_finished_item",
        "allow_zero_valuation_rate",
    ],
});

export const stockEntryAdditionalCost = defineChildDoctype({
    doctype: "Stock Entry Additional Cost",
    table: "stock_entry_additional_cost",
    fields: {
        expense_account_id: { type: "Link", label: "Expense Account", target: "Account", required: true },
        description: { type: "Data", label: "Description" },
        amount: { type: "Currency", label: "Amount", required: true },
    },
    columns: ["expense_account_id", "description", "amount"],
});

/** ERPNext Stock Entry. Submit posts the stock ledger for the eight standard purposes. */
export const stockEntry = defineDoctype<"stock_entry", "items" | "additional_costs">({
    doctype: "Stock Entry",
    table: "stock_entry",
    module: "stock",
    slug: "stock-entry",
    titleField: "title",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        title: { type: "Data", label: "Title", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "MAT-STE-.YYYY.-" },
        stock_entry_type_id: { type: "Link", label: "Stock Entry Type", target: "Stock Entry Type", required: true },
        purpose: { type: "Data", label: "Purpose", readOnly: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        posting_date: { type: "Date", label: "Posting Date", required: true, default: today() },
        posting_time: { type: "Data", label: "Posting Time" },
        set_posting_time: { type: "Check", label: "Edit Posting Date and Time" },
        from_warehouse_id: { type: "Link", label: "Source Warehouse", target: "Warehouse" },
        to_warehouse_id: { type: "Link", label: "Target Warehouse", target: "Warehouse" },
        add_to_transit: { type: "Check", label: "Add to Transit" },
        items: { type: "Table", label: "Items", target: "Stock Entry Detail", required: true },
        additional_costs: { type: "Table", label: "Additional Costs", target: "Stock Entry Additional Cost" },
        total_outgoing_value: { type: "Currency", label: "Total Outgoing Value", readOnly: true },
        total_incoming_value: { type: "Currency", label: "Total Incoming Value", readOnly: true },
        value_difference: { type: "Currency", label: "Value Difference", readOnly: true },
        is_opening: { type: "Select", label: "Is Opening", options: ["No", "Yes"], default: "No" },
        remarks: { type: "Text", label: "Remarks" },
        project: { type: "Data", label: "Project" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
        bom_no: { type: "Data", label: "BOM No" },
        fg_completed_qty: { type: "Float", label: "Finished Goods Qty", default: 0 },
        use_multi_level_bom: { type: "Check", label: "Use Multi-Level BOM", default: true },
        work_order_id: { type: "Data", label: "Work Order" },
        outgoing_stock_entry_id: { type: "Link", label: "Outgoing Stock Entry", target: "Stock Entry" },
    },
    children: { items: stockEntryDetail, additional_costs: stockEntryAdditionalCost },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["stock_entry_type_id", "company_id", "posting_date", "posting_time", "set_posting_time"],
                        ["from_warehouse_id", "to_warehouse_id", "add_to_transit", "is_opening", "purpose"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
                { label: "Additional Costs", columns: [["additional_costs"]] },
                {
                    columns: [["total_outgoing_value", "total_incoming_value", "value_difference"], ["remarks"]],
                },
            ],
        },
        {
            label: "More",
            sections: [
                {
                    columns: [
                        ["cost_center_id", "project", "outgoing_stock_entry_id", "naming_series", "name", "title"],
                        ["bom_no", "fg_completed_qty", "use_multi_level_bom", "work_order_id"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["title", "posting_date", "value_difference", "company_id"],
        searchFields: ["name", "title", "purpose"],
        defaultSort: { field: "posting_date", desc: true },
    },
    errorFields: {
        ste_items: "items",
        ste_qty: "items",
        ste_item: "items",
        ste_uom: "items",
        ste_warehouse: "items",
        ste_rate: "items",
        ste_cost: "additional_costs",
        ste_transit: "add_to_transit",
        ste_opening: "is_opening",
        ste_opening_cost: "additional_costs",
        ste_purpose: "stock_entry_type_id",
        ste_type: "stock_entry_type_id",
    },
});
