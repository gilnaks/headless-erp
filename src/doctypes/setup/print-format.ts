import { TEMPLATE_KEYS } from "@/print/template-keys";
import { defineDoctype } from "../define";

/**
 * Print Format registry (Frappe Print Format, ported from memory: the frappe repo is not cloned). Each row picks a
 * server-rendered template (`src/print/registry.tsx`) for a doctype; "<Doctype> Standard" rows are seeded per
 * organization and only their Default / Disabled flags change (supabase/migrations/0120_setup_print_format.sql).
 */
export const printFormat = defineDoctype({
    doctype: "Print Format",
    table: "print_format",
    module: "setup",
    slug: "print-format",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Name", required: true, setOnlyOnce: true },
        doc_type: { type: "Select", label: "DocType", options: "DocType", required: true, setOnlyOnce: true },
        template_key: {
            type: "Select",
            label: "Template",
            options: TEMPLATE_KEYS,
            required: true,
            default: "record",
            description: "record = every field of the document laid out like its form.",
        },
        is_standard: { type: "Check", label: "Standard", readOnly: true },
        is_default: { type: "Check", label: "Default", description: "Used when printing this DocType unless another format is picked." },
        disabled: { type: "Check", label: "Disabled" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["name", "doc_type", "template_key"],
                        ["is_standard", "is_default", "disabled"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "doc_type", "template_key", "is_default", "disabled"],
        searchFields: ["name", "doc_type"],
        defaultSort: { field: "doc_type" },
    },
    errorFields: {
        duplicate: "name",
        print_format_standard: "template_key",
        print_format_disabled_default: "disabled",
        print_format_doc_type: "doc_type",
    },
});
