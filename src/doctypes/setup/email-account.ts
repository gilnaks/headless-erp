import { defineDoctype } from "../define";

/**
 * Email Account, outbound only (frappe/email/doctype/email_account, ported from memory: the frappe repo is not
 * cloned; `company` from erpnext/setup/install.py create_custom_company_links). Sends through Resend; the API key is
 * stored in Supabase Vault by `set_email_account_key` and never read back into the form. Default-outgoing rules live
 * in `app.email_account_validate` (supabase/migrations/0123_setup_email_account.sql).
 */
export const emailAccount = defineDoctype({
    doctype: "Email Account",
    table: "email_account",
    module: "setup",
    slug: "email-account",
    titleField: "email_account_name",
    fields: {
        email_account_name: { type: "Data", label: "Email Account Name", required: true },
        email_id: { type: "Data", label: "Email Address", required: true, placeholder: "sales@example.com" },
        company_id: {
            type: "Link",
            label: "Company",
            target: "Company",
            description: "Documents of this company are sent from this account.",
        },
        provider: { type: "Select", label: "Service", options: ["resend"], required: true, default: "resend" },
        api_key_secret: {
            type: "Password",
            label: "API Key",
            secretRpc: "set_email_account_key",
            description: "Stored encrypted and never shown again. Leave blank to keep the saved key.",
        },
        has_api_key: { type: "Check", label: "API Key Saved", readOnly: true },
        enabled: { type: "Check", label: "Enabled", default: true },
        enable_outgoing: { type: "Check", label: "Enable Outgoing", default: true },
        default_outgoing: { type: "Check", label: "Default Outgoing", description: "Used when a company has no account of its own." },
        always_use_account_email_id_as_sender: {
            type: "Check",
            label: "Always use this email address as sender address",
            description: "Otherwise replies go to the person who sent the email.",
        },
        always_use_account_name_as_sender_name: {
            type: "Check",
            label: "Always use this name as sender name",
            description: "Otherwise the sender's own name is shown.",
        },
        add_signature: { type: "Check", label: "Add Signature" },
        signature: {
            type: "Text",
            label: "Signature",
            html: true,
            dependsOn: (v) => Boolean(v.add_signature),
            description: "HTML; scripts, event handlers and javascript: links are removed on save.",
        },
        footer: {
            type: "Text",
            label: "Footer Content",
            html: true,
            description: "HTML appended to every email sent from this account.",
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["email_account_name", "email_id", "company_id"],
                        ["enabled", "enable_outgoing", "default_outgoing"],
                    ],
                },
                {
                    label: "Service",
                    columns: [["provider", "api_key_secret"], ["has_api_key"]],
                },
                {
                    label: "Outgoing",
                    columns: [
                        ["always_use_account_email_id_as_sender", "always_use_account_name_as_sender_name"],
                        ["add_signature", "signature"],
                    ],
                },
                { label: "Footer", columns: [["footer"]] },
            ],
        },
    ],
    listView: {
        columns: ["email_account_name", "email_id", "company_id", "provider", "default_outgoing"],
        searchFields: ["email_account_name", "email_id"],
        defaultSort: { field: "email_account_name" },
    },
    errorFields: {
        duplicate: "email_account_name",
        invalid_email: "email_id",
        email_default_disabled: "default_outgoing",
        email_key_required: "api_key_secret",
    },
    actions: [
        {
            id: "send-test-email",
            label: "Send Test Email",
            run: async (_values, { orgSlug, id, notify }) => {
                if (!id) throw new Error("Save the Email Account first.");
                // Server Action, imported lazily so descriptors stay importable outside Next (registry tests).
                const { sendTestEmail } = await import("@/lib/actions/setup/email-account");
                const result = await sendTestEmail({ orgSlug, id });
                if (!result.ok) throw new Error(result.error);
                notify(`Test email sent to ${result.data?.to}.`);
                return {};
            },
        },
    ],
});
