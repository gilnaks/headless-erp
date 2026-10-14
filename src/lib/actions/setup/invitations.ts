"use server";

import { refresh } from "next/cache";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { getOrgBySlug } from "@/lib/queries/doc";
import { type CreateInvitationInput, createInvitationSchema, type InvitationRefInput, invitationRefSchema } from "@/lib/schemas/users";
import { createClient } from "@/lib/supabase/server";

const FIELD_FOR: Record<string, string> = {
    invalid_email: "email",
    already_member: "email",
    invite_pending: "email",
    invalid_role: "roles",
    roles_required: "roles",
};

/**
 * Link-only delivery (00-setup §3.4): returns the token so the System Manager can copy `/invite/<token>`;
 * no email is sent until the Email track.
 */
export async function createInvitation(input: CreateInvitationInput): Promise<ActionResult<{ token: string }>> {
    const parsed = createInvitationSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, email, roleProfile, roles } = parsed.data;
    await requireUser(`/${orgSlug}/setup/users`);
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
    refresh();
    return { ok: true, data: { token: (data as { token: string }).token } };
}

/** New token and expiry; the previous link stops working. */
export async function resendInvitation(input: InvitationRefInput): Promise<ActionResult<{ token: string }>> {
    const parsed = invitationRefSchema.safeParse(input);
    if (!parsed.success) return fail("Unknown invitation.");
    await requireUser(`/${parsed.data.orgSlug}/setup/users`);

    const supabase = await createClient();
    const { data, error } = await supabase.rpc("resend_invitation", { p_id: parsed.data.id });
    if (error) return fail(dbError(error).message);
    refresh();
    return { ok: true, data: { token: (data as { token: string }).token } };
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
