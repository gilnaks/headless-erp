import "server-only";
import { redirect } from "next/navigation";
import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import { type OrgRoles, orgsFromClaims } from "./orgs";

export type AuthClaims = {
    userId: string;
    email: string | null;
    orgs: OrgRoles;
};

/** Verified JWT claims for the current request (getClaims validates the signature), or null when signed out. */
export const getAuthClaims = cache(async (): Promise<AuthClaims | null> => {
    const supabase = await createClient();
    const { data } = await supabase.auth.getClaims();
    const claims = data?.claims;
    if (!claims?.sub) return null;
    return {
        userId: claims.sub,
        email: typeof claims.email === "string" ? claims.email : null,
        orgs: orgsFromClaims(claims as Record<string, unknown>),
    };
});

/** For Server Components and Server Actions that need a signed-in user. */
export async function requireUser(next?: string): Promise<AuthClaims> {
    const claims = await getAuthClaims();
    if (!claims) redirect(next ? `/login?next=${encodeURIComponent(next)}` : "/login");
    return claims;
}
