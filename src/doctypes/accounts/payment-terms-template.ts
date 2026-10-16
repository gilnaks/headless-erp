import { defineChildDoctype, defineDoctype } from "../define";

const DUE = [
    "Day(s) after invoice date",
    "Day(s) after the end of the invoice month",
    "Month(s) after the end of the invoice month",
] as const;

export const paymentTermsTemplateDetail = defineChildDoctype({
    doctype: "Payment Terms Template Detail",
    table: "payment_terms_template_detail",
    fields: {
        payment_term_id: { type: "Link", label: "Payment Term", target: "Payment Term" },
        description: { type: "Data", label: "Description" },
        invoice_portion: { type: "Percent", label: "Invoice Portion", required: true },
        due_date_based_on: { type: "Select", label: "Due Date Based On", options: DUE, default: DUE[0], required: true },
        credit_days: { type: "Int", label: "Credit Days", default: 0 },
        credit_months: { type: "Int", label: "Credit Months", default: 0 },
        mode_of_payment_id: { type: "Link", label: "Mode of Payment", target: "Mode of Payment" },
        discount_type: { type: "Select", label: "Discount Type", options: ["Percentage", "Amount"], default: "Percentage" },
        discount: { type: "Float", label: "Discount" },
        discount_validity_based_on: { type: "Select", label: "Discount Validity Based On", options: ["", ...DUE] },
        discount_validity: { type: "Int", label: "Discount Validity" },
    },
    columns: [
        "payment_term_id",
        "description",
        "invoice_portion",
        "due_date_based_on",
        "credit_days",
        "credit_months",
        "mode_of_payment_id",
        "discount_type",
        "discount",
        "discount_validity_based_on",
        "discount_validity",
    ],
});

/** ERPNext Payment Terms Template. Row portions must add to 100%. */
export const paymentTermsTemplate = defineDoctype<"payment_terms_template", "terms">({
    doctype: "Payment Terms Template",
    table: "payment_terms_template",
    module: "accounts",
    slug: "payment-terms-template",
    titleField: "name",
    fields: {
        template_name: { type: "Data", label: "Template Name", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        allocate_payment_based_on_payment_terms: { type: "Check", label: "Allocate Payment Based On Payment Terms" },
        terms: { type: "Table", label: "Terms", target: "Payment Terms Template Detail", required: true },
    },
    children: { terms: paymentTermsTemplateDetail },
    tabs: [
        {
            label: "Details",
            sections: [
                { columns: [["template_name", "allocate_payment_based_on_payment_terms"], ["name"]] },
                { label: "Terms", columns: [["terms"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "allocate_payment_based_on_payment_terms"],
        searchFields: ["name", "template_name"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "template_name",
        payment_terms_portion: "terms",
        payment_term_required: "terms",
        payment_term_duplicate: "terms",
    },
});
