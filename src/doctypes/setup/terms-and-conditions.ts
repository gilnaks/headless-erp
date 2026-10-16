import { defineDoctype } from "../define";

/** ERPNext Terms and Conditions. The body uses the same handlebars subset as Email Template. */
export const termsAndConditions = defineDoctype({
    doctype: "Terms and Conditions",
    table: "terms_and_conditions",
    module: "setup",
    slug: "terms-and-conditions",
    titleField: "title",
    fields: {
        title: { type: "Data", label: "Title", required: true },
        disabled: { type: "Check", label: "Disabled" },
        selling: { type: "Check", label: "Selling", default: true },
        buying: { type: "Check", label: "Buying", default: true },
        copy_attachments_to_transaction: { type: "Check", label: "Copy Attachments to Transaction" },
        terms: {
            type: "Text",
            label: "Terms",
            html: true,
            description: "Placeholders: {{doc.field}}. Scripts and event handlers are removed on save.",
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["title", "disabled"],
                        ["selling", "buying", "copy_attachments_to_transaction"],
                    ],
                },
                { columns: [["terms"]] },
            ],
        },
    ],
    listView: {
        columns: ["title", "selling", "buying", "disabled"],
        searchFields: ["title"],
        defaultSort: { field: "title" },
    },
    validate: (values): Record<string, string> => {
        if (!values.disabled && !values.selling && !values.buying) {
            return { selling: "At least one of Selling or Buying must be selected" };
        }
        return {};
    },
    errorFields: { duplicate: "title", terms_module: "selling" },
});
