import { defineDoctype } from "../define";

/**
 * Frappe Role (frappe/core/doctype/role, from memory: no local Frappe clone). Ported: role_name (= `name`), disabled;
 * `is_standard` marks the 19 seeded roles. desk_access, two_factor_auth, restrict_to_domain, home_page dropped
 * (docs/modules/00-setup.md §2.7).
 */
export const role = defineDoctype({
    doctype: "Role",
    table: "roles",
    module: "setup",
    slug: "roles",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Role Name", required: true, description: "Standard roles cannot be renamed or deleted." },
        disabled: {
            type: "Check",
            label: "Disabled",
            description: "Members keep the role, but it grants nothing until it is enabled again.",
        },
        is_standard: { type: "Check", label: "Is Standard", readOnly: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["name", "disabled"], ["is_standard"]] }] }],
    listView: { columns: ["name", "is_standard", "disabled"], searchFields: ["name"], defaultSort: { field: "name" } },
    errorFields: { duplicate: "name", role_standard: "name", role_protected: "disabled" },
});
