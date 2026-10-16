import { defineDoctype } from "../define";

/** ERPNext Stock Entry Type. The eight standard purposes are seeded (00-setup A6) and cannot be renamed. */
export const stockEntryType = defineDoctype({
    doctype: "Stock Entry Type",
    table: "stock_entry_type",
    module: "stock",
    slug: "stock-entry-type",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Name", required: true, setOnlyOnce: true },
        purpose: { type: "Data", label: "Purpose", readOnly: true },
        is_standard: { type: "Check", label: "Is Standard", readOnly: true },
        add_to_transit: { type: "Check", label: "Add to Transit" },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["name", "purpose", "add_to_transit", "is_standard"]] }] }],
    listView: {
        columns: ["name", "purpose", "add_to_transit", "is_standard"],
        searchFields: ["name"],
        defaultSort: { field: "name" },
    },
    triggers: {
        name: (values) => ({ purpose: values.name }),
    },
    errorFields: { duplicate: "name", stock_entry_type_standard: "name", stock_entry_type_purpose: "purpose" },
});
