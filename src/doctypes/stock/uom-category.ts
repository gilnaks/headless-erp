import { defineDoctype } from "../define";

/** ERPNext UOM Category. Categories for the curated units are seeded with the UOM rows. */
export const uomCategory = defineDoctype({
    doctype: "UOM Category",
    table: "uom_category",
    module: "stock",
    slug: "uom-category",
    titleField: "category_name",
    fields: {
        category_name: { type: "Data", label: "Category Name", required: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["category_name"]] }] }],
    listView: {
        columns: ["category_name"],
        searchFields: ["category_name"],
        defaultSort: { field: "category_name" },
    },
    errorFields: { duplicate: "category_name" },
});
