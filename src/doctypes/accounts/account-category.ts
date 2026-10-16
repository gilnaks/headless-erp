import { defineDoctype } from "../define";

/** ERPNext Account Category. Seeded from every category named in the vendored charts. */
export const accountCategory = defineDoctype({
    doctype: "Account Category",
    table: "account_category",
    module: "accounts",
    slug: "account-category",
    titleField: "account_category_name",
    fields: {
        account_category_name: { type: "Data", label: "Account Category", required: true },
        description: { type: "Text", label: "Description" },
        root_type: {
            type: "Select",
            label: "Root Type",
            options: ["Asset", "Liability", "Equity", "Income", "Expense"],
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["account_category_name", "root_type", "description"]] }],
        },
    ],
    listView: {
        columns: ["account_category_name", "root_type"],
        searchFields: ["account_category_name"],
        defaultSort: { field: "account_category_name" },
    },
    errorFields: { duplicate: "account_category_name" },
});
