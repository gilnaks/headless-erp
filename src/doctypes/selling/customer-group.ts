import { defineDoctype } from "../define";

/** ERPNext Customer Group. Price list, payment terms, accounts and credit limits wait for those tables. */
export const customerGroup = defineDoctype({
    doctype: "Customer Group",
    table: "customer_group",
    module: "selling",
    slug: "customer-group",
    titleField: "customer_group_name",
    fields: {
        customer_group_name: { type: "Data", label: "Customer Group Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Customer Group",
            target: "Customer Group",
            description: "Leave empty to place the group under All Customer Groups.",
        },
        is_group: { type: "Check", label: "Is Group" },
    },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["customer_group_name", "parent_id", "is_group"]] }],
        },
    ],
    listView: {
        columns: ["customer_group_name", "parent_id", "is_group"],
        searchFields: ["customer_group_name"],
        defaultSort: { field: "customer_group_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "customer_group_name",
        customer_group_root: "customer_group_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
