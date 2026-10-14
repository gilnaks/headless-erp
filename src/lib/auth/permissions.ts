import type { Tables } from "@/types/database";

export type PermAction = "read" | "write" | "create" | "delete" | "submit" | "cancel" | "amend" | "report" | "export";

export type RolePermission = Pick<Tables<"role_permissions">, "role" | "doctype"> & Partial<Record<`can_${PermAction}`, boolean>>;

/**
 * UI hint: does any of `roles` grant `action` on `doctype`? Mirrors `app.has_perm` (System Manager does not bypass
 * doctype permissions there either). The database remains the authority; this only hides buttons and links.
 */
export function can(roles: readonly string[], permissions: readonly RolePermission[], doctype: string, action: PermAction): boolean {
    const key = `can_${action}` as const;
    const needsRead = action === "report" || action === "export";
    return permissions.some(
        (p) => p.doctype === doctype && roles.includes(p.role) && p[key] === true && (!needsRead || p.can_read === true),
    );
}
