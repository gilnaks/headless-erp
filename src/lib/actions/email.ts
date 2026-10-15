import { z } from "zod";
import type { Doctype, FieldValues } from "@/doctypes/define";
import { getDoctypeByName } from "@/doctypes/registry";
import { appUrl } from "@/lib/app-url";
import { type AuthClaims, requireUser } from "@/lib/auth/claims";
import { dispatchEmail } from "@/lib/email/dispatch";
import { escapeHtml, renderTemplate, type TemplateContext } from "@/lib/email/render";
import { SEND_DOCUMENT_TEMPLATE } from "@/lib/email/templates";
import { type ActionResult, fail } from "@/lib/errors";
import { getDoc, getOrgBySlug } from "@/lib/queries/doc";
import { createClient } from "@/lib/supabase/client";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_RECIPIENTS = 20;
/** Fields that hold the record's own email address (Frappe composer `recipients` default). */
const RECIPIENT_FIELDS = ["contact_email", "email_id", "email"];

type DocRef = { orgSlug: string; doctype: string; id: string };

type Loaded = {
    claims: AuthClaims;
    org: { id: string; slug: string; name: string };
    d: Doctype;
    doc: FieldValues;
    companyId: string | null;
    context: TemplateContext;
};

/** The record (read with RLS: no access = not found), its company and the sender, as template context. */
async function load(ref: DocRef): Promise<Loaded | string> {
    const claims = await requireUser(`/${ref.orgSlug}`);
    const d = getDoctypeByName(ref.doctype);
    if (!d || d.single) return `${ref.doctype} cannot be emailed.`;
    if (!UUID.test(ref.id)) return `${d.doctype} not found.`;
    const org = await getOrgBySlug(ref.orgSlug);
    if (!org) return "Organization not found.";
    const doc = await getDoc(d, org.id, ref.id);
    if (!doc) return `${d.doctype} not found.`;

    const companyId = d.doctype === "Company" ? ref.id : typeof doc.company_id === "string" ? doc.company_id : null;
    const supabase = await createClient();
    const [{ data: company }, { data: profile }] = await Promise.all([
        companyId ? supabase.from("companies").select("*").eq("id", companyId).maybeSingle() : Promise.resolve({ data: null }),
        supabase.from("user_profile").select("full_name").eq("user_id", claims.userId).maybeSingle(),
    ]);
    const title = String(doc[d.titleField] ?? "");
    const context: TemplateContext = {
        doc: {
            ...doc,
            doctype: d.doctype,
            name: typeof doc.name === "string" && doc.name ? doc.name : title,
            print_url: `${await appUrl()}/print/${d.slug}/${ref.id}`,
        },
        company: (company as FieldValues | null) ?? {},
        user: { full_name: profile?.full_name ?? claims.email ?? "", email: claims.email ?? "" },
    };
    return { claims, org, d, doc, companyId, context };
}

export type EmailTemplateOption = { id: string; name: string };
export type EmailDraft = { to: string; subject: string; html: string; templates: EmailTemplateOption[] };

/**
 * Compose defaults for a record (Frappe `CommunicationComposer`): the record's email address and the template
 * rendered against it. `templateId` null = the app's `Send Document` template.
 */
export async function getEmailDraft(input: DocRef & { templateId?: string | null }): Promise<ActionResult<EmailDraft>> {
    const loaded = await load(input);
    if (typeof loaded === "string") return fail(loaded);
    const { org, doc, context } = loaded;

    const supabase = await createClient();
    const { data: rows } = await supabase
        .from("email_template")
        .select("id, name, subject, use_html, response_html, response")
        .eq("org_id", org.id)
        .order("name");
    const templates = (rows ?? []).map((t) => ({ id: t.id, name: t.name }));

    let template = { subject: SEND_DOCUMENT_TEMPLATE.subject, body: SEND_DOCUMENT_TEMPLATE.html, html: true };
    if (input.templateId) {
        const row = rows?.find((t) => t.id === input.templateId);
        if (!row) return fail("Email Template not found.");
        template = row.use_html
            ? { subject: row.subject, body: row.response_html ?? "", html: true }
            : { subject: row.subject, body: row.response ?? "", html: false };
    }

    try {
        const body = renderTemplate(template.body, context, { html: template.html });
        const to = RECIPIENT_FIELDS.map((f) => doc[f]).find((v): v is string => typeof v === "string" && v.includes("@")) ?? "";
        return {
            ok: true,
            data: {
                to,
                subject: renderTemplate(template.subject, context),
                html: template.html ? body : escapeHtml(body).replace(/\n/g, "<br>"),
                templates,
            },
        };
    } catch (e) {
        return fail(`The template could not be rendered: ${e instanceof Error ? e.message : String(e)}`);
    }
}

function parseAddresses(value: string): string[] | null {
    const items = value
        .split(/[,;\s]+/)
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean);
    return items.every((s) => z.email().safeParse(s).success) ? [...new Set(items)] : null;
}

const sendSchema = z.object({
    to: z.string(),
    cc: z.string(),
    subject: z.string().trim().min(1, "Subject is required").max(300),
    html: z.string().trim().min(1, "Message is required").max(200_000),
});

/**
 * Emails a record (Frappe `make` communication): body sanitized, sent through the company's / org's Email Account
 * (else the platform sender) and logged to `email_log` against the record. No PDF attachment (00-setup §9).
 */
export async function sendDocumentEmail(
    input: DocRef & z.input<typeof sendSchema>,
): Promise<ActionResult<{ to: string[]; dryRun: boolean }>> {
    const parsed = sendSchema.safeParse(input);
    if (!parsed.success) {
        const issue = parsed.error.issues[0];
        return fail(issue.message, { [String(issue.path[0])]: issue.message });
    }
    const to = parseAddresses(parsed.data.to);
    const cc = parseAddresses(parsed.data.cc);
    if (!to?.length) return fail("Enter at least one valid recipient.", { to: "Enter valid email addresses, separated by commas" });
    if (!cc) return fail("Check the CC addresses.", { cc: "Enter valid email addresses, separated by commas" });
    if (to.length + cc.length > MAX_RECIPIENTS) return fail(`Send to at most ${MAX_RECIPIENTS} recipients at once.`);

    const loaded = await load(input);
    if (typeof loaded === "string") return fail(loaded);
    const { claims, org, d, companyId, context } = loaded;

    const supabase = await createClient();
    const { data: cleanHtml, error: cleanError } = await supabase.rpc("sanitize_html", { p_html: parsed.data.html });
    if (cleanError || cleanHtml == null) return fail("The message could not be prepared.");

    const result = await dispatchEmail({
        kind: "account",
        orgId: org.id,
        companyId,
        userName: String(context.user?.full_name ?? "") || null,
        userEmail: claims.email,
        to,
        cc,
        subject: parsed.data.subject,
        html: cleanHtml,
        reference: { doctype: d.doctype, id: input.id },
        sentBy: claims.userId,
    });
    if (!result.ok) return fail(`The email was not sent: ${result.error}`);
    return { ok: true, data: { to: [...to, ...cc], dryRun: result.dryRun } };
}
