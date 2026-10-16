import { defineDoctype } from "../define";

/** ERPNext Item Group (erpnext/setup/doctype/item_group). Defaults and taxes wait for Account and Item Tax Template. */
export const itemGroup = defineDoctype({
    doctype: "Item Group",
    table: "item_group",
    module: "stock",
    slug: "item-group",
    titleField: "item_group_name",
    fields: {
        item_group_name: { type: "Data", label: "Item Group Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Item Group",
            target: "Item Group",
            description: "Leave empty to place the group under All Item Groups.",
        },
        is_group: { type: "Check", label: "Is Group" },
    },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["item_group_name", "parent_id", "is_group"]] }],
        },
    ],
    listView: {
        columns: ["item_group_name", "parent_id", "is_group"],
        searchFields: ["item_group_name"],
        defaultSort: { field: "item_group_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "item_group_name",
        item_group_root: "item_group_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
