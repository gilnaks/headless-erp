import { describe, expect, it } from "vitest";
import { findLink } from "@/config/navigation";
import { isLinkActive, orgRelativePath } from "./active";

describe("orgRelativePath", () => {
    it("strips the org prefix and trailing slashes", () => {
        expect(orgRelativePath("/acme", "acme")).toBe("");
        expect(orgRelativePath("/acme/", "acme")).toBe("");
        expect(orgRelativePath("/acme/accounts/journal-entry/new", "acme")).toBe("accounts/journal-entry/new");
    });
});

describe("isLinkActive", () => {
    const je = findLink("accounts/journal-entry");
    const home = findLink("accounts");
    if (!je || !home) throw new Error("navigation fixtures missing");

    it("keeps doctype links active on sub-pages", () => {
        expect(isLinkActive(je, "accounts/journal-entry")).toBe(true);
        expect(isLinkActive(je, "accounts/journal-entry/abc")).toBe(true);
        expect(isLinkActive(je, "accounts/journal-entry-x")).toBe(false);
    });

    it("matches module homes exactly", () => {
        expect(isLinkActive(home, "accounts")).toBe(true);
        expect(isLinkActive(home, "accounts/journal-entry")).toBe(false);
    });
});
