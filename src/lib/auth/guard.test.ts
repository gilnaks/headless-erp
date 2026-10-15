import { describe, expect, it } from "vitest";
import { isPublicPath, signedOutRedirect } from "./guard";

describe("route guard", () => {
    it("leaves auth, invite, and health pages open", () => {
        expect(isPublicPath("/login")).toBe(true);
        expect(isPublicPath("/signup")).toBe(true);
        expect(isPublicPath("/forgot-password")).toBe(true);
        expect(isPublicPath("/update-password")).toBe(true);
        expect(isPublicPath("/auth/callback")).toBe(true);
        expect(isPublicPath("/health")).toBe(true);
        expect(isPublicPath("/invite/abc")).toBe(true);
    });

    it("sends other paths to login and keeps a same-origin next", () => {
        expect(signedOutRedirect("/login")).toBeNull();
        expect(signedOutRedirect("/")).toBe("/login");
        expect(signedOutRedirect("/acme/setup/company")).toBe("/login?next=%2Facme%2Fsetup%2Fcompany");
    });
});
