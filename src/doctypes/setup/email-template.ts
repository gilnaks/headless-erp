import { templateError } from "@/lib/email/render";
import { defineDoctype } from "../define";

const PLACEHOLDERS =
    "Placeholders: {{doc.field}}, {{doc.items[0].field}}, {{company.field}}, {{user.full_name}}; helpers money, date, qty.";

/**
 * Email Template (frappe/email/doctype/email_template, ported from memory: the frappe repo is not cloned). Bodies use
 * the handlebars subset of `src/lib/email/render.ts` instead of Jinja; `validate` rejects templates that do not
 * compile. The HTML body is sanitized on save.
 */
export const emailTemplate = defineDoctype({
    doctype: "Email Template",
    table: "email_template",
    module: "setup",
    slug: "email-template",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Name", required: true, setOnlyOnce: true },
        subject: { type: "Data", label: "Subject", required: true, placeholder: "{{doc.doctype}} {{doc.name}}" },
        use_html: { type: "Check", label: "Use HTML", default: true },
        response_html: {
            type: "Text",
            label: "Response",
            html: true,
            dependsOn: (v) => Boolean(v.use_html),
            description: `${PLACEHOLDERS} Scripts, event handlers and javascript: links are removed on save.`,
        },
        response: {
            type: "Text",
            label: "Response (plain text)",
            dependsOn: (v) => !v.use_html,
            description: PLACEHOLDERS,
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["name", "subject"], ["use_html"]] }, { columns: [["response_html", "response"]] }],
        },
    ],
    listView: {
        columns: ["name", "subject", "use_html"],
        searchFields: ["name", "subject"],
        defaultSort: { field: "name" },
    },
    errorFields: { duplicate: "name" },
    validate: (values) => {
        const errors: Record<string, string> = {};
        for (const field of ["subject", "response_html", "response"]) {
            const error = templateError(values[field]);
            if (error) errors[field] = error;
        }
        return errors;
    },
    preview: "EmailTemplate",
});
