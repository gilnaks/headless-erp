"use server";

import { refresh, updateTag } from "next/cache";
import { redirect } from "next/navigation";
import { docPath, type FieldValues } from "@/doctypes/define";
import { getDoctypeByName } from "@/doctypes/registry";
import { formToPayload, schemaFor } from "@/doctypes/schema";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { sanitizeHtml } from "@/lib/html/sanitize";
import type { LinkOption } from "@/lib/link-titles";
import { getOrgBySlug } from "@/lib/queries/doc";
import { getLinkTitles, searchLinkTitles } from "@/lib/queries/links";
import { createClient } from "@/lib/supabase/server";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type { LinkOption };

function docTag(orgId: string, doctype: string): string {
    return `org:${orgId}:${doctype}`;
}

/**
 * Generic save (frappe `Document.save`): Zod parse with the doctype's schema, HTML fields sanitized, then `app.save_doc` (RLS authorizes), or
 * the descriptor's `create` RPC for new documents. New documents redirect to their form; edits refresh the route.
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
    if (d.single && input.id === null) return fail(`${d.doctype} cannot be created.`);

    const parsed = schemaFor(d).safeParse(input.values);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const values = { ...(parsed.data as FieldValues) };
    for (const [name, field] of Object.entries(d.fields)) {
        if (field.html && typeof values[name] === "string") values[name] = sanitizeHtml(values[name]);
    }

    const isNew = input.id === null;
    const payload = { ...formToPayload(d, values, { isNew }), ...(isNew ? { org_id: org.id } : { id: input.id }) };

    const supabase = await createClient();
    const { data, error } =
        isNew && d.create
            ? await supabase.rpc(d.create, { p: payload })
            : await supabase.rpc("save_doc", { p_doctype: d.doctype, p_payload: payload });
    if (error) {
        const { code, message } = dbError(error);
        const field = d.errorFields[code];
        return field ? fail(message, { [field]: message }) : fail(message);
    }

    const id = (data as { id: string }).id;
    for (const [name, field] of Object.entries(d.fields)) {
        const secret = values[name];
        if (field.type !== "Password" || !field.secretRpc || typeof secret !== "string" || !secret.trim()) continue;
        const { error: secretError } = await supabase.rpc(field.secretRpc, { p_id: id, p_secret: secret });
        if (secretError) {
            updateTag(docTag(org.id, d.doctype));
            const message = `${d.doctype} saved, but ${field.label} was not: ${dbError(secretError).message}`;
            if (isNew) redirect(`/${org.slug}/${docPath(d)}/${id}`);
            return fail(message, { [name]: message });
        }
    }

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
    if (d.single) return fail(`${d.doctype} cannot be deleted.`);

    const supabase = await createClient();
    const { error } = await supabase.rpc("delete_doc", { p_doctype: d.doctype, p_id: input.id });
    if (error) return fail(dbError(error).message);

    updateTag(docTag(org.id, d.doctype));
    redirect(`/${org.slug}/${docPath(d)}`);
}

/**
 * Options for a Link field: records of `doctype` whose title matches `q`, plus the labels of `ids` (the current
 * value). Any doctype in `doctype_meta` works, so Links can target doctypes without a descriptor yet; `User` lists
 * the organization's members.
 */
export async function searchLink(input: { orgSlug: string; doctype: string; q?: string; ids?: string[] }): Promise<LinkOption[]> {
    await requireUser(`/${input.orgSlug}`);
    const org = await getOrgBySlug(input.orgSlug);
    if (!org) return [];

    const ids = (input.ids ?? []).filter((id) => UUID.test(id));
    const [selected, found] = await Promise.all([
        getLinkTitles(org.id, input.doctype, ids),
        searchLinkTitles(org.id, input.doctype, input.q ?? ""),
    ]);

    const options = new Map<string, LinkOption>();
    for (const option of [...selected, ...found]) options.set(option.id, option);
    return [...options.values()];
}
