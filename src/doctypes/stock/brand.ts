import { defineDoctype } from "../define";

/** ERPNext Brand (erpnext/setup/doctype/brand). Company defaults wait for Item Default. */
export const brand = defineDoctype({
    doctype: "Brand",
    table: "brand",
    module: "stock",
    slug: "brand",
    titleField: "brand",
    fields: {
        brand: { type: "Data", label: "Brand", required: true },
        description: { type: "Text", label: "Description" },
    },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["brand", "description"]] }],
        },
    ],
    listView: {
        columns: ["brand", "description"],
        searchFields: ["brand"],
        defaultSort: { field: "brand" },
    },
    errorFields: { duplicate: "brand" },
});
