import { cache } from "react";
import type { InvitationRow } from "@/lib/invitations";
import { createClient } from "@/lib/supabase/client";

export type Member = {
    userId: string;
    email: string;
    fullName: string | null;
    avatarUrl: string | null;
    roles: string[];
    roleProfile: string | null;
    status: string;
    isOwner: boolean;
    createdAt: string;
    /** Only filled for System Managers. */
    lastSignInAt: string | null;
};

export type RoleProfileOption = { name: string; roles: string[] };

/** Members of an org with their auth emails (`app.org_member_directory`; empty for non-members). */
export const getMemberDirectory = cache(async (orgId: string): Promise<Member[]> => {
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("org_member_directory", { p_org: orgId });
    if (error) throw new Error("Could not load users");
    return (data ?? []).map((m) => ({
        userId: m.user_id,
        email: m.email,
        fullName: m.full_name,
        avatarUrl: m.avatar_url,
        roles: m.roles ?? [],
        roleProfile: m.role_profile,
        status: m.status,
        isOwner: m.is_owner,
        createdAt: m.created_at,
        lastSignInAt: m.last_sign_in_at,
    }));
});

/** Newest first; RLS returns rows (and tokens) to System Managers only. */
export const getInvitations = cache(async (orgId: string): Promise<InvitationRow[]> => {
    const supabase = await createClient();
    const { data, error } = await supabase
        .from("invitations")
        .select("id, email, roles, role_profile, token, expires_at, accepted_at, revoked_at, created_at")
        .eq("org_id", orgId)
        .order("created_at", { ascending: false })
        .limit(100);
    if (error) throw new Error("Could not load invitations");
    return data ?? [];
});

export const getRoleProfiles = cache(async (orgId: string): Promise<RoleProfileOption[]> => {
    const supabase = await createClient();
    const { data } = await supabase.from("role_profile").select("name, roles").eq("org_id", orgId).order("name");
    return data ?? [];
});
