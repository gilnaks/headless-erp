export type InvitationStatus = "pending" | "expired" | "revoked" | "accepted";

export type InvitationRow = {
    id: string;
    email: string;
    roles: string[];
    role_profile: string | null;
    token: string;
    expires_at: string;
    accepted_at: string | null;
    revoked_at: string | null;
    created_at: string;
};

/** Derived like `app.invitation_preview`: accepted and revoked are final; otherwise the expiry decides. */
export function invitationStatus(
    inv: Pick<InvitationRow, "expires_at" | "accepted_at" | "revoked_at">,
    now = new Date(),
): InvitationStatus {
    if (inv.accepted_at) return "accepted";
    if (inv.revoked_at) return "revoked";
    return new Date(inv.expires_at) < now ? "expired" : "pending";
}

export function inviteLink(origin: string, token: string): string {
    return `${origin.replace(/\/+$/, "")}/invite/${encodeURIComponent(token)}`;
}
