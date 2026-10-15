import { cache } from "react";
import { getAuthClaims } from "@/lib/auth/claims";
import type { PermRule } from "@/lib/role-permissions";
import { createClient } from "@/lib/supabase/client";

export type PermissionDoctype = { doctype: string; module: string; isSubmittable: boolean; locked: boolean };

export const getPermissionDoctypes = cache(async (): Promise<PermissionDoctype[]> => {
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("permission_doctypes");
    if (error) throw new Error("Could not load document types");
    return (data ?? []).map((d) => ({ doctype: d.doctype, module: d.module, isSubmittable: d.is_submittable, locked: d.locked }));
});

export const getRolePermissions = cache(async (orgId: string): Promise<PermRule[]> => {
    const supabase = await createClient();
    const { data, error } = await supabase
        .from("role_permissions")
        .select(
            "role, doctype, can_read, can_write, can_create, can_delete, can_submit, can_cancel, can_amend, can_report, can_export, if_owner",
        )
        .eq("org_id", orgId)
        .order("doctype")
        .order("role");
    if (error) throw new Error("Could not load role permissions");
    return data ?? [];
});

/** The caller's current roles in the org (membership row, not the JWT snapshot). */
export const getMyRoles = cache(async (orgId: string): Promise<string[]> => {
    const claims = await getAuthClaims();
    const supabase = await createClient();
    const { data } = await supabase
        .from("org_members")
        .select("roles")
        .eq("org_id", orgId)
        .eq("user_id", claims?.userId ?? "")
        .maybeSingle();
    return data?.roles ?? [];
});
