import { describe, expect, it } from "vitest";
import { compileTemplate, renderTemplate, templateError } from "./render";
import { APP_TEMPLATES } from "./templates";

const context = {
    doc: {
        doctype: "Sales Invoice",
        name: "ACC-SINV-2026-00001",
        customer_name: 'Smith & Sons <"Ltd">',
        grand_total: "1234.5",
        currency: "EUR",
        posting_date: "2026-10-15",
        is_return: false,
        items: [{ item_code: "WIDGET", qty: 2.5 }],
    },
    company: { company_name: "Acme", default_currency: "USD" },
    user: { full_name: "Jane Doe" },
};

describe("renderTemplate", () => {
    it("fills doc, child-row, company and user values", () => {
        expect(renderTemplate("{{doc.name}} / {{doc.items[0].item_code}} / {{company.company_name}} / {{user.full_name}}", context)).toBe(
            "ACC-SINV-2026-00001 / WIDGET / Acme / Jane Doe",
        );
    });

    it("escapes values in HTML output only", () => {
        expect(renderTemplate("<p>{{doc.customer_name}}</p>", context, { html: true })).toBe(
            "<p>Smith &amp; Sons &lt;&quot;Ltd&quot;&gt;</p>",
        );
        expect(renderTemplate("{{doc.customer_name}}", context)).toBe('Smith & Sons <"Ltd">');
    });

    it("formats with money, date and qty", () => {
        expect(renderTemplate("{{money doc.grand_total}}", context)).toBe("€1,234.50");
        expect(renderTemplate("{{money doc.grand_total}}", { ...context, doc: { grand_total: 10 } })).toBe("$10.00");
        expect(renderTemplate("{{date doc.posting_date}}", context)).toBe("Oct 15, 2026");
        expect(renderTemplate("{{qty doc.items[0].qty}}", context)).toBe("2.5");
    });

    it("renders missing values, objects and non-numbers as empty", () => {
        expect(renderTemplate("[{{doc.nope}}][{{doc.items[3].qty}}][{{doc.items}}][{{money doc.customer_name}}]", context)).toBe(
            "[][][][]",
        );
        expect(renderTemplate("{{doc.is_return}}", context)).toBe("No");
    });

    it("allows whitespace inside tags", () => {
        expect(renderTemplate("{{  money   doc.grand_total }}", context)).toBe("€1,234.50");
    });
});

describe("compileTemplate", () => {
    it.each([
        ["{{doc.name", 'Unclosed "{{"'],
        ["{{doc.name {{doc.x}}", 'Unclosed "{{"'],
        ["doc.name}}", 'Unmatched "}}"'],
        ["{{upper doc.name}}", 'Unknown helper "upper" in {{upper doc.name}} (use money, date, qty)'],
        ["{{#each doc.items}}", 'Unknown helper "#each" in {{#each doc.items}} (use money, date, qty)'],
        ["{{doc.items[x]}}", "Invalid placeholder {{doc.items[x]}}"],
        ["{{frappe.db}}", 'Unknown value "frappe" in {{frappe.db}} (use doc, company or user)'],
        ["{{doc.name | upper}}", "Unsupported placeholder {{doc.name | upper}}"],
        ["{{ }}", "Empty placeholder {{ }}"],
    ])("rejects %s", (source, error) => {
        expect(compileTemplate(source)).toEqual({ ok: false, error });
    });

    it("accepts plain text and the app templates", () => {
        expect(templateError("No placeholders at all")).toBeNull();
        expect(templateError("")).toBeNull();
        for (const t of APP_TEMPLATES) {
            expect(templateError(t.subject)).toBeNull();
            expect(templateError(t.html)).toBeNull();
        }
    });

    it("throws on render of an invalid template", () => {
        expect(() => renderTemplate("{{bad doc.x}}", context)).toThrow(/Unknown helper/);
    });
});
