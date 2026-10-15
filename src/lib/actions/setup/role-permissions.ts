import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { getOrgBySlug } from "@/lib/queries/doc";
import { refresh } from "@/lib/query-client";
import {
    type ResetDoctypeInput,
    type RuleInput,
    resetDoctypeSchema,
    ruleSchema,
    type SetPermissionInput,
    setPermissionSchema,
} from "@/lib/schemas/role-permissions";
import { createClient } from "@/lib/supabase/client";

const PATH = "setup/role-permissions";
const NOT_ALLOWED = "You do not have permission to change role permissions. Ask a System Manager.";

async function context(orgSlug: string) {
    await requireUser(`/${orgSlug}/${PATH}`);
    return { org: await getOrgBySlug(orgSlug), supabase: await createClient() };
}

/** Frappe permission_manager.update: one rule, one or more flags (dependencies already applied by the client). */
export async function setPermission(input: SetPermissionInput): Promise<ActionResult> {
    const parsed = setPermissionSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, role, doctype, patch } = parsed.data;
    const { org, supabase } = await context(orgSlug);
    if (!org) return fail("Organization not found.");

    const { data, error } = await supabase
        .from("role_permissions")
        .update(patch)
        .eq("org_id", org.id)
        .eq("role", role)
        .eq("doctype", doctype)
        .select("role");
    if (error) return fail(dbError(error).message);
    if (!data?.length) return fail(NOT_ALLOWED);
    refresh();
    return { ok: true };
}

/** Frappe permission_manager.add: a new role × doctype rule with Read (Report and Export default on). */
export async function addRule(input: RuleInput): Promise<ActionResult> {
    const parsed = ruleSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, role, doctype } = parsed.data;
    const { org, supabase } = await context(orgSlug);
    if (!org) return fail("Organization not found.");

    const { error } = await supabase.from("role_permissions").insert({ org_id: org.id, role, doctype, can_read: true });
    if (error) {
        const { code, message } = dbError(error);
        if (code === "duplicate") return fail(`${role} already has a rule for ${doctype}.`);
        if (code === "permission_denied") return fail(NOT_ALLOWED);
        return fail(message);
    }
    refresh();
    return { ok: true };
}

export async function removeRule(input: RuleInput): Promise<ActionResult> {
    const parsed = ruleSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));
    const { orgSlug, role, doctype } = parsed.data;
    const { org, supabase } = await context(orgSlug);
    if (!org) return fail("Organization not found.");

    const { data, error } = await supabase
        .from("role_permissions")
        .delete()
        .eq("org_id", org.id)
        .eq("role", role)
        .eq("doctype", doctype)
        .select("role");
    if (error) return fail(dbError(error).message);
    if (!data?.length) return fail(NOT_ALLOWED);
    refresh();
    return { ok: true };
}

/** Frappe permission_manager.reset for one doctype: the org's rules are replaced by the defaults. */
export async function resetDoctype(input: ResetDoctypeInput): Promise<ActionResult> {
    const parsed = resetDoctypeSchema.safeParse(input);
    if (!parsed.success) return fail("Select a document type.");
    const { orgSlug, doctype } = parsed.data;
    const { org, supabase } = await context(orgSlug);
    if (!org) return fail("Organization not found.");

    const { error } = await supabase.rpc("reset_role_permissions", { p_org: org.id, p_doctype: doctype });
    if (error) return fail(dbError(error).message);
    refresh();
    return { ok: true };
}
