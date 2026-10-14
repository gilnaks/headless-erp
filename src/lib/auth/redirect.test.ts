import { describe, expect, it } from "vitest";
import { safeNext, withNext } from "./redirect";

describe("safeNext", () => {
    it.each([
        ["/acme", "/acme"],
        ["/acme/accounts?x=1#top", "/acme/accounts?x=1#top"],
        ["/invite/abc123", "/invite/abc123"],
    ])("keeps same-origin path %s", (input, expected) => {
        expect(safeNext(input)).toBe(expected);
    });

    it.each([null, undefined, "", "acme", "https://evil.test/x", "//evil.test", "/\\evil.test", "javascript:alert(1)", "\\\\evil"])(
        "falls back for %s",
        (input) => {
            expect(safeNext(input)).toBe("/");
        },
    );

    it("uses the given fallback", () => {
        expect(safeNext("//evil.test", "/setup")).toBe("/setup");
    });

    it("normalises dot segments without leaving the origin", () => {
        expect(safeNext("/a/../../b")).toBe("/b");
    });
});

describe("withNext", () => {
    it("omits the default target", () => {
        expect(withNext("/signup", "/")).toBe("/signup");
        expect(withNext("/signup", null)).toBe("/signup");
    });

    it("encodes the target", () => {
        expect(withNext("/login", "/invite/t?x=1")).toBe("/login?next=%2Finvite%2Ft%3Fx%3D1");
    });

    it("drops unsafe targets", () => {
        expect(withNext("/login", "https://evil.test")).toBe("/login");
    });
});
