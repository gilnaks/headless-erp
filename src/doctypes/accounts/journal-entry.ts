import { defineChildDoctype, defineDoctype } from "../define";

const VOUCHER_TYPES = [
    "Journal Entry",
    "Bank Entry",
    "Cash Entry",
    "Credit Card Entry",
    "Debit Note",
    "Credit Note",
    "Contra Entry",
    "Excise Entry",
    "Write Off Entry",
    "Opening Entry",
] as const;

function today(): string {
    const date = new Date();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

function money(value: unknown): number {
    const n = typeof value === "number" ? value : Number(value);
    return Number.isFinite(n) ? n : 0;
}

export const journalEntryAccount = defineChildDoctype({
    doctype: "Journal Entry Account",
    table: "journal_entry_account",
    fields: {
        account_id: { type: "Link", label: "Account", target: "Account", required: true },
        debit: { type: "Currency", label: "Debit" },
        credit: { type: "Currency", label: "Credit" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
        party_type: { type: "Select", label: "Party Type", options: ["Customer", "Supplier"] },
        party_id: { type: "DynamicLink", label: "Party", optionsField: "party_type" },
        is_advance: { type: "Select", label: "Is Advance", options: ["No", "Yes"], default: "No" },
        user_remark: { type: "Data", label: "User Remark" },
        reference_type: {
            type: "Select",
            label: "Reference Type",
            options: ["Sales Invoice", "Purchase Invoice", "Journal Entry", "Sales Order", "Purchase Order"],
        },
        reference_id: { type: "Data", label: "Reference Name" },
        against_account: { type: "Data", label: "Against Account", readOnly: true },
    },
    columns: ["account_id", "debit", "credit", "cost_center_id", "party_type", "party_id"],
});

/** ERPNext Journal Entry. Submit posts one general-ledger row per account line. */
export const journalEntry = defineDoctype<"journal_entry", "accounts">({
    doctype: "Journal Entry",
    table: "journal_entry",
    module: "accounts",
    slug: "journal-entry",
    titleField: "title",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        title: { type: "Data", label: "Title", readOnly: true },
        voucher_type: { type: "Select", label: "Voucher Type", options: VOUCHER_TYPES, required: true, default: "Journal Entry" },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "ACC-JV-.YYYY.-" },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        posting_date: { type: "Date", label: "Posting Date", required: true, default: today() },
        accounts: { type: "Table", label: "Accounts", target: "Journal Entry Account", required: true },
        cheque_no: {
            type: "Data",
            label: "Reference No",
            dependsOn: (values) => values.voucher_type === "Bank Entry",
            required: true,
        },
        cheque_date: {
            type: "Date",
            label: "Reference Date",
            dependsOn: (values) => values.voucher_type === "Bank Entry",
            required: true,
        },
        user_remark: { type: "Text", label: "User Remark" },
        total_debit: { type: "Currency", label: "Total Debit", readOnly: true },
        total_credit: { type: "Currency", label: "Total Credit", readOnly: true },
        difference: { type: "Currency", label: "Difference", readOnly: true },
        multi_currency: { type: "Check", label: "Multi Currency", readOnly: true, default: false },
        is_opening: { type: "Select", label: "Is Opening", options: ["No", "Yes"], default: "No" },
        bill_no: { type: "Data", label: "Bill No" },
        bill_date: { type: "Date", label: "Bill Date" },
        due_date: { type: "Date", label: "Due Date" },
        write_off_based_on: {
            type: "Select",
            label: "Write Off Based On",
            options: ["Accounts Receivable", "Accounts Payable"],
            default: "Accounts Receivable",
        },
        write_off_amount: { type: "Currency", label: "Write Off Amount" },
        pay_to_recd_from: { type: "Data", label: "Pay To / Recd From" },
        mode_of_payment_id: { type: "Link", label: "Mode of Payment", target: "Mode of Payment" },
        letter_head_id: { type: "Link", label: "Letter Head", target: "Letter Head" },
        print_heading_id: { type: "Link", label: "Print Heading", target: "Print Heading" },
        reversal_of: { type: "Link", label: "Reversal Of", target: "Journal Entry", readOnly: true },
        clearance_date: { type: "Date", label: "Clearance Date" },
        custom_remark: { type: "Check", label: "Custom Remark" },
    },
    children: { accounts: journalEntryAccount },
    triggers: {
        accounts: (values) => {
            const rows = Array.isArray(values.accounts) ? values.accounts : [];
            const debit = rows.reduce((sum, row) => sum + money(row.debit), 0);
            const credit = rows.reduce((sum, row) => sum + money(row.credit), 0);
            return { total_debit: String(debit), total_credit: String(credit), difference: String(debit - credit) };
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["voucher_type", "company_id", "posting_date", "naming_series"],
                        ["cheque_no", "cheque_date", "is_opening", "pay_to_recd_from"],
                    ],
                },
                { label: "Accounts", columns: [["accounts"]] },
                {
                    columns: [
                        ["total_debit", "total_credit", "difference"],
                        ["user_remark", "custom_remark"],
                    ],
                },
            ],
        },
        {
            label: "More",
            sections: [
                {
                    columns: [
                        ["bill_no", "bill_date", "due_date", "write_off_based_on", "write_off_amount"],
                        [
                            "mode_of_payment_id",
                            "letter_head_id",
                            "print_heading_id",
                            "clearance_date",
                            "reversal_of",
                            "name",
                            "title",
                            "multi_currency",
                        ],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["title", "voucher_type", "posting_date", "total_debit", "company_id"],
        searchFields: ["title", "voucher_type", "name", "cheque_no"],
        defaultSort: { field: "posting_date", desc: true },
    },
    errorFields: {
        je_accounts: "accounts",
        je_difference: "difference",
        je_zero: "accounts",
        je_same_account: "accounts",
        je_party: "accounts",
        je_party_type: "accounts",
        je_reference: "cheque_no",
        je_stock: "accounts",
        je_account: "accounts",
        gl_unbalanced: "difference",
        gl_opening_pl: "accounts",
        gl_round_off_opening: "accounts",
        gl_frozen: "posting_date",
        fiscal_year: "posting_date",
        update_after_submit: "user_remark",
        cancelled_readonly: "name",
    },
});
