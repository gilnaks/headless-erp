import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { FieldValues } from "../define";
import { defineChildDoctype, defineDoctype } from "../define";

const PAYMENT_TYPES = ["Receive", "Pay", "Internal Transfer"] as const;
const PARTY_TYPES = ["Customer", "Supplier"] as const;
const REFERENCE_DOCTYPES = [
    "Sales Invoice",
    "Purchase Invoice",
    "Journal Entry",
    "Sales Order",
    "Purchase Order",
    "Payment Entry",
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

function text(value: unknown): string {
    return typeof value === "string" ? value : "";
}

function partyVisible(values: FieldValues): boolean {
    return values.payment_type !== "Internal Transfer";
}

/** Draft preview. Postgres recomputes the same amounts on save and submit. */
function preview(values: FieldValues): FieldValues {
    const paid = money(values.paid_amount);
    const received = money(values.received_amount);
    const rows = Array.isArray(values.references) ? values.references : [];
    const deductions = Array.isArray(values.deductions) ? values.deductions : [];
    const allocated = Math.abs(rows.reduce((sum, row) => sum + money(row.allocated_amount), 0));
    const deducted = deductions.reduce((sum, row) => sum + money(row.amount), 0);
    const type = values.payment_type;
    let unallocated = 0;
    if (values.party_id && type === "Receive" && allocated < paid + deducted) unallocated = paid + deducted - allocated;
    else if (values.party_id && type === "Pay" && allocated < received - deducted) unallocated = received - deducted - allocated;
    const difference =
        type === "Receive"
            ? allocated + unallocated - received - deducted
            : type === "Pay"
              ? paid - (allocated + unallocated) - deducted
              : paid - received - deducted;
    return {
        total_allocated_amount: String(allocated),
        base_total_allocated_amount: String(allocated),
        unallocated_amount: String(unallocated),
        difference_amount: String(difference),
        base_paid_amount: String(paid),
        base_received_amount: String(received),
    };
}

function withPaidCopy(values: FieldValues): FieldValues {
    const received = text(values.received_amount) ? values.received_amount : values.paid_amount;
    return { ...preview({ ...values, received_amount: received }), received_amount: received };
}

async function getOutstandingInvoices(values: FieldValues): Promise<FieldValues> {
    if (!partyVisible(values)) throw new Error("Internal Transfer has no outstanding invoices.");
    const company = text(values.company_id);
    const partyType = text(values.party_type);
    const party = text(values.party_id);
    const account = text(values.payment_type === "Pay" ? values.paid_to_account_id : values.paid_from_account_id);
    if (!company || !partyType || !party || !account) throw new Error("Set the company, party and party account first.");
    const amount = money(values.payment_type === "Pay" ? values.received_amount : values.paid_amount);
    const { data, error } = await createClient().rpc("get_outstanding_reference_documents", {
        p_company: company,
        p_party_type: partyType,
        p_party: party,
        p_account: account,
        p_amount: amount,
    });
    if (error) throw new Error(dbError(error).message);
    const rows = Array.isArray(data) ? data : [];
    return {
        references: rows.map((row) => {
            const item = row as Record<string, unknown>;
            return {
                reference_doctype: text(item.reference_doctype) || "Journal Entry",
                reference_id: text(item.reference_id),
                due_date: text(item.due_date),
                total_amount: String(item.total_amount ?? ""),
                outstanding_amount: String(item.outstanding_amount ?? ""),
                allocated_amount: String(item.allocated_amount ?? ""),
                account_id: text(item.account_id),
            };
        }),
        ...preview({ ...values, references: rows }),
    };
}

export const paymentEntryReference = defineChildDoctype({
    doctype: "Payment Entry Reference",
    table: "payment_entry_reference",
    fields: {
        reference_doctype: { type: "Select", label: "Type", options: REFERENCE_DOCTYPES, required: true, default: "Journal Entry" },
        reference_id: { type: "Data", label: "Reference Name", required: true },
        due_date: { type: "Date", label: "Due Date" },
        account_id: { type: "Link", label: "Account", target: "Account" },
        total_amount: { type: "Currency", label: "Total", readOnly: true },
        outstanding_amount: { type: "Currency", label: "Outstanding", readOnly: true },
        allocated_amount: { type: "Currency", label: "Allocated" },
    },
    columns: ["reference_doctype", "reference_id", "due_date", "account_id", "total_amount", "outstanding_amount", "allocated_amount"],
});

export const paymentEntryDeduction = defineChildDoctype({
    doctype: "Payment Entry Deduction",
    table: "payment_entry_deduction",
    fields: {
        account_id: { type: "Link", label: "Account", target: "Account", required: true },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center", required: true },
        amount: { type: "Currency", label: "Amount", required: true },
        description: { type: "Data", label: "Description" },
    },
    columns: ["account_id", "cost_center_id", "amount", "description"],
});

/** ERPNext Payment Entry. Submit posts the bank, party and deduction rows. */
export const paymentEntry = defineDoctype<"payment_entry", "references" | "deductions">({
    doctype: "Payment Entry",
    table: "payment_entry",
    module: "accounts",
    slug: "payment-entry",
    titleField: "title",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        title: { type: "Data", label: "Title", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "ACC-PAY-.YYYY.-" },
        payment_type: { type: "Select", label: "Payment Type", options: PAYMENT_TYPES, required: true, default: "Receive" },
        posting_date: { type: "Date", label: "Posting Date", required: true, default: today() },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        mode_of_payment_id: { type: "Link", label: "Mode of Payment", target: "Mode of Payment" },
        party_type: { type: "Select", label: "Party Type", options: PARTY_TYPES, required: true, dependsOn: partyVisible },
        party_id: { type: "DynamicLink", label: "Party", optionsField: "party_type", required: true, dependsOn: partyVisible },
        party_name: { type: "Data", label: "Party Name", readOnly: true, dependsOn: partyVisible },
        party_balance: { type: "Currency", label: "Party Balance", readOnly: true, dependsOn: partyVisible },
        paid_from_account_id: { type: "Link", label: "Paid From", target: "Account", required: true },
        paid_from_account_currency: { type: "Data", label: "Paid From Currency", readOnly: true },
        paid_from_account_type: { type: "Data", label: "Paid From Account Type", readOnly: true },
        paid_from_account_balance: { type: "Currency", label: "Paid From Balance", readOnly: true },
        paid_to_account_id: { type: "Link", label: "Paid To", target: "Account", required: true },
        paid_to_account_currency: { type: "Data", label: "Paid To Currency", readOnly: true },
        paid_to_account_type: { type: "Data", label: "Paid To Account Type", readOnly: true },
        paid_to_account_balance: { type: "Currency", label: "Paid To Balance", readOnly: true },
        paid_amount: { type: "Currency", label: "Paid Amount", required: true },
        source_exchange_rate: { type: "Currency", label: "Source Exchange Rate", readOnly: true, default: 1 },
        base_paid_amount: { type: "Currency", label: "Base Paid Amount", readOnly: true },
        received_amount: { type: "Currency", label: "Received Amount" },
        target_exchange_rate: { type: "Currency", label: "Target Exchange Rate", readOnly: true, default: 1 },
        base_received_amount: { type: "Currency", label: "Base Received Amount", readOnly: true },
        references: { type: "Table", label: "References", target: "Payment Entry Reference", dependsOn: partyVisible },
        total_allocated_amount: { type: "Currency", label: "Total Allocated", readOnly: true },
        base_total_allocated_amount: { type: "Currency", label: "Base Total Allocated", readOnly: true },
        unallocated_amount: { type: "Currency", label: "Unallocated", readOnly: true },
        difference_amount: { type: "Currency", label: "Difference", readOnly: true },
        deductions: { type: "Table", label: "Deductions", target: "Payment Entry Deduction" },
        reference_no: { type: "Data", label: "Reference No" },
        reference_date: { type: "Date", label: "Reference Date" },
        clearance_date: { type: "Date", label: "Clearance Date" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
        contact_person_id: { type: "Link", label: "Contact", target: "Contact", dependsOn: partyVisible },
        contact_email: { type: "Data", label: "Contact Email", dependsOn: partyVisible },
        remarks: { type: "Text", label: "Remarks" },
        custom_remarks: { type: "Check", label: "Custom Remarks" },
        is_opening: { type: "Select", label: "Is Opening", options: ["No", "Yes"], default: "No" },
        status: { type: "Data", label: "Status", readOnly: true },
    },
    children: { references: paymentEntryReference, deductions: paymentEntryDeduction },
    triggers: {
        payment_type: (values) =>
            values.payment_type === "Internal Transfer"
                ? { party_type: "", party_id: "", party_name: "", references: [], ...preview({ ...values, party_id: "", references: [] }) }
                : preview(values),
        paid_amount: withPaidCopy,
        received_amount: (values) => preview(values),
        references: (values) => preview(values),
        deductions: (values) => preview(values),
        party_id: (values) => preview(values),
    },
    actions: [{ id: "get-outstanding", label: "Get Outstanding Invoices", run: getOutstandingInvoices }],
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["payment_type", "company_id", "posting_date", "mode_of_payment_id"],
                        ["party_type", "party_id", "party_name", "party_balance"],
                    ],
                },
                {
                    label: "Accounts",
                    columns: [
                        [
                            "paid_from_account_id",
                            "paid_from_account_type",
                            "paid_from_account_currency",
                            "paid_from_account_balance",
                            "paid_amount",
                            "source_exchange_rate",
                        ],
                        [
                            "paid_to_account_id",
                            "paid_to_account_type",
                            "paid_to_account_currency",
                            "paid_to_account_balance",
                            "received_amount",
                            "target_exchange_rate",
                        ],
                    ],
                },
                { label: "References", columns: [["references"]] },
                { label: "Deductions", columns: [["deductions"]] },
                {
                    columns: [
                        ["total_allocated_amount", "unallocated_amount", "difference_amount", "base_paid_amount", "base_received_amount"],
                        ["reference_no", "reference_date", "remarks", "custom_remarks"],
                    ],
                },
            ],
        },
        {
            label: "More",
            sections: [
                {
                    columns: [
                        ["cost_center_id", "clearance_date", "contact_person_id", "contact_email", "is_opening"],
                        ["name", "title", "naming_series", "status", "base_total_allocated_amount"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["title", "payment_type", "posting_date", "paid_from_account_id", "paid_to_account_id", "status"],
        searchFields: ["title", "name", "reference_no", "party_name"],
        defaultSort: { field: "posting_date", desc: true },
    },
    errorFields: {
        pe_difference: "difference_amount",
        pe_reference: "reference_no",
        pe_party: "party_id",
        pe_party_account: "paid_from_account_id",
        pe_accounts: "paid_from_account_id",
        pe_bank: "paid_to_account_id",
        pe_amount: "paid_amount",
        pe_allocated: "references",
        pe_references: "references",
        pe_duplicate: "references",
        pe_deduction: "deductions",
        pe_supplier_hold: "party_id",
        fiscal_year: "posting_date",
        gl_unbalanced: "difference_amount",
        gl_frozen: "posting_date",
        gl_entries: "paid_amount",
        docstatus_locked: "status",
        update_after_submit: "remarks",
        cancelled_readonly: "name",
    },
});
