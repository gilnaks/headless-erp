import { defineDoctype } from "../define";

/** ERPNext Batch. The stock ledger keeps batch_qty. */
export const batch = defineDoctype<"batch">({
    doctype: "Batch",
    table: "batch",
    module: "stock",
    slug: "batch",
    titleField: "batch_id",
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        batch_id: { type: "Data", label: "Batch No", required: true },
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        manufacturing_date: { type: "Date", label: "Manufacturing Date" },
        expiry_date: { type: "Date", label: "Expiry Date" },
        batch_qty: { type: "Float", label: "Batch Qty", readOnly: true },
        disabled: { type: "Check", label: "Disabled" },
        supplier_id: { type: "Link", label: "Supplier", target: "Supplier" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["batch_id", "item_id", "manufacturing_date", "disabled"],
                        ["expiry_date", "batch_qty", "supplier_id", "name"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["batch_id", "item_id", "expiry_date", "batch_qty", "disabled"],
        searchFields: ["batch_id", "name"],
        defaultSort: { field: "batch_id" },
    },
    errorFields: { batch_id: "batch_id", batch_item: "item_id" },
});
