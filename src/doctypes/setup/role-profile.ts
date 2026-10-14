import { defineDoctype } from "../define";

/**
 * Frappe Role Profile (frappe/core/doctype/role_profile, from memory: no local Frappe clone); defaults from
 * erpnext/setup/install.py DEFAULT_ROLE_PROFILES. Saving re-syncs every member holding the profile.
 */
export const roleProfile = defineDoctype({
    doctype: "Role Profile",
    table: "role_profile",
    module: "setup",
    slug: "role-profile",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Role Profile", required: true },
        roles: {
            type: "MultiSelect",
            label: "Roles",
            options: "Role",
            description: "Members with this profile get exactly these roles.",
        },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["name"], ["roles"]] }] }],
    listView: { columns: ["name", "roles"], searchFields: ["name"], defaultSort: { field: "name" } },
    errorFields: { duplicate: "name", invalid_role: "roles" },
});
