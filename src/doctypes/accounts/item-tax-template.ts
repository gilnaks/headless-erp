import { defineChildDoctype, defineDoctype } from "../define";

export const itemTaxTemplateDetail = defineChildDoctype({
    doctype: "Item Tax Template Detail",
    table: "item_tax_template_detail",
    fields: {
        tax_type_id: { type: "Link", label: "Tax", target: "Account", required: true },
        tax_rate: { type: "Percent", label: "Tax Rate" },
        not_applicable: { type: "Check", label: "Not Applicable" },
    },
    columns: ["tax_type_id", "tax_rate", "not_applicable"],
});

export const itemTaxTemplate = defineDoctype<"item_tax_template", "taxes">({
    doctype: "Item Tax Template",
    table: "item_tax_template",
    module: "accounts",
    slug: "item-tax-template",
    titleField: "name",
    fields: {
        title: { type: "Data", label: "Title", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        disabled: { type: "Check", label: "Disabled" },
        taxes: { type: "Table", label: "Tax Rates", target: "Item Tax Template Detail", required: true },
    },
    children: { taxes: itemTaxTemplateDetail },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["title", "company_id", "disabled"], ["name"]] }, { label: "Tax Rates", columns: [["taxes"]] }],
        },
    ],
    listView: {
        columns: ["name", "company_id", "disabled"],
        searchFields: ["name", "title"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "title",
        item_tax_company: "taxes",
        item_tax_type: "taxes",
        item_tax_duplicate: "taxes",
        item_tax_rows: "taxes",
    },
});
