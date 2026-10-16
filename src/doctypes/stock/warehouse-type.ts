import { defineDoctype } from "../define";

/** ERPNext Warehouse Type. Seeded with Transit. */
export const warehouseType = defineDoctype({
    doctype: "Warehouse Type",
    table: "warehouse_type",
    module: "stock",
    slug: "warehouse-type",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Warehouse Type", required: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["name"]] }] }],
    listView: { columns: ["name"], searchFields: ["name"], defaultSort: { field: "name" } },
    errorFields: { duplicate: "name" },
});
