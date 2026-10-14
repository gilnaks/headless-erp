import "server-only";
import type { Doctype, FieldValues } from "@/doctypes/define";
import { type LinkOption, type LinkTitles, linkRequests, titleKey } from "@/lib/link-titles";
import { docTable } from "@/lib/queries/doc";
import { getMemberDirectory } from "@/lib/queries/users";
import { createClient } from "@/lib/supabase/server";

const SEARCH_LIMIT = 20;

/** `User` links point at organization members: titles come from the member directory (emails live in auth). */
async function memberOptions(orgId: string): Promise<LinkOption[]> {
    const members = await getMemberDirectory(orgId);
    return members.map((m) => ({ id: m.userId, label: m.fullName ? `${m.fullName} (${m.email})` : m.email }));
}

async function linkMeta(doctype: string) {
    const supabase = await createClient();
    const { data } = await supabase
        .from("doctype_meta")
        .select("table_name, title_field")
        .eq("doctype", doctype)
        .eq("is_child", false)
        .maybeSingle();
    return data ? { supabase, table: data.table_name, title: data.title_field ?? "name" } : null;
}

/** Labels of specific records of `doctype` (RLS applies; invisible records are left out). */
export async function getLinkTitles(orgId: string, doctype: string, ids: string[]): Promise<LinkOption[]> {
    if (!ids.length) return [];
    if (doctype === "User") return (await memberOptions(orgId)).filter((o) => ids.includes(o.id));
    const meta = await linkMeta(doctype);
    if (!meta) return [];
    const { data } = await docTable(meta.supabase, meta.table).select(`id, ${meta.title}`).eq("org_id", orgId).in("id", ids);
    return ((data ?? []) as unknown as FieldValues[]).map((r) => ({ id: String(r.id), label: String(r[meta.title] ?? r.id) }));
}

/** Records of `doctype` whose title contains `q` (Link combobox). */
export async function searchLinkTitles(orgId: string, doctype: string, q: string): Promise<LinkOption[]> {
    const term = q.trim();
    if (doctype === "User") {
        const needle = term.toLowerCase();
        return (await memberOptions(orgId)).filter((o) => o.label.toLowerCase().includes(needle)).slice(0, SEARCH_LIMIT);
    }
    const meta = await linkMeta(doctype);
    if (!meta) return [];
    const escaped = term.replace(/[%_\\]/g, (c) => `\\${c}`);
    const { data } = await docTable(meta.supabase, meta.table)
        .select(`id, ${meta.title}`)
        .eq("org_id", orgId)
        .ilike(meta.title, `%${escaped}%`)
        .order(meta.title)
        .limit(SEARCH_LIMIT);
    return ((data ?? []) as unknown as FieldValues[]).map((r) => ({ id: String(r.id), label: String(r[meta.title] ?? r.id) }));
}

/** Titles for every Link / DynamicLink cell of a list page, one query per target doctype. */
export async function getListLinkTitles(
    d: Doctype,
    orgId: string,
    rows: FieldValues[],
    columns: string[] = d.listView.columns,
): Promise<LinkTitles> {
    const requests = [...linkRequests(d.fields, columns, rows)];
    const resolved = await Promise.all(requests.map(([doctype, ids]) => getLinkTitles(orgId, doctype, ids)));
    const titles: LinkTitles = {};
    requests.forEach(([doctype], i) => {
        for (const option of resolved[i]) titles[titleKey(doctype, option.id)] = option.label;
    });
    return titles;
}
