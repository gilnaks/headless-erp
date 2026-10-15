"use server";

import { randomUUID } from "node:crypto";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, fail } from "@/lib/errors";
import { getOrgBySlug } from "@/lib/queries/doc";
import { createClient } from "@/lib/supabase/server";

const BUCKET = "org-files";
const MAX_BYTES = 2 * 1024 * 1024;
/** Mirrors `storage.buckets.allowed_mime_types` for `org-files` (0118). */
const IMAGE_TYPES: Record<string, string> = { "image/png": "png", "image/jpeg": "jpg", "image/gif": "gif", "image/webp": "webp" };
/** Folders with storage policies (`app.file_doctype`). */
const FOLDERS = new Set(["letter-head"]);
const SIGNED_URL_SECONDS = 60 * 60;

/**
 * A one-time signed upload URL for an image below `<org_id>/<folder>/` (Frappe "Attach Image"). Storage RLS decides
 * whether the caller may write there; the browser uploads straight to Storage with the returned token.
 */
export async function createImageUpload(input: {
    orgSlug: string;
    folder: string;
    contentType: string;
    size: number;
}): Promise<ActionResult<{ path: string; token: string }>> {
    await requireUser(`/${input.orgSlug}`);
    if (!FOLDERS.has(input.folder)) return fail("Uploads are not allowed here.");
    const ext = IMAGE_TYPES[input.contentType];
    if (!ext) return fail("Upload a PNG, JPEG, GIF or WebP image.");
    if (input.size > MAX_BYTES) return fail("Images must be 2 MB or smaller.");
    const org = await getOrgBySlug(input.orgSlug);
    if (!org) return fail("Organization not found.");

    const supabase = await createClient();
    const path = `${org.id}/${input.folder}/${randomUUID()}.${ext}`;
    const { data, error } = await supabase.storage.from(BUCKET).createSignedUploadUrl(path);
    if (error || !data) return fail("You cannot upload files here.");
    return { ok: true, data: { path: data.path, token: data.token } };
}

/** Short-lived read URLs for the caller's org files (Storage RLS: members only); unknown paths map to null. */
export async function signedFileUrls(input: { orgSlug: string; paths: string[] }): Promise<Record<string, string | null>> {
    await requireUser(`/${input.orgSlug}`);
    const paths = [...new Set(input.paths.filter(Boolean))];
    if (!paths.length) return {};
    const supabase = await createClient();
    const { data } = await supabase.storage.from(BUCKET).createSignedUrls(paths, SIGNED_URL_SECONDS);
    const out: Record<string, string | null> = Object.fromEntries(paths.map((p) => [p, null]));
    for (const item of data ?? []) if (item.path && !item.error) out[item.path] = item.signedUrl;
    return out;
}
