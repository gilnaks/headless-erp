/** Pure print rules (Frappe `frappe.www.printview`), shared by the print route and Vitest. */

export type PrintSettingsLike = {
    with_letterhead: boolean;
    letter_head_id: string | null;
    allow_print_for_draft: boolean;
    allow_print_for_cancelled: boolean;
    add_draft_heading: boolean;
    pdf_page_size: string;
    pdf_page_height: number | null;
    pdf_page_width: number | null;
    font_size: number;
    font: string;
};

/** Frappe Print Settings defaults (used when the settings row cannot be read). */
export const DEFAULT_PRINT_SETTINGS: PrintSettingsLike = {
    with_letterhead: true,
    letter_head_id: null,
    allow_print_for_draft: true,
    allow_print_for_cancelled: false,
    add_draft_heading: true,
    pdf_page_size: "A4",
    pdf_page_height: null,
    pdf_page_width: null,
    font_size: 9,
    font: "Default",
};

export type LetterHeadCandidates = {
    /** The document's own `letter_head_id` (transactions). */
    document?: string | null;
    /** `companies.default_letter_head_id` of the document's company. */
    company?: string | null;
    /** Print Settings `letter_head_id`. */
    settings?: string | null;
    /** The organization's default letter head (`is_default`). */
    orgDefault?: string | null;
};

/**
 * Letter head for a print: none when Print Settings has `with_letterhead` off, else the first of document → company
 * default → Print Settings → organization default.
 */
export function resolveLetterHeadId(candidates: LetterHeadCandidates, withLetterhead: boolean): string | null {
    if (!withLetterhead) return null;
    return candidates.document || candidates.company || candidates.settings || candidates.orgDefault || null;
}

/** Frappe `validate_print_permission` for docstatus: the message when printing is not allowed, else null. */
export function printBlockedReason(
    docstatus: number,
    settings: Pick<PrintSettingsLike, "allow_print_for_draft" | "allow_print_for_cancelled">,
) {
    if (docstatus === 0 && !settings.allow_print_for_draft) return "Not allowed to print draft documents";
    if (docstatus === 2 && !settings.allow_print_for_cancelled) return "Not allowed to print cancelled documents";
    return null;
}

/** Draft heading (`add_draft_heading`) on submittable drafts only, as Frappe prints "Draft" for docstatus 0. */
export function showDraftHeading(docstatus: number, submittable: boolean, settings: Pick<PrintSettingsLike, "add_draft_heading">): boolean {
    return submittable && docstatus === 0 && settings.add_draft_heading;
}

/** CSS `@page { size }` for the PDF page size (Custom = width × height in mm). */
export function pageSizeCss(settings: Pick<PrintSettingsLike, "pdf_page_size" | "pdf_page_height" | "pdf_page_width">): string {
    if (settings.pdf_page_size === "Custom" && settings.pdf_page_width && settings.pdf_page_height) {
        return `${settings.pdf_page_width}mm ${settings.pdf_page_height}mm`;
    }
    return ["A4", "Letter", "Legal"].includes(settings.pdf_page_size) ? settings.pdf_page_size : "A4";
}

const FONTS: Record<string, string> = {
    "Helvetica Neue": '"Helvetica Neue", Helvetica, Arial, sans-serif',
    Arial: "Arial, Helvetica, sans-serif",
    Helvetica: "Helvetica, Arial, sans-serif",
    Inter: "var(--font-inter), Inter, sans-serif",
    Verdana: "Verdana, Geneva, sans-serif",
    Monospace: "ui-monospace, SFMono-Regular, Menlo, monospace",
};

/** CSS font stack for the Print Settings `font` ("Default" = the app font). */
export function fontFamilyCss(font: string): string {
    return FONTS[font] ?? "var(--font-inter), system-ui, sans-serif";
}

export type PrintFormatLike = { id: string; name: string; template_key: string; is_default: boolean; disabled: boolean };

/** The requested format when it exists and is enabled, else the doctype's default, else the first enabled one. */
export function pickPrintFormat<T extends PrintFormatLike>(formats: T[], requestedId?: string | null): T | null {
    const enabled = formats.filter((f) => !f.disabled);
    return enabled.find((f) => f.id === requestedId) ?? enabled.find((f) => f.is_default) ?? enabled[0] ?? null;
}
