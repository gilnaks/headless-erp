import { titleKey } from "@/lib/link-titles";
import { getLinkTitles } from "@/lib/queries/links";
import { createClient } from "@/lib/supabase/client";

export type MemberPermission = {
    id: string;
    doctype: string;
    recordId: string;
    /** Title of the record, or its id when it is not visible to the caller. */
    record: string;
    applicableFor: string | null;
    isDefault: boolean;
    hideDescendants: boolean;
};

/** One member's User Permissions with record titles (RLS: System Managers, or the user themselves). */
export async function getMemberPermissions(orgId: string, userId: string): Promise<MemberPermission[]> {
    const supabase = await createClient();
    const { data, error } = await supabase
        .from("user_permissions")
        .select("id, doctype, record_id, applicable_for, is_default, hide_descendants")
        .eq("org_id", orgId)
        .eq("user_id", userId)
        .order("doctype")
        .order("created_at");
    if (error) throw new Error("Could not load user permissions");

    const rows = data ?? [];
    const idsByDoctype = new Map<string, Set<string>>();
    for (const r of rows) idsByDoctype.set(r.doctype, (idsByDoctype.get(r.doctype) ?? new Set()).add(r.record_id));
    const doctypes = [...idsByDoctype.keys()];
    const resolved = await Promise.all(doctypes.map((doctype) => getLinkTitles(orgId, doctype, [...(idsByDoctype.get(doctype) ?? [])])));
    const titles = new Map<string, string>();
    doctypes.forEach((doctype, i) => {
        for (const option of resolved[i]) titles.set(titleKey(doctype, option.id), option.label);
    });

    return rows.map((r) => ({
        id: r.id,
        doctype: r.doctype,
        recordId: r.record_id,
        record: titles.get(titleKey(r.doctype, r.record_id)) ?? r.record_id,
        applicableFor: r.applicable_for,
        isDefault: r.is_default,
        hideDescendants: r.hide_descendants,
    }));
}
