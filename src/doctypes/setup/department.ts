import { defineDoctype } from "../define";

/**
 * ERPNext Department (erpnext/setup/doctype/department): a tree named "<department_name> - <abbr>" by
 * `app.department_validate` (0112). The org root "All Departments" has no company and cannot be changed (§2.3).
 */
export const department = defineDoctype({
    doctype: "Department",
    table: "department",
    module: "setup",
    slug: "department",
    titleField: "name",
    fields: {
        department_name: { type: "Data", label: "Department", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        parent_id: {
            type: "Link",
            label: "Parent Department",
            target: "Department",
            description: "Leave empty to place the department under All Departments.",
        },
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
                        ["department_name", "parent_id", "company_id"],
                        ["name", "is_group", "disabled"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "company_id", "parent_id", "is_group", "disabled"],
        searchFields: ["name"],
        defaultSort: { field: "name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group", filters: ["company_id"], disabledField: "disabled" },
    errorFields: {
        duplicate: "department_name",
        company_required: "company_id",
        department_root: "department_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
