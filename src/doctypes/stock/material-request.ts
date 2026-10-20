import { fillMaterialRequestItem } from "@/lib/stock/item-details";
import { defineChildDoctype, defineDoctype } from "../define";

function today(): string {
    const date = new Date();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

export const materialRequestItem = defineChildDoctype({
    doctype: "Material Request Item",
    table: "material_request_item",
    fields: {
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        qty: { type: "Float", label: "Qty", required: true },
        uom_id: { type: "Link", label: "UOM", target: "UOM" },
        conversion_factor: { type: "Float", label: "UOM Conversion Factor", readOnly: true },
        stock_uom_id: { type: "Link", label: "Stock UOM", target: "UOM", readOnly: true },
        stock_qty: { type: "Float", label: "Qty in Stock UOM", readOnly: true },
        schedule_date: { type: "Date", label: "Required By" },
        warehouse_id: { type: "Link", label: "Target Warehouse", target: "Warehouse" },
        from_warehouse_id: { type: "Link", label: "Source Warehouse", target: "Warehouse" },
        ordered_qty: { type: "Float", label: "Ordered Qty", readOnly: true },
        received_qty: { type: "Float", label: "Received Qty", readOnly: true },
        rate: { type: "Currency", label: "Rate" },
        amount: { type: "Currency", label: "Amount", readOnly: true },
        project: { type: "Data", label: "Project" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
    },
    columns: ["item_id", "qty", "warehouse_id", "from_warehouse_id", "stock_qty", "ordered_qty", "rate", "schedule_date"],
});

/** ERPNext Material Request. Submit does not move stock; a Stock Entry fulfills Issue, Transfer, and Customer Provided. */
export const materialRequest = defineDoctype<"material_request", "items">({
    doctype: "Material Request",
    table: "material_request",
    module: "stock",
    slug: "material-request",
    titleField: "title",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        title: { type: "Data", label: "Title", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "MAT-MR-.YYYY.-" },
        material_request_type: {
            type: "Select",
            label: "Purpose",
            options: ["Purchase", "Material Transfer", "Material Issue", "Manufacture", "Customer Provided"],
            required: true,
        },
        customer_id: { type: "Link", label: "Customer", target: "Customer" },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        transaction_date: { type: "Date", label: "Transaction Date", required: true, default: today() },
        schedule_date: { type: "Date", label: "Required By", required: true, default: today() },
        set_from_warehouse_id: { type: "Link", label: "Set Source Warehouse", target: "Warehouse" },
        set_warehouse_id: { type: "Link", label: "Set Target Warehouse", target: "Warehouse" },
        status: { type: "Data", label: "Status", readOnly: true },
        per_ordered: { type: "Float", label: "% Ordered", readOnly: true },
        per_received: { type: "Float", label: "% Received", readOnly: true },
        items: { type: "Table", label: "Items", target: "Material Request Item", required: true },
    },
    children: { items: materialRequestItem },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["material_request_type", "company_id", "customer_id", "transaction_date"],
                        ["schedule_date", "set_from_warehouse_id", "set_warehouse_id"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
                {
                    columns: [
                        ["status", "per_ordered", "per_received"],
                        ["title", "naming_series", "name"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["title", "material_request_type", "status", "transaction_date", "company_id"],
        searchFields: ["name", "title", "material_request_type"],
        defaultSort: { field: "transaction_date", desc: true },
    },
    errorFields: {
        mr_items: "items",
        mr_item: "items",
        mr_qty: "items",
        mr_uom: "items",
        mr_warehouse: "items",
        mr_date: "schedule_date",
        mr_type: "material_request_type",
        mr_status: "status",
        mr_stopped: "status",
        mr_map: "material_request_type",
        mr_empty: "items",
    },
    triggers: { items: fillMaterialRequestItem },
    actions: [
        {
            id: "stop",
            label: "Stop",
            when: "submitted",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Material Request first.");
                const { setMaterialRequestStatus } = await import("@/lib/actions/stock/material-request");
                await setMaterialRequestStatus(orgSlug, id, "Stopped");
                return {};
            },
        },
        {
            id: "reopen",
            label: "Reopen",
            when: "submitted",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Material Request first.");
                const { setMaterialRequestStatus } = await import("@/lib/actions/stock/material-request");
                await setMaterialRequestStatus(orgSlug, id, "Submitted");
                return {};
            },
        },
        {
            id: "make-stock-entry",
            label: "Create Stock Entry",
            when: "submitted",
            run: async (_values, { orgSlug, id }) => {
                if (!id) throw new Error("Save the Material Request first.");
                const { makeStockEntryFromMaterialRequest } = await import("@/lib/actions/stock/material-request");
                await makeStockEntryFromMaterialRequest(orgSlug, id);
                return {};
            },
        },
    ],
});
