import "server-only";
import { appUrl } from "@/lib/app-url";
import type { AuthClaims } from "@/lib/auth/claims";
import { inviteLink } from "@/lib/invitations";
import { createClient } from "@/lib/supabase/server";
import { renderTemplate } from "./render";
import { deliver, platformSender } from "./sender";
import { INVITATION_TEMPLATE } from "./templates";

export type InvitationDelivery = {
    email: string;
    /** True when the invitation email went out; otherwise the link has to be shared by hand. */
    emailed: boolean;
    emailError?: string;
};

/**
 * Sends the `Invitation` app template through the platform sender (00-setup §3.4) and logs it to `email_log`.
 * Failures do not undo the invitation: callers keep the token for the copy-link fallback.
 */
export async function emailInvitation(
    org: { id: string; name: string },
    invitation: { id: string; token: string },
    claims: AuthClaims,
): Promise<InvitationDelivery> {
    const supabase = await createClient();
    const [{ data: row }, { data: profile }] = await Promise.all([
        supabase.from("invitations").select("email, expires_at").eq("id", invitation.id).single(),
        supabase.from("user_profile").select("full_name").eq("user_id", claims.userId).maybeSingle(),
    ]);
    const email = row?.email ?? "";
    if (!row) return { email, emailed: false, emailError: "The invitation could not be loaded." };

    const sender = platformSender();
    if (!sender) return { email, emailed: false, emailError: "Email is not set up for this site." };

    const context = {
        doc: { organization: org.name, invite_url: inviteLink(await appUrl(), invitation.token), expires_on: row.expires_at },
        user: { full_name: profile?.full_name ?? claims.email ?? "A colleague" },
    };
    const result = await deliver(sender, {
        orgId: org.id,
        to: [email],
        subject: renderTemplate(INVITATION_TEMPLATE.subject, context),
        html: renderTemplate(INVITATION_TEMPLATE.html, context, { html: true }),
        reference: { doctype: "Invitation", id: invitation.id },
        sentBy: claims.userId,
    });
    return result.ok ? { email, emailed: true } : { email, emailed: false, emailError: result.error };
}
