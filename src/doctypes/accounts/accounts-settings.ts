import { defineDoctype } from "../define";

/**
 * Accounts Settings (ERPNext accounts_settings.json). One row per organization, seeded by
 * supabase/migrations/0309_accounts_settings.sql. Fixed columns stay off this form.
 */
export const accountsSettings = defineDoctype({
    doctype: "Accounts Settings",
    table: "accounts_settings",
    module: "accounts",
    slug: "settings",
    single: true,
    fields: {
        unlink_payment_on_cancellation_of_invoice: {
            type: "Check",
            label: "Unlink Payment on cancellation of invoice",
            default: true,
        },
        unlink_advance_payment_on_cancelation_of_order: {
            type: "Check",
            label: "Unlink Advance Payment on cancellation of order",
            default: true,
        },
        check_supplier_invoice_uniqueness: { type: "Check", label: "Check Supplier invoice number uniqueness" },
        automatically_fetch_payment_terms: {
            type: "Check",
            label: "Automatically fetch Payment Terms from Order/Quotation",
        },
        confirm_before_resetting_posting_date: {
            type: "Check",
            label: "Confirm before resetting posting date",
            default: true,
        },
        over_billing_allowance: { type: "Percent", label: "Over Billing Allowance (%)", default: 0 },
        role_allowed_to_over_bill: { type: "Link", label: "Role Allowed to over bill", target: "Role" },
        credit_controller: { type: "Link", label: "Role allowed to bypass credit limit", target: "Role" },
        enable_overdue_billing_threshold: { type: "Check", label: "Prevent Sales Invoice when Customer is Overdue" },
        role_allowed_to_bypass_overdue_billing: {
            type: "Link",
            label: "Role Allowed to Bypass Over Billing Restriction",
            target: "Role",
            dependsOn: (v) => v.enable_overdue_billing_threshold === true,
        },
        determine_address_tax_category_from: {
            type: "Select",
            label: "Determine Address Tax Category from",
            options: ["Billing Address", "Shipping Address"],
            required: true,
            default: "Billing Address",
        },
        add_taxes_from_item_tax_template: {
            type: "Check",
            label: "Automatically add Taxes and Charges from Item Tax Template",
            default: true,
        },
        add_taxes_from_taxes_and_charges_template: {
            type: "Check",
            label: "Automatically add taxes from Taxes and Charges Template",
        },
        round_row_wise_tax: { type: "Check", label: "Round tax amount row-wise" },
        merge_similar_account_heads: { type: "Check", label: "Merge similar Account Heads" },
        show_balance_in_coa: { type: "Check", label: "Show balances in Chart of Accounts", default: true },
        allow_stale: { type: "Check", label: "Allow Stale Exchange Rates", default: true },
        stale_days: { type: "Int", label: "Stale Days", required: true, default: 1 },
        transfer_match_days: { type: "Int", label: "Match transfers within 'N' days", required: true, default: 3 },
        ignore_is_opening_check_for_reporting: { type: "Check", label: "Ignore Is Opening check for reporting" },
        general_ledger_remarks_length: { type: "Int", label: "General Ledger remarks length", required: true, default: 0 },
        receivable_payable_remarks_length: {
            type: "Int",
            label: "Accounts Receivable / Payable remarks length",
            required: true,
            default: 0,
        },
        default_ageing_range: { type: "Data", label: "Default Ageing Range", required: true, default: "30, 60, 90, 120" },
        show_inclusive_tax_in_print: { type: "Check", label: "Show inclusive tax in print" },
        show_payment_schedule_in_print: { type: "Check", label: "Show Payment Schedule in print" },
        show_taxes_as_table_in_print: { type: "Check", label: "Show taxes as table in print" },
        book_asset_depreciation_entry_automatically: {
            type: "Check",
            label: "Book Asset Depreciation entry automatically",
            default: true,
        },
        calculate_depr_using_total_days: {
            type: "Check",
            label: "Calculate daily depreciation using total days in depreciation period",
        },
        role_to_notify_on_depreciation_failure: {
            type: "Link",
            label: "Role to Notify on Depreciation Failure",
            target: "Role",
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    label: "Invoice Cancellation",
                    columns: [["unlink_payment_on_cancellation_of_invoice", "unlink_advance_payment_on_cancelation_of_order"]],
                },
                {
                    label: "Invoice and Billing",
                    columns: [
                        [
                            "check_supplier_invoice_uniqueness",
                            "automatically_fetch_payment_terms",
                            "confirm_before_resetting_posting_date",
                            "over_billing_allowance",
                            "role_allowed_to_over_bill",
                        ],
                        ["credit_controller", "enable_overdue_billing_threshold", "role_allowed_to_bypass_overdue_billing"],
                    ],
                },
                {
                    label: "Tax Settings",
                    columns: [
                        [
                            "determine_address_tax_category_from",
                            "add_taxes_from_item_tax_template",
                            "add_taxes_from_taxes_and_charges_template",
                            "round_row_wise_tax",
                        ],
                    ],
                },
                {
                    label: "Journals",
                    columns: [["merge_similar_account_heads"]],
                },
                {
                    label: "Chart of Accounts",
                    columns: [["show_balance_in_coa"]],
                },
                {
                    label: "Currency Exchange Settings",
                    columns: [["allow_stale", "stale_days"]],
                },
                {
                    label: "Banking",
                    columns: [["transfer_match_days"]],
                },
                {
                    label: "Reports",
                    columns: [
                        [
                            "ignore_is_opening_check_for_reporting",
                            "general_ledger_remarks_length",
                            "receivable_payable_remarks_length",
                            "default_ageing_range",
                        ],
                    ],
                },
                {
                    label: "Print Settings",
                    columns: [["show_inclusive_tax_in_print", "show_payment_schedule_in_print", "show_taxes_as_table_in_print"]],
                },
                {
                    label: "Assets",
                    columns: [
                        [
                            "book_asset_depreciation_entry_automatically",
                            "calculate_depr_using_total_days",
                            "role_to_notify_on_depreciation_failure",
                        ],
                    ],
                },
            ],
        },
    ],
});
