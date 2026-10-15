import { defineDoctype } from "../define";

const ALIGN = ["Left", "Right", "Center"] as const;
const SOURCE = ["HTML", "Image"] as const;

/**
 * Letter Head (frappe/printing/doctype/letter_head, ported from memory: the frappe repo is not cloned). Header and
 * footer are HTML (sanitized on save) or an image in the private `org-files` bucket. Default/disabled rules live in
 * `app.letter_head_validate` (supabase/migrations/0118_setup_letter_head.sql).
 */
export const letterHead = defineDoctype({
    doctype: "Letter Head",
    table: "letter_head",
    module: "setup",
    slug: "letter-head",
    titleField: "letter_head_name",
    fields: {
        letter_head_name: { type: "Data", label: "Letter Head Name", required: true },
        source: { type: "Select", label: "Letter Head Based On", options: SOURCE, required: true, default: "HTML" },
        footer_source: { type: "Select", label: "Footer Based On", options: SOURCE, required: true, default: "HTML" },
        is_default: { type: "Check", label: "Default Letter Head" },
        disabled: { type: "Check", label: "Disabled" },
        content: {
            type: "Text",
            label: "Header HTML",
            html: true,
            dependsOn: (v) => v.source === "HTML",
            description: "Scripts, event handlers and javascript: links are removed on save.",
        },
        image: {
            type: "AttachImage",
            label: "Image",
            folder: "letter-head",
            required: true,
            dependsOn: (v) => v.source === "Image",
        },
        image_height: { type: "Float", label: "Image Height (px)", dependsOn: (v) => v.source === "Image" },
        image_width: { type: "Float", label: "Image Width (px)", dependsOn: (v) => v.source === "Image" },
        align: { type: "Select", label: "Align", options: ALIGN, required: true, default: "Left", dependsOn: (v) => v.source === "Image" },
        footer: {
            type: "Text",
            label: "Footer HTML",
            html: true,
            dependsOn: (v) => v.footer_source === "HTML",
            description: "Scripts, event handlers and javascript: links are removed on save.",
        },
        footer_image: {
            type: "AttachImage",
            label: "Footer Image",
            folder: "letter-head",
            dependsOn: (v) => v.footer_source === "Image",
        },
        footer_image_height: { type: "Float", label: "Footer Image Height (px)", dependsOn: (v) => v.footer_source === "Image" },
        footer_image_width: { type: "Float", label: "Footer Image Width (px)", dependsOn: (v) => v.footer_source === "Image" },
        footer_align: {
            type: "Select",
            label: "Footer Align",
            options: ALIGN,
            required: true,
            default: "Left",
            dependsOn: (v) => v.footer_source === "Image",
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["letter_head_name", "source", "footer_source"],
                        ["is_default", "disabled"],
                    ],
                },
                {
                    label: "Letter Head",
                    columns: [
                        ["content", "image"],
                        ["image_height", "image_width", "align"],
                    ],
                },
                {
                    label: "Footer",
                    columns: [
                        ["footer", "footer_image"],
                        ["footer_image_height", "footer_image_width", "footer_align"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["letter_head_name", "source", "is_default", "disabled"],
        searchFields: ["letter_head_name"],
        defaultSort: { field: "letter_head_name" },
    },
    errorFields: { duplicate: "letter_head_name", letter_head_disabled_default: "disabled" },
    preview: "LetterHead",
});
