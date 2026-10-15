import { describe, expect, it } from "vitest";
import {
    DEFAULT_PRINT_SETTINGS,
    fontFamilyCss,
    pageSizeCss,
    pickPrintFormat,
    printBlockedReason,
    resolveLetterHeadId,
    showDraftHeading,
} from "./resolve";

describe("resolveLetterHeadId", () => {
    const all = { document: "doc", company: "company", settings: "settings", orgDefault: "org" };

    it("prefers the document, then the company, Print Settings and the org default", () => {
        expect(resolveLetterHeadId(all, true)).toBe("doc");
        expect(resolveLetterHeadId({ ...all, document: null }, true)).toBe("company");
        expect(resolveLetterHeadId({ ...all, document: null, company: null }, true)).toBe("settings");
        expect(resolveLetterHeadId({ orgDefault: "org" }, true)).toBe("org");
        expect(resolveLetterHeadId({}, true)).toBeNull();
    });

    it("prints without a letter head when with_letterhead is off", () => {
        expect(resolveLetterHeadId(all, false)).toBeNull();
    });
});

describe("printBlockedReason", () => {
    it("follows allow_print_for_draft / allow_print_for_cancelled", () => {
        expect(printBlockedReason(0, DEFAULT_PRINT_SETTINGS)).toBeNull();
        expect(printBlockedReason(1, DEFAULT_PRINT_SETTINGS)).toBeNull();
        expect(printBlockedReason(2, DEFAULT_PRINT_SETTINGS)).toBe("Not allowed to print cancelled documents");
        expect(printBlockedReason(0, { allow_print_for_draft: false, allow_print_for_cancelled: false })).toBe(
            "Not allowed to print draft documents",
        );
        expect(printBlockedReason(2, { allow_print_for_draft: true, allow_print_for_cancelled: true })).toBeNull();
    });
});

describe("showDraftHeading", () => {
    it("marks submittable drafts only", () => {
        expect(showDraftHeading(0, true, DEFAULT_PRINT_SETTINGS)).toBe(true);
        expect(showDraftHeading(1, true, DEFAULT_PRINT_SETTINGS)).toBe(false);
        expect(showDraftHeading(0, false, DEFAULT_PRINT_SETTINGS)).toBe(false);
        expect(showDraftHeading(0, true, { add_draft_heading: false })).toBe(false);
    });
});

describe("pageSizeCss", () => {
    it("maps named sizes and Custom dimensions", () => {
        expect(pageSizeCss(DEFAULT_PRINT_SETTINGS)).toBe("A4");
        expect(pageSizeCss({ pdf_page_size: "Letter", pdf_page_height: null, pdf_page_width: null })).toBe("Letter");
        expect(pageSizeCss({ pdf_page_size: "Custom", pdf_page_height: 200, pdf_page_width: 100 })).toBe("100mm 200mm");
        expect(pageSizeCss({ pdf_page_size: "Custom", pdf_page_height: null, pdf_page_width: 100 })).toBe("A4");
    });
});

describe("fontFamilyCss", () => {
    it("falls back to the app font", () => {
        expect(fontFamilyCss("Default")).toContain("--font-inter");
        expect(fontFamilyCss("Arial")).toMatch(/^Arial/);
    });
});

describe("pickPrintFormat", () => {
    const formats = [
        { id: "a", name: "A", template_key: "record", is_default: false, disabled: false },
        { id: "b", name: "B", template_key: "record", is_default: true, disabled: false },
        { id: "c", name: "C", template_key: "record", is_default: false, disabled: true },
    ];

    it("uses the requested enabled format, else the default, else the first enabled", () => {
        expect(pickPrintFormat(formats, "a")?.id).toBe("a");
        expect(pickPrintFormat(formats, "c")?.id).toBe("b");
        expect(pickPrintFormat(formats, null)?.id).toBe("b");
        expect(pickPrintFormat(formats.slice(0, 1))?.id).toBe("a");
        expect(pickPrintFormat([])).toBeNull();
    });
});
