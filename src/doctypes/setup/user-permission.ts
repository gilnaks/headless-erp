import { defineDoctype } from "../define";

/**
 * User Permission targets that are trees (`doctype_meta.is_tree`); only they offer "Hide Descendants". Checked against
 * the database by `doctypes.db.test.ts`.
 */
export const TREE_PERMISSION_TARGETS: readonly string[] = ["Company"];

/**
 * Frappe User Permission (frappe/core/doctype/user_permission, from memory: no local Frappe clone). Ported: user,
 * allow (`doctype`), for_value (`record_id`), applicable_for (empty = apply_to_all_doctypes), is_default,
 * hide_descendants (docs/modules/00-setup.md §2.9).
 */
export const userPermission = defineDoctype({
    doctype: "User Permission",
    table: "user_permissions",
    module: "setup",
    slug: "user-permissions",
    titleField: "doctype",
    fields: {
        user_id: { type: "Link", label: "User", target: "User", required: true },
        doctype: { type: "Select", label: "Allow", options: "UserPermissionTarget", required: true },
        record_id: {
            type: "DynamicLink",
            label: "For Value",
            optionsField: "doctype",
            required: true,
            description: "The user only sees this record (and the records linked to it) of that document type.",
        },
        applicable_for: {
            type: "Select",
            label: "Applicable For",
            options: "DocType",
            description: "Leave empty to apply to all document types.",
        },
        is_default: {
            type: "Check",
            label: "Is Default",
            description: "Pre-selected for this user (e.g. the company in the top bar). One default per document type.",
        },
        hide_descendants: {
            type: "Check",
            label: "Hide Descendants",
            description: "Allow only this record, not the records below it in the tree.",
            dependsOn: (v) => TREE_PERMISSION_TARGETS.includes(String(v.doctype ?? "")),
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["user_id", "doctype", "record_id"],
                        ["applicable_for", "is_default", "hide_descendants"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["user_id", "doctype", "record_id", "applicable_for", "is_default"],
        searchFields: ["doctype", "applicable_for"],
        defaultSort: { field: "doctype" },
    },
    errorFields: {
        user_not_member: "user_id",
        doctype_not_allowed: "doctype",
        record_unknown: "record_id",
        applicable_for_unknown: "applicable_for",
        default_exists: "is_default",
        duplicate: "record_id",
    },
});
