import { describe, expect, it } from "vitest";
import { findLinkForPath, MODULE_IDS, MODULES, moduleForPath, moduleLinks } from "./navigation";

describe("navigation config", () => {
    it("covers the eight PLAN §1 modules exactly once", () => {
        expect([...MODULE_IDS].sort()).toEqual(["accounts", "assets", "buying", "manufacturing", "projects", "selling", "setup", "stock"]);
    });

    it("gives every module a home", () => {
        for (const module of MODULES) {
            const home = module.items.find((l) => l.target.kind === "workspace");
            expect(home, module.id).toBeDefined();
        }
    });

    it("has unique paths within each module", () => {
        for (const module of MODULES) {
            const paths = moduleLinks(module).map((l) => l.path);
            expect(new Set(paths).size, module.id).toBe(paths.length);
        }
    });

    it("uses normalised paths that resolve to a known module", () => {
        for (const module of MODULES) {
            for (const link of moduleLinks(module)) {
                expect(link.path, link.label).toMatch(/^([a-z0-9-]+(\/[a-z0-9-]+)*)?$/);
                if (link.path) expect(moduleForPath(link.path), link.path).toBeDefined();
            }
        }
    });

    it("keeps out-of-scope ERPNext items out (PLAN §1)", () => {
        const labels = MODULES.flatMap((m) => moduleLinks(m).map((l) => l.label));
        for (const banned of [
            "Pricing Rule",
            "POS",
            "POS Profile",
            "Accounting Dimension",
            "Item Attribute",
            "Data Import",
            "Quality Inspection",
        ]) {
            expect(labels).not.toContain(banned);
        }
    });

    it("resolves doctype sub-pages to their list entry", () => {
        expect(findLinkForPath("accounts/journal-entry")?.label).toBe("Journal Entry");
        expect(findLinkForPath("accounts/journal-entry/new")?.label).toBe("Journal Entry");
        expect(findLinkForPath("accounts/reports/general-ledger")?.label).toBe("General Ledger");
        expect(findLinkForPath("accounts/reports/general-ledger/extra")).toBeUndefined();
        expect(findLinkForPath("accounts/nope")).toBeUndefined();
    });

    it("maps the org home to Setup", () => {
        expect(moduleForPath("")?.id).toBe("setup");
    });
});
