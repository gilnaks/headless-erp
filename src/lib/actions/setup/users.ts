"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { getOrgBySlug } from "@/lib/queries/doc";
import {
    type RemoveMemberInput,
    removeMemberSchema,
    type SetMemberStatusInput,
    setMemberStatusSchema,
    type UpdateMemberRolesInput,
    updateMemberRolesSchema,
} from "@/lib/schemas/users";
import { createClient } from "@/lib/supabase/server";

const NOT_ALLOWED = "You do not have permission to change users. Ask a System Manager.";

/** Org for the action, after the session check; RLS (System Manager on org_members) authorizes the write. */
async function context(orgSlug: string, userId: string) {
    await requireUser(`/${orgSlug}/setup/users/${userId}`);
    const org = await getOrgBySlug(orgSlug);
    return { org, supabase: await createClient() };
}

/** Role profile or hand-picked roles (frappe User: `role_profile_name` repopulates the roles on save). */
export async function updateMemberRoles(input: UpdateMemberRolesInput): Promise<ActionResult> {
    const parsed = updateMemberRolesSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, userId, roleProfile, roles } = parsed.data;
    const { org, supabase } = await context(orgSlug, userId);
    if (!org) return fail("Organization not found.");

    const { data, error } = await supabase
        .from("org_members")
        .update({ role_profile: roleProfile, roles })
        .eq("org_id", org.id)
        .eq("user_id", userId)
        .select("user_id");
    if (error) {
        const { code, message } = dbError(error);
        if (code === "invalid_role") return fail(message, { roles: message });
        return fail(message);
    }
    if (!data?.length) return fail(NOT_ALLOWED);
    refresh();
    return { ok: true };
}

/** Disabled members keep their roles but lose access (`app.is_member` only counts active rows). */
export async function setMemberStatus(input: SetMemberStatusInput): Promise<ActionResult> {
    const parsed = setMemberStatusSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, userId, status } = parsed.data;
    const { org, supabase } = await context(orgSlug, userId);
    if (!org) return fail("Organization not found.");

    const { data, error } = await supabase
        .from("org_members")
        .update({ status })
        .eq("org_id", org.id)
        .eq("user_id", userId)
        .select("user_id");
    if (error) return fail(dbError(error).message);
    if (!data?.length) return fail(NOT_ALLOWED);
    refresh();
    return { ok: true };
}

/** Removes the membership (and, by trigger, the member's User Permissions); the auth user stays. */
export async function removeMember(input: RemoveMemberInput): Promise<ActionResult> {
    const parsed = removeMemberSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, userId } = parsed.data;
    const { org, supabase } = await context(orgSlug, userId);
    if (!org) return fail("Organization not found.");

    const { data, error } = await supabase.from("org_members").delete().eq("org_id", org.id).eq("user_id", userId).select("user_id");
    if (error) return fail(dbError(error).message);
    if (!data?.length) return fail(NOT_ALLOWED);
    redirect(`/${org.slug}/setup/users`);
}
