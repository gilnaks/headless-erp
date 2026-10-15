import { requireUser } from "@/lib/auth/claims";
import { emailInvitation, type InvitationDelivery } from "@/lib/email/invitation";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { getOrgBySlug } from "@/lib/queries/doc";
import { refresh } from "@/lib/query-client";
import { type CreateInvitationInput, createInvitationSchema, type InvitationRefInput, invitationRefSchema } from "@/lib/schemas/users";
import { createClient } from "@/lib/supabase/client";

const FIELD_FOR: Record<string, string> = {
    invalid_email: "email",
    already_member: "email",
    invite_pending: "email",
    invalid_role: "roles",
    roles_required: "roles",
};

export type InvitationResult = InvitationDelivery & { token: string };

/** Creates the invitation and emails the link (00-setup §3.4); the token is returned for "Copy link". */
export async function createInvitation(input: CreateInvitationInput): Promise<ActionResult<InvitationResult>> {
    const parsed = createInvitationSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, email, roleProfile, roles } = parsed.data;
    const claims = await requireUser(`/${orgSlug}/setup/users`);
    const org = await getOrgBySlug(orgSlug);
    if (!org) return fail("Organization not found.");

    const supabase = await createClient();
    const { data, error } = await supabase.rpc("create_invitation", {
        p_org: org.id,
        p_email: email,
        p_roles: roleProfile ? [] : roles,
        p_role_profile: roleProfile ?? "",
    });
    if (error) {
        const { code, message } = dbError(error);
        const field = FIELD_FOR[code];
        return field ? fail(message, { [field]: message }) : fail(message);
    }
    const { id, token } = data as { id: string; token: string };
    const delivery = await emailInvitation(org, { id, token }, claims);
    refresh();
    return { ok: true, data: { token, ...delivery } };
}

/** New token and expiry, emailed again; the previous link stops working. */
export async function resendInvitation(input: InvitationRefInput): Promise<ActionResult<InvitationResult>> {
    const parsed = invitationRefSchema.safeParse(input);
    if (!parsed.success) return fail("Unknown invitation.");
    const claims = await requireUser(`/${parsed.data.orgSlug}/setup/users`);
    const org = await getOrgBySlug(parsed.data.orgSlug);
    if (!org) return fail("Organization not found.");

    const supabase = await createClient();
    const { data, error } = await supabase.rpc("resend_invitation", { p_id: parsed.data.id });
    if (error) return fail(dbError(error).message);
    const { token } = data as { token: string };
    const delivery = await emailInvitation(org, { id: parsed.data.id, token }, claims);
    refresh();
    return { ok: true, data: { token, ...delivery } };
}

export async function revokeInvitation(input: InvitationRefInput): Promise<ActionResult> {
    const parsed = invitationRefSchema.safeParse(input);
    if (!parsed.success) return fail("Unknown invitation.");
    await requireUser(`/${parsed.data.orgSlug}/setup/users`);
    const org = await getOrgBySlug(parsed.data.orgSlug);
    if (!org) return fail("Organization not found.");

    const supabase = await createClient();
    const { data, error } = await supabase
        .from("invitations")
        .update({ revoked_at: new Date().toISOString() })
        .eq("org_id", org.id)
        .eq("id", parsed.data.id)
        .is("accepted_at", null)
        .is("revoked_at", null)
        .select("id");
    if (error) return fail(dbError(error).message);
    if (!data?.length) return fail("This invitation is already closed, or you cannot change it.");
    refresh();
    return { ok: true };
}
