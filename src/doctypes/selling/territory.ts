import { defineDoctype } from "../define";

/** ERPNext Territory. The organization country and Rest Of The World are seeded under All Territories. */
export const territory = defineDoctype({
    doctype: "Territory",
    table: "territory",
    module: "selling",
    slug: "territory",
    titleField: "territory_name",
    fields: {
        territory_name: { type: "Data", label: "Territory Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Territory",
            target: "Territory",
            description: "Leave empty to place the territory under All Territories.",
        },
        is_group: { type: "Check", label: "Is Group" },
        territory_manager_id: { type: "Link", label: "Territory Manager", target: "Sales Person" },
    },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["territory_name", "parent_id", "is_group", "territory_manager_id"]] }],
        },
    ],
    listView: {
        columns: ["territory_name", "parent_id", "is_group", "territory_manager_id"],
        searchFields: ["territory_name"],
        defaultSort: { field: "territory_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "territory_name",
        territory_root: "territory_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
