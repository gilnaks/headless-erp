import { describe, expect, it } from "vitest";
import { orgsFromClaims, rolesDiffer } from "./orgs";

describe("orgsFromClaims", () => {
    it("reads app.orgs and drops non-string roles", () => {
        expect(orgsFromClaims({ app: { orgs: { a: ["Sales User", 1], b: "x" } } })).toEqual({ a: ["Sales User"], b: [] });
    });

    it("returns an empty map without the hook claim", () => {
        expect(orgsFromClaims({})).toEqual({});
        expect(orgsFromClaims(null)).toEqual({});
    });
});

describe("rolesDiffer", () => {
    it("ignores order and duplicates", () => {
        expect(rolesDiffer(["Stock User", "Sales User"], ["Sales User", "Stock User", "Sales User"])).toBe(false);
    });

    it("detects added and removed roles", () => {
        expect(rolesDiffer(["Sales User"], ["Sales User", "Sales Manager"])).toBe(true);
        expect(rolesDiffer(["Sales User", "Sales Manager"], ["Sales User"])).toBe(true);
    });

    it("treats a missing org in the token as stale", () => {
        expect(rolesDiffer(undefined, [])).toBe(true);
    });

    it("matches when both are empty", () => {
        expect(rolesDiffer([], [])).toBe(false);
    });
});
