import { defineDoctype } from "../define";

const DUE = [
    "Day(s) after invoice date",
    "Day(s) after the end of the invoice month",
    "Month(s) after the end of the invoice month",
] as const;

/** ERPNext Payment Term. The name is the trimmed payment term name. */
export const paymentTerm = defineDoctype({
    doctype: "Payment Term",
    table: "payment_term",
    module: "accounts",
    slug: "payment-term",
    titleField: "name",
    fields: {
        payment_term_name: { type: "Data", label: "Payment Term Name", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        invoice_portion: { type: "Percent", label: "Invoice Portion" },
        mode_of_payment_id: { type: "Link", label: "Mode of Payment", target: "Mode of Payment" },
        due_date_based_on: { type: "Select", label: "Due Date Based On", options: ["", ...DUE] },
        credit_days: { type: "Int", label: "Credit Days", default: 0 },
        credit_months: { type: "Int", label: "Credit Months", default: 0 },
        discount_type: { type: "Select", label: "Discount Type", options: ["Percentage", "Amount"], default: "Percentage" },
        discount: { type: "Float", label: "Discount" },
        discount_validity_based_on: {
            type: "Select",
            label: "Discount Validity Based On",
            options: DUE,
            default: DUE[0],
        },
        discount_validity: { type: "Int", label: "Discount Validity" },
        description: { type: "Text", label: "Description" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["payment_term_name", "invoice_portion", "mode_of_payment_id", "due_date_based_on", "credit_days", "credit_months"],
                        ["name", "discount_type", "discount", "discount_validity_based_on", "discount_validity", "description"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "invoice_portion", "due_date_based_on", "credit_days"],
        searchFields: ["name", "payment_term_name"],
        defaultSort: { field: "name" },
    },
    errorFields: { duplicate: "payment_term_name" },
});
