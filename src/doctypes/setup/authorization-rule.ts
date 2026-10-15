import { defineDoctype } from "../define";

/**
 * Authorization Rule (erpnext/setup/doctype/authorization_rule), simplified port: Grand Total limits on Sales/Purchase
 * Orders and Invoices (docs/modules/00-setup.md §2.10). Validation and enforcement
 * (`app.validate_approving_authority`) live in supabase/migrations/0125_setup_authorization_rule.sql.
 */
export const authorizationRule = defineDoctype({
    doctype: "Authorization Rule",
    table: "authorization_rule",
    module: "setup",
    slug: "authorization-rule",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Name", readOnly: true, description: "Set on save (HR-ARU-.#####)." },
        transaction: {
            type: "Select",
            label: "Transaction",
            options: ["Sales Order", "Purchase Order", "Sales Invoice", "Purchase Invoice"],
            required: true,
        },
        based_on: { type: "Select", label: "Based On", options: ["Grand Total"], required: true, default: "Grand Total" },
        company_id: { type: "Link", label: "Company", target: "Company", description: "Leave empty to apply to all companies." },
        value: {
            type: "Float",
            label: "Above Value",
            description: "The rule applies when the Grand Total (in company currency) reaches this value.",
        },
        system_role: {
            type: "Select",
            label: "Applicable To (Role)",
            options: "Role",
            description: "Leave Role and User empty to apply the rule to everyone.",
        },
        system_user: { type: "Link", label: "Applicable To (User)", target: "User" },
        approving_role: {
            type: "Select",
            label: "Approving Role",
            options: "Role",
            description: "Users with this role can submit above the value.",
        },
        approving_user: { type: "Link", label: "Approving User", target: "User" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["name", "transaction", "based_on"],
                        ["company_id", "value"],
                    ],
                },
                { label: "Applicable To", columns: [["system_role"], ["system_user"]] },
                { label: "Approver", columns: [["approving_role"], ["approving_user"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "transaction", "based_on", "company_id", "value", "approving_role", "approving_user"],
        searchFields: ["name", "transaction", "approving_role"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "transaction",
        approver_required: "approving_role",
        approving_user_same: "approving_user",
        approving_role_same: "approving_role",
        system_user_not_member: "system_user",
        approving_user_not_member: "approving_user",
    },
});
