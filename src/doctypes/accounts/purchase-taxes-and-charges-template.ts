import { defineChildDoctype, defineDoctype } from "../define";

const CHARGE = ["Actual", "On Net Total", "On Previous Row Amount", "On Previous Row Total", "On Item Quantity"] as const;

export const purchaseTaxesAndCharges = defineChildDoctype({
    doctype: "Purchase Taxes and Charges",
    table: "purchase_taxes_and_charges",
    fields: {
        category: { type: "Select", label: "Category", options: ["Valuation and Total", "Valuation", "Total"], default: "Total" },
        add_deduct_tax: { type: "Select", label: "Add or Deduct", options: ["Add", "Deduct"], default: "Add" },
        charge_type: { type: "Select", label: "Type", options: CHARGE, default: "On Net Total", required: true },
        row_id: { type: "Int", label: "Row" },
        account_head_id: { type: "Link", label: "Account Head", target: "Account", required: true },
        description: { type: "Data", label: "Description", required: true },
        rate: { type: "Percent", label: "Rate" },
        cost_center_id: { type: "Link", label: "Cost Center", target: "Cost Center" },
        included_in_print_rate: { type: "Check", label: "Included in Print Rate" },
    },
    columns: [
        "category",
        "add_deduct_tax",
        "charge_type",
        "account_head_id",
        "description",
        "rate",
        "row_id",
        "cost_center_id",
        "included_in_print_rate",
    ],
});

export const purchaseTaxesAndChargesTemplate = defineDoctype<"purchase_taxes_and_charges_template", "taxes">({
    doctype: "Purchase Taxes and Charges Template",
    table: "purchase_taxes_and_charges_template",
    module: "accounts",
    slug: "purchase-taxes-and-charges-template",
    titleField: "name",
    fields: {
        title: { type: "Data", label: "Title", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        tax_category_id: { type: "Link", label: "Tax Category", target: "Tax Category" },
        is_default: { type: "Check", label: "Default" },
        disabled: { type: "Check", label: "Disabled" },
        taxes: { type: "Table", label: "Taxes", target: "Purchase Taxes and Charges" },
    },
    children: { taxes: purchaseTaxesAndCharges },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["title", "company_id", "tax_category_id"],
                        ["name", "is_default", "disabled"],
                    ],
                },
                { label: "Taxes", columns: [["taxes"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "company_id", "is_default", "disabled"],
        searchFields: ["name", "title"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "title",
        tax_template_default: "is_default",
        tax_template_category: "tax_category_id",
        tax_account_head: "taxes",
        tax_row_id: "taxes",
        tax_inclusive_actual: "taxes",
        tax_cost_center: "taxes",
    },
});
