"use server";

import { docPath, type FieldValues } from "@/doctypes/define";
import { DOCTYPES } from "@/doctypes/registry";
import { requireUser } from "@/lib/auth/claims";
import { docTable, getOrgBySlug, searchTerm } from "@/lib/queries/doc";
import { createClient } from "@/lib/supabase/server";

export type SearchHit = { doctype: string; id: string; label: string; path: string };

const PER_DOCTYPE = 5;

/** Command palette record search: title and list search fields of every listed doctype, scoped by RLS. */
export async function searchDocs(orgSlug: string, q: string): Promise<SearchHit[]> {
    await requireUser(`/${orgSlug}`);
    const term = searchTerm(q);
    if (term.length < 2) return [];
    const org = await getOrgBySlug(orgSlug);
    if (!org) return [];

    const supabase = await createClient();
    const results = await Promise.all(
        DOCTYPES.filter((d) => !d.single).map(async (d) => {
            const fields = [...new Set([d.titleField, ...d.listView.searchFields])];
            const { data, error } = await docTable(supabase, d.table)
                .select(`id, ${d.titleField}`)
                .eq("org_id", org.id)
                .or(fields.map((f) => `${f}.ilike.%${term}%`).join(","))
                .order(d.titleField)
                .limit(PER_DOCTYPE);
            if (error) throw new Error(`Could not search ${d.doctype}`);
            return ((data ?? []) as unknown as FieldValues[]).map((row) => ({
                doctype: d.doctype,
                id: String(row.id),
                label: String(row[d.titleField] ?? row.id),
                path: `${docPath(d)}/${row.id}`,
            }));
        }),
    );
    return results.flat();
}
