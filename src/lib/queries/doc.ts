import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { cache } from "react";
import type { Doctype, FieldValues } from "@/doctypes/define";
import { getAuthClaims } from "@/lib/auth/claims";
import { can, type RolePermission } from "@/lib/auth/permissions";
import { PAGE_SIZES } from "@/lib/list-params";
import { createClient } from "@/lib/supabase/server";

/**
 * Query builder for a table chosen at runtime (descriptor / doctype_meta). Generated types cannot follow a dynamic
 * name, so rows come back as `FieldValues`; RLS still applies because it is the same user-scoped client.
 */
export function docTable(supabase: Awaited<ReturnType<typeof createClient>>, table: string) {
    return (supabase as unknown as SupabaseClient).from(table);
}

export type ListParams = { q?: string; sort?: string; desc?: boolean; page?: number; pageSize?: number };
export type ListResult = { rows: FieldValues[]; count: number; page: number; pageSize: number; sort: string; desc: boolean };
export type DocPermissions = { read: boolean; write: boolean; create: boolean; delete: boolean };

/** The organization for a URL slug, resolved through RLS (null when the caller is not a member). */
export const getOrgBySlug = cache(async (slug: string) => {
    const supabase = await createClient();
    const { data } = await supabase.from("organizations").select("id, slug, name").eq("slug", slug).maybeSingle();
    return data;
});

/** PostgREST `or=` filters break on these characters; search terms are plain text. */
function searchTerm(q: string | undefined): string {
    return (q ?? "").replace(/[,()*%\\]/g, " ").trim();
}

export async function listDocs(d: Doctype, orgId: string, params: ListParams): Promise<ListResult> {
    const sort = params.sort && d.listView.columns.includes(params.sort) ? params.sort : d.listView.defaultSort.field;
    const desc = params.sort ? Boolean(params.desc) : Boolean(d.listView.defaultSort.desc);
    const pageSize = PAGE_SIZES.includes(params.pageSize as (typeof PAGE_SIZES)[number]) ? (params.pageSize as number) : PAGE_SIZES[0];
    const page = Math.max(1, Math.floor(params.page ?? 1));

    const supabase = await createClient();
    const columns = ["id", ...new Set([d.titleField, ...d.listView.columns])].join(", ");
    let query = docTable(supabase, d.table)
        .select(columns, { count: "exact" })
        .eq("org_id", orgId)
        .order(sort, { ascending: !desc })
        .order("id")
        .range((page - 1) * pageSize, page * pageSize - 1);

    const term = searchTerm(params.q);
    if (term) query = query.or(d.listView.searchFields.map((f) => `${f}.ilike.%${term}%`).join(","));

    const { data, count, error } = await query;
    if (error) throw new Error(`Could not load ${d.doctype} list`);
    return { rows: (data ?? []) as unknown as FieldValues[], count: count ?? 0, page, pageSize, sort, desc };
}

/** Header row plus child rows (ordered by idx), or null when missing or not visible. */
export async function getDoc(d: Doctype, orgId: string, id: string): Promise<FieldValues | null> {
    const supabase = await createClient();
    const { data, error } = await docTable(supabase, d.table).select("*").eq("org_id", orgId).eq("id", id).maybeSingle();
    if (error || !data) return null;

    const doc: FieldValues = { ...(data as FieldValues) };
    for (const [field, child] of Object.entries(d.children)) {
        const { data: rows } = await docTable(supabase, child.table).select("*").eq("parent_id", id).order("idx");
        doc[field] = rows ?? [];
    }
    return doc;
}

/** UI hints from role_permissions + the caller's roles (the database still authorizes every write). */
export async function getDocPermissions(orgId: string, doctype: string): Promise<DocPermissions> {
    const claims = await getAuthClaims();
    const supabase = await createClient();
    const [{ data: member }, { data: perms }] = await Promise.all([
        supabase
            .from("org_members")
            .select("roles")
            .eq("org_id", orgId)
            .eq("user_id", claims?.userId ?? "")
            .maybeSingle(),
        supabase
            .from("role_permissions")
            .select("role, doctype, can_read, can_write, can_create, can_delete")
            .eq("org_id", orgId)
            .eq("doctype", doctype),
    ]);
    const roles = member?.roles ?? claims?.orgs[orgId] ?? [];
    const rows = (perms ?? []) as RolePermission[];
    return {
        read: can(roles, rows, doctype, "read"),
        write: can(roles, rows, doctype, "write"),
        create: can(roles, rows, doctype, "create"),
        delete: can(roles, rows, doctype, "delete"),
    };
}
