import { defineDoctype } from "../define";

/** ERPNext Designation (erpnext/setup/doctype/designation): a job title; 31 presets per organization (§2.4). */
export const designation = defineDoctype({
    doctype: "Designation",
    table: "designation",
    module: "setup",
    slug: "designation",
    titleField: "designation_name",
    fields: {
        designation_name: { type: "Data", label: "Designation", required: true },
        description: { type: "Text", label: "Description" },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["designation_name", "description"]] }] }],
    listView: {
        columns: ["designation_name", "description"],
        searchFields: ["designation_name"],
        defaultSort: { field: "designation_name" },
    },
    errorFields: { duplicate: "designation_name" },
});
