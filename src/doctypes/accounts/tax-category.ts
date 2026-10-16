import { defineDoctype } from "../define";

/** ERPNext Tax Category. The name copies the title. */
export const taxCategory = defineDoctype({
    doctype: "Tax Category",
    table: "tax_category",
    module: "accounts",
    slug: "tax-category",
    titleField: "name",
    fields: {
        title: { type: "Data", label: "Title", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        disabled: { type: "Check", label: "Disabled" },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["title", "disabled", "name"]] }] }],
    listView: {
        columns: ["name", "disabled"],
        searchFields: ["name", "title"],
        defaultSort: { field: "name" },
    },
    errorFields: { duplicate: "title" },
});
