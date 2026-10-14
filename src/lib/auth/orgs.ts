export type OrgRoles = Record<string, string[]>;

/** Reads `app.orgs` ({ orgId: roles[] }) added by `app.custom_access_token_hook`. UI hint only: RLS never trusts it. */
export function orgsFromClaims(claims: Record<string, unknown> | null | undefined): OrgRoles {
    const app = claims?.app;
    if (!app || typeof app !== "object") return {};
    const orgs = (app as { orgs?: unknown }).orgs;
    if (!orgs || typeof orgs !== "object" || Array.isArray(orgs)) return {};

    const result: OrgRoles = {};
    for (const [orgId, roles] of Object.entries(orgs)) {
        result[orgId] = Array.isArray(roles) ? roles.filter((r): r is string => typeof r === "string") : [];
    }
    return result;
}

/** True when the JWT's roles for an org no longer match `org_members.roles` (order-insensitive). */
export function rolesDiffer(claimRoles: readonly string[] | undefined, dbRoles: readonly string[]): boolean {
    if (!claimRoles) return true;
    const a = [...new Set(claimRoles)].sort();
    const b = [...new Set(dbRoles)].sort();
    return a.length !== b.length || a.some((r, i) => r !== b[i]);
}
