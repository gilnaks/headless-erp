import { describe, expect, it } from "vitest";
import { orgsFromClaims } from "./orgs";
import { can, type RolePermission } from "./permissions";

const perms: RolePermission[] = [
    { role: "Accounts User", doctype: "Journal Entry", can_read: true, can_write: true, can_create: true, can_submit: true },
    { role: "Accounts Manager", doctype: "Journal Entry", can_read: true, can_cancel: true, can_report: true },
    { role: "Auditor", doctype: "Journal Entry", can_report: true },
];

describe("can", () => {
    it("grants when any role has the flag", () => {
        expect(can(["Accounts User"], perms, "Journal Entry", "submit")).toBe(true);
        expect(can(["Sales User", "Accounts Manager"], perms, "Journal Entry", "cancel")).toBe(true);
    });

    it("denies without a matching role, doctype or flag", () => {
        expect(can(["Accounts User"], perms, "Journal Entry", "cancel")).toBe(false);
        expect(can(["Accounts User"], perms, "Payment Entry", "read")).toBe(false);
        expect(can(["System Manager"], perms, "Journal Entry", "read")).toBe(false);
        expect(can([], perms, "Journal Entry", "read")).toBe(false);
    });

    it("requires read for report and export (mirrors app.orgs_with_perm)", () => {
        expect(can(["Accounts Manager"], perms, "Journal Entry", "report")).toBe(true);
        expect(can(["Auditor"], perms, "Journal Entry", "report")).toBe(false);
    });
});

describe("orgsFromClaims", () => {
    it("reads app.orgs", () => {
        expect(orgsFromClaims({ app: { orgs: { o1: ["System Manager"], o2: [] } } })).toEqual({ o1: ["System Manager"], o2: [] });
    });

    it("tolerates missing or malformed claims", () => {
        expect(orgsFromClaims(null)).toEqual({});
        expect(orgsFromClaims({})).toEqual({});
        expect(orgsFromClaims({ app: "x" })).toEqual({});
        expect(orgsFromClaims({ app: { orgs: ["o1"] } })).toEqual({});
        expect(orgsFromClaims({ app: { orgs: { o1: "System Manager", o2: ["Stock User", 3] } } })).toEqual({ o1: [], o2: ["Stock User"] });
    });
});
