import { defineDoctype } from "../define";

/**
 * Print Settings (Frappe single, ported from memory: the frappe repo is not cloned) plus ERPNext's custom fields from
 * erpnext/setup/install.py `create_print_setting_custom_fields`. Seeded with the organization by
 * supabase/migrations/0119_setup_print_settings.sql; applied by the print route.
 */
export const printSettings = defineDoctype({
    doctype: "Print Settings",
    table: "print_settings",
    module: "setup",
    slug: "print-settings",
    single: true,
    fields: {
        send_print_as_pdf: {
            type: "Check",
            label: "Send Print as PDF",
            description: "Send document print as a PDF attachment when emailing.",
        },
        attach_view_link: { type: "Check", label: "Send document web view link in email", default: true },
        repeat_header_footer: { type: "Check", label: "Repeat Header and Footer", default: true },
        pdf_page_size: {
            type: "Select",
            label: "PDF Page Size",
            options: ["A4", "Letter", "Legal", "Custom"],
            required: true,
            default: "A4",
        },
        pdf_page_height: {
            type: "Float",
            label: "PDF Page Height (in mm)",
            required: true,
            dependsOn: (v) => v.pdf_page_size === "Custom",
        },
        pdf_page_width: {
            type: "Float",
            label: "PDF Page Width (in mm)",
            required: true,
            dependsOn: (v) => v.pdf_page_size === "Custom",
        },
        with_letterhead: { type: "Check", label: "Print with letterhead", default: true },
        letter_head_id: {
            type: "Link",
            label: "Default Letter Head",
            target: "Letter Head",
            description: "Used when the document and its company have none; empty = the organization's default letter head.",
        },
        compact_item_print: { type: "Check", label: "Compact Item Print", default: true },
        print_uom_after_quantity: { type: "Check", label: "Print UOM after Quantity" },
        allow_print_for_draft: { type: "Check", label: "Allow Print for Draft", default: true },
        add_draft_heading: { type: "Check", label: 'Always add "Draft" Heading for printing draft documents', default: true },
        allow_page_break_inside_tables: { type: "Check", label: "Allow page break inside tables" },
        allow_print_for_cancelled: { type: "Check", label: "Allow Print for Cancelled" },
        print_taxes_with_zero_amount: { type: "Check", label: "Print taxes with zero amount" },
        print_style: { type: "Select", label: "Print Style", options: ["Modern"], required: true, default: "Modern" },
        font: {
            type: "Select",
            label: "Font",
            options: ["Default", "Helvetica Neue", "Arial", "Helvetica", "Inter", "Verdana", "Monospace"],
            required: true,
            default: "Default",
        },
        font_size: { type: "Float", label: "Font Size", required: true, default: 9, description: "In points (6-24)." },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    label: "PDF Settings",
                    columns: [
                        ["send_print_as_pdf", "attach_view_link", "repeat_header_footer"],
                        ["pdf_page_size", "pdf_page_height", "pdf_page_width"],
                    ],
                },
                {
                    label: "Page Settings",
                    columns: [
                        ["with_letterhead", "letter_head_id", "compact_item_print", "print_uom_after_quantity"],
                        [
                            "allow_print_for_draft",
                            "add_draft_heading",
                            "allow_page_break_inside_tables",
                            "allow_print_for_cancelled",
                            "print_taxes_with_zero_amount",
                        ],
                    ],
                },
                { label: "Print Style", columns: [["print_style", "font", "font_size"]] },
            ],
        },
    ],
});
