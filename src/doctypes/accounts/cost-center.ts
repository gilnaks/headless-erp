import { defineDoctype } from "../define";

/** ERPNext Cost Center. Each company is seeded with a group named after the company and a Main ledger. */
export const costCenter = defineDoctype({
    doctype: "Cost Center",
    table: "cost_center",
    module: "accounts",
    slug: "cost-center",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        cost_center_name: { type: "Data", label: "Cost Center Name", required: true },
        cost_center_number: { type: "Data", label: "Cost Center Number" },
        parent_id: { type: "Link", label: "Parent Cost Center", target: "Cost Center" },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        is_group: { type: "Check", label: "Is Group" },
        disabled: { type: "Check", label: "Disabled" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["cost_center_name", "cost_center_number", "parent_id", "company_id"],
                        ["name", "is_group", "disabled"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "company_id", "parent_id", "is_group", "disabled"],
        searchFields: ["name", "cost_center_name"],
        defaultSort: { field: "name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group", filters: ["company_id"], disabledField: "disabled" },
    errorFields: {
        duplicate: "cost_center_name",
        cost_center_company: "company_id",
        cost_center_parent: "parent_id",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
