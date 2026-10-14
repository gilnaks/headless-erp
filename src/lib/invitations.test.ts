import { describe, expect, it } from "vitest";
import { invitationStatus, inviteLink } from "./invitations";

describe("invitationStatus", () => {
    const now = new Date("2026-10-14T12:00:00Z");
    const open = { expires_at: "2026-10-20T00:00:00Z", accepted_at: null, revoked_at: null };

    it("is pending until it expires", () => {
        expect(invitationStatus(open, now)).toBe("pending");
        expect(invitationStatus({ ...open, expires_at: "2026-10-14T11:59:59Z" }, now)).toBe("expired");
    });

    it("accepted and revoked are final, whatever the expiry", () => {
        const past = { expires_at: "2026-01-01T00:00:00Z" };
        expect(invitationStatus({ ...open, ...past, accepted_at: "2025-12-31T00:00:00Z" }, now)).toBe("accepted");
        expect(invitationStatus({ ...open, ...past, revoked_at: "2025-12-31T00:00:00Z" }, now)).toBe("revoked");
    });
});

describe("inviteLink", () => {
    it("joins the origin and the token", () => {
        expect(inviteLink("https://erp.example.com/", "abc123")).toBe("https://erp.example.com/invite/abc123");
    });
});
