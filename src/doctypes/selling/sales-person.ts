import { defineDoctype } from "../define";

/** ERPNext Sales Person. The Employee link is not built. A disabled person cannot join a sales team. */
export const salesPerson = defineDoctype({
    doctype: "Sales Person",
    table: "sales_person",
    module: "selling",
    slug: "sales-person",
    titleField: "sales_person_name",
    fields: {
        sales_person_name: { type: "Data", label: "Sales Person Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Sales Person",
            target: "Sales Person",
            description: "Leave empty to place the person under Sales Team.",
        },
        is_group: { type: "Check", label: "Is Group" },
        enabled: { type: "Check", label: "Enabled", default: true },
        commission_rate: { type: "Percent", label: "Commission Rate", default: 0 },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["sales_person_name", "parent_id", "is_group"],
                        ["enabled", "commission_rate"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["sales_person_name", "parent_id", "enabled", "commission_rate"],
        searchFields: ["sales_person_name"],
        defaultSort: { field: "sales_person_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "sales_person_name",
        sales_person_root: "sales_person_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
