"use server";

import { refresh, updateTag } from "next/cache";
import { redirect } from "next/navigation";
import { docPath, type FieldValues } from "@/doctypes/define";
import { getDoctypeByName } from "@/doctypes/registry";
import { formToPayload, schemaFor } from "@/doctypes/schema";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { docTable, getOrgBySlug } from "@/lib/queries/doc";
import { createClient } from "@/lib/supabase/server";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type LinkOption = { id: string; label: string };

function docTag(orgId: string, doctype: string): string {
    return `org:${orgId}:${doctype}`;
}

/**
 * Generic save (frappe `Document.save`): Zod parse with the doctype's schema, then `app.save_doc` (RLS authorizes).
 * New documents redirect to their form; edits refresh the current route.
 */
export async function saveDoc(input: {
    orgSlug: string;
    doctype: string;
    id: string | null;
    values: FieldValues;
}): Promise<ActionResult<{ id: string }>> {
    await requireUser(`/${input.orgSlug}`);
    const d = getDoctypeByName(input.doctype);
    if (!d) return fail(`${input.doctype} is not a document type.`);
    const org = await getOrgBySlug(input.orgSlug);
    if (!org) return fail("Organization not found.");
    if (input.id !== null && !UUID.test(input.id)) return fail(`${d.doctype} not found.`);

    const parsed = schemaFor(d).safeParse(input.values);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const isNew = input.id === null;
    const payload = { ...formToPayload(d, parsed.data as FieldValues, { isNew }), ...(isNew ? { org_id: org.id } : { id: input.id }) };

    const supabase = await createClient();
    const { data, error } = await supabase.rpc("save_doc", { p_doctype: d.doctype, p_payload: payload });
    if (error) {
        const { code, message } = dbError(error);
        const field = d.errorFields[code];
        return field ? fail(message, { [field]: message }) : fail(message);
    }

    const id = (data as { id: string }).id;
    updateTag(docTag(org.id, d.doctype));
    if (isNew) redirect(`/${org.slug}/${docPath(d)}/${id}`);
    refresh();
    return { ok: true, data: { id } };
}

/** Generic delete (frappe `delete_doc`): drafts and masters only; returns to the list. */
export async function deleteDoc(input: { orgSlug: string; doctype: string; id: string }): Promise<ActionResult> {
    await requireUser(`/${input.orgSlug}`);
    const d = getDoctypeByName(input.doctype);
    if (!d) return fail(`${input.doctype} is not a document type.`);
    const org = await getOrgBySlug(input.orgSlug);
    if (!org) return fail("Organization not found.");
    if (!UUID.test(input.id)) return fail(`${d.doctype} not found.`);

    const supabase = await createClient();
    const { error } = await supabase.rpc("delete_doc", { p_doctype: d.doctype, p_id: input.id });
    if (error) return fail(dbError(error).message);

    updateTag(docTag(org.id, d.doctype));
    redirect(`/${org.slug}/${docPath(d)}`);
}

/**
 * Options for a Link field: records of `doctype` whose title matches `q`, plus the labels of `ids` (the current
 * value). Any doctype in `doctype_meta` works, so Links can target doctypes without a descriptor yet.
 */
export async function searchLink(input: { orgSlug: string; doctype: string; q?: string; ids?: string[] }): Promise<LinkOption[]> {
    await requireUser(`/${input.orgSlug}`);
    const org = await getOrgBySlug(input.orgSlug);
    if (!org) return [];

    const supabase = await createClient();
    const { data: meta } = await supabase
        .from("doctype_meta")
        .select("table_name, title_field")
        .eq("doctype", input.doctype)
        .eq("is_child", false)
        .maybeSingle();
    if (!meta) return [];

    const title = meta.title_field ?? "name";
    const term = (input.q ?? "").replace(/[%_\\]/g, (c) => `\\${c}`).trim();
    const ids = (input.ids ?? []).filter((id) => UUID.test(id));

    const [found, selected] = await Promise.all([
        docTable(supabase, meta.table_name).select(`id, ${title}`).eq("org_id", org.id).ilike(title, `%${term}%`).order(title).limit(20),
        ids.length
            ? docTable(supabase, meta.table_name).select(`id, ${title}`).eq("org_id", org.id).in("id", ids)
            : Promise.resolve({ data: [] }),
    ]);

    const options = new Map<string, LinkOption>();
    const rows = [...(selected.data ?? []), ...(found.data ?? [])] as unknown as FieldValues[];
    for (const row of rows) {
        options.set(String(row.id), { id: String(row.id), label: String(row[title] ?? row.id) });
    }
    return [...options.values()];
}
