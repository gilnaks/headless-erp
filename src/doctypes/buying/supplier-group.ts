import { defineDoctype } from "../define";

/** ERPNext Supplier Group. Payment terms and party accounts wait for those tables. */
export const supplierGroup = defineDoctype({
    doctype: "Supplier Group",
    table: "supplier_group",
    module: "buying",
    slug: "supplier-group",
    titleField: "supplier_group_name",
    fields: {
        supplier_group_name: { type: "Data", label: "Supplier Group Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Supplier Group",
            target: "Supplier Group",
            description: "Leave empty to place the group under All Supplier Groups.",
        },
        is_group: { type: "Check", label: "Is Group" },
    },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["supplier_group_name", "parent_id", "is_group"]] }],
        },
    ],
    listView: {
        columns: ["supplier_group_name", "parent_id", "is_group"],
        searchFields: ["supplier_group_name"],
        defaultSort: { field: "supplier_group_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "supplier_group_name",
        supplier_group_root: "supplier_group_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
