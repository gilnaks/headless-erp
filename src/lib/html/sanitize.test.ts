import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const { sanitizeHtml } = await import("./sanitize");

describe("sanitizeHtml", () => {
    it("keeps formatting, tables and images", () => {
        const html =
            '<div style="text-align:right"><h2>Acme</h2><p><b>Bold</b> <em>it</em></p>' +
            '<table><tbody><tr><td colspan="2">Cell</td></tr></tbody></table><img src="https://x.test/logo.png" alt="Logo" /></div>';
        expect(sanitizeHtml(html)).toBe(html);
    });

    it("removes scripts, styles blocks and iframes with their content", () => {
        expect(sanitizeHtml("<p>Hi</p><script>alert(1)</script><style>p{}</style><iframe src='x'></iframe>")).toBe("<p>Hi</p>");
    });

    it("strips event handlers", () => {
        expect(sanitizeHtml('<img src="https://x.test/a.png" onerror="alert(1)" /><p onclick="x()">t</p>')).toBe(
            '<img src="https://x.test/a.png" /><p>t</p>',
        );
    });

    it("strips javascript: and protocol-relative URLs", () => {
        expect(sanitizeHtml('<a href="javascript:alert(1)">x</a>')).toBe("<a>x</a>");
        expect(sanitizeHtml('<a href="JaVaScRiPt:alert(1)">x</a>')).toBe("<a>x</a>");
        expect(sanitizeHtml('<img src="//evil.test/a.png" />')).toBe("<img />");
    });

    it("allows data: URLs only on images", () => {
        expect(sanitizeHtml('<img src="data:image/png;base64,AAA" />')).toBe('<img src="data:image/png;base64,AAA" />');
        expect(sanitizeHtml('<a href="data:text/html,x">x</a>')).toBe("<a>x</a>");
    });

    it("drops unsafe style values and unknown properties", () => {
        expect(sanitizeHtml('<p style="color: red; background-image: url(x)">t</p>')).toBe('<p style="color:red">t</p>');
        expect(sanitizeHtml('<p style="width: expression(alert(1))">t</p>')).toBe("<p>t</p>");
    });
});
