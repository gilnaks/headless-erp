import { type Doctype, type FieldValues, layoutFields } from "@/doctypes/define";
import { DOCTYPES } from "@/doctypes/registry";
import { formatAddress } from "@/lib/format/address";
import { type LinkTitles, linkRequests, titleKey } from "@/lib/link-titles";
import {
    DEFAULT_PRINT_SETTINGS,
    type PrintFormatLike,
    type PrintSettingsLike,
    pickPrintFormat,
    printBlockedReason,
    resolveLetterHeadId,
    showDraftHeading,
} from "@/lib/print/resolve";
import { docTable, getDoc } from "@/lib/queries/doc";
import { getLinkTitles } from "@/lib/queries/links";
import { createClient } from "@/lib/supabase/client";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SIGNED_URL_SECONDS = 60 * 60;

export type LetterHeadBlock =
    | { kind: "html"; html: string }
    | { kind: "image"; url: string; height: number | null; width: number | null; align: string }
    | null;

export type PrintContext = {
    d: Doctype;
    doc: FieldValues;
    org: { id: string; slug: string };
    titles: LinkTitles;
    settings: PrintSettingsLike;
    formats: PrintFormatLike[];
    format: PrintFormatLike | null;
    letterHead: { header: LetterHeadBlock; footer: LetterHeadBlock } | null;
    /** Frappe `validate_print_permission` message when the docstatus cannot be printed. */
    blocked: string | null;
    draftHeading: boolean;
    /** The company's preferred billing address as display lines (ERPNext `get_default_company_address`). */
    companyAddress: string[] | null;
};

/** Printable doctype for the `/print/[doctype]` segment (the descriptor slug). */
export function printDoctype(slug: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.slug === slug && !d.single);
}

async function resolveTitles(d: Doctype, orgId: string, doc: FieldValues): Promise<LinkTitles> {
    const requests: [string, string[]][] = [...linkRequests(d.fields, layoutFields(d), [doc])];
    for (const [name, child] of Object.entries(d.children)) {
        const rows = Array.isArray(doc[name]) ? (doc[name] as FieldValues[]) : [];
        requests.push(...linkRequests(child.fields, child.columns, rows));
    }
    const resolved = await Promise.all(requests.map(([doctype, ids]) => getLinkTitles(orgId, doctype, ids)));
    const titles: LinkTitles = {};
    requests.forEach(([doctype], i) => {
        for (const option of resolved[i]) titles[titleKey(doctype, option.id)] = option.label;
    });
    return titles;
}

type LetterHeadRow = {
    source: string;
    content: string | null;
    image: string | null;
    image_height: number | null;
    image_width: number | null;
    align: string;
    footer_source: string;
    footer: string | null;
    footer_image: string | null;
    footer_image_height: number | null;
    footer_image_width: number | null;
    footer_align: string;
};

async function letterHeadBlocks(supabase: Awaited<ReturnType<typeof createClient>>, row: LetterHeadRow) {
    const paths = [row.source === "Image" ? row.image : null, row.footer_source === "Image" ? row.footer_image : null].filter(
        (p): p is string => Boolean(p),
    );
    const urls: Record<string, string> = {};
    if (paths.length) {
        const { data } = await supabase.storage.from("org-files").createSignedUrls(paths, SIGNED_URL_SECONDS);
        for (const item of data ?? []) if (item.path && item.signedUrl && !item.error) urls[item.path] = item.signedUrl;
    }
    const block = (
        source: string,
        html: string | null,
        image: string | null,
        height: number | null,
        width: number | null,
        align: string,
    ) => {
        if (source === "Image") return image && urls[image] ? { kind: "image" as const, url: urls[image], height, width, align } : null;
        // Stored HTML is sanitized by app.sanitize_html on every write.
        return html?.trim() ? { kind: "html" as const, html } : null;
    };
    return {
        header: block(row.source, row.content, row.image, row.image_height, row.image_width, row.align),
        footer: block(row.footer_source, row.footer, row.footer_image, row.footer_image_height, row.footer_image_width, row.footer_align),
    };
}

/**
 * Everything the print view needs, read with the caller's client: RLS decides whether the record is visible (null =
 * missing or another organization's). Letter head: document → company default → Print Settings → org default.
 */
export async function getPrintContext(slug: string, id: string, formatId?: string | null): Promise<PrintContext | null> {
    const d = printDoctype(slug);
    if (!d || !UUID.test(id)) return null;

    const supabase = await createClient();
    const { data: head } = await docTable(supabase, d.table).select("org_id").eq("id", id).maybeSingle();
    const orgId = (head as { org_id?: string } | null)?.org_id;
    if (!orgId) return null;
    const doc = await getDoc(d, orgId, id);
    if (!doc) return null;

    const companyId = d.doctype === "Company" ? id : typeof doc.company_id === "string" ? doc.company_id : null;
    const [{ data: org }, { data: settingsRow }, { data: formatRows }, { data: orgDefault }, { data: company }, titles, { data: address }] =
        await Promise.all([
            supabase.from("organizations").select("id, slug").eq("id", orgId).single(),
            supabase.from("print_settings").select("*").eq("org_id", orgId).maybeSingle(),
            supabase
                .from("print_format")
                .select("id, name, template_key, is_default, disabled")
                .eq("org_id", orgId)
                .eq("doc_type", d.doctype)
                .order("name"),
            supabase.from("letter_head").select("id").eq("org_id", orgId).eq("is_default", true).eq("disabled", false).maybeSingle(),
            companyId
                ? supabase.from("companies").select("default_letter_head_id").eq("id", companyId).maybeSingle()
                : Promise.resolve({ data: null }),
            resolveTitles(d, orgId, doc),
            companyId ? supabase.rpc("company_address", { p_company: companyId }).maybeSingle() : Promise.resolve({ data: null }),
        ]);
    if (!org) return null;

    const settings: PrintSettingsLike = settingsRow
        ? {
              ...DEFAULT_PRINT_SETTINGS,
              ...settingsRow,
              font_size: Number(settingsRow.font_size),
              pdf_page_height: settingsRow.pdf_page_height === null ? null : Number(settingsRow.pdf_page_height),
              pdf_page_width: settingsRow.pdf_page_width === null ? null : Number(settingsRow.pdf_page_width),
          }
        : DEFAULT_PRINT_SETTINGS;

    const letterHeadId = resolveLetterHeadId(
        {
            document: typeof doc.letter_head_id === "string" ? doc.letter_head_id : null,
            company: company?.default_letter_head_id ?? null,
            settings: settings.letter_head_id,
            orgDefault: orgDefault?.id ?? null,
        },
        settings.with_letterhead,
    );
    let letterHead: PrintContext["letterHead"] = null;
    if (letterHeadId) {
        const { data: row } = await supabase.from("letter_head").select("*").eq("id", letterHeadId).eq("disabled", false).maybeSingle();
        if (row) letterHead = await letterHeadBlocks(supabase, row);
    }

    const formats = (formatRows ?? []) as PrintFormatLike[];
    const docstatus = Number(doc.docstatus ?? 0);
    return {
        d,
        doc,
        org,
        titles,
        settings,
        formats: formats.filter((f) => !f.disabled),
        format: pickPrintFormat(formats, formatId),
        letterHead,
        blocked: printBlockedReason(docstatus, settings),
        draftHeading: showDraftHeading(docstatus, d.submittable, settings),
        companyAddress: address ? formatAddress(address) : null,
    };
}
