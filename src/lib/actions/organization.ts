import { requireUser } from "@/lib/auth/claims";
import { emailInvitation } from "@/lib/email/invitation";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { redirect } from "@/lib/navigate";
import { type ProvisionOrganizationInput, provisionOrganizationSchema } from "@/lib/schemas/organization";
import { createClient } from "@/lib/supabase/client";

/** Database error code → wizard field (`app.provision_organization` and the triggers it runs). */
const FIELD_FOR: Record<string, string> = {
    slug_taken: "org.slug",
    slug_reserved: "org.slug",
    invalid_slug: "org.slug",
    name_required: "org.name",
    country_unknown: "org.country",
    currency_unknown: "org.default_currency",
    company_name_required: "company.company_name",
    abbr_required: "company.abbr",
    abbr_taken: "company.abbr",
    coa_unknown: "company.chart_of_accounts",
    fiscal_year_dates: "company.fy_start_date",
    invalid_email: "invites",
    already_member: "invites",
    invite_pending: "invites",
};

/** Setup wizard submit (frappe `setup_complete`): one `provision_organization` call, then into the new organization. */
export async function provisionOrganization(input: ProvisionOrganizationInput): Promise<ActionResult> {
    const claims = await requireUser("/setup");
    const parsed = provisionOrganizationSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const { org, company, invites } = parsed.data;
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("provision_organization", {
        p: { org, company, invites: invites.map((i) => ({ email: i.email, roles: [], role_profile: i.role_profile })) },
    });
    if (error) {
        const { code, message } = dbError(error);
        const field = FIELD_FOR[code];
        return field ? fail(message, { [field]: message }) : fail(message);
    }

    // Re-issue the access token so `app.orgs` in the JWT includes the new organization.
    await supabase.auth.refreshSession();
    const created = data as { id: string; slug: string };

    // Best effort: a failed send leaves the invitation open; the Users page can resend or copy the link.
    if (invites.length) {
        const { data: invitations } = await supabase
            .from("invitations")
            .select("id, token")
            .eq("org_id", created.id)
            .is("accepted_at", null);
        for (const invitation of invitations ?? []) {
            await emailInvitation({ id: created.id, name: org.name }, invitation, claims).catch(() => null);
        }
    }
    redirect(`/${created.slug}`);
}

export type ChartOption = { name: string; isDefault: boolean };
export type ChartAccount = { idx: number; account: string; depth: number; isGroup: boolean; rootType: string };

/** `get_charts_for_country(country, with_standard=True)`: the country's charts, then the standard ones. */
export async function chartsForCountry(country: string): Promise<ChartOption[]> {
    await requireUser("/setup");
    const supabase = await createClient();
    const { data } = await supabase.rpc("coa_templates_for_country", { p_country: country });
    return (data ?? []).map((r) => ({ name: r.name, isDefault: r.is_default }));
}

/** Read-only tree of a chart template (setup wizard "View Chart of Accounts"). */
export async function chartPreview(template: string): Promise<ChartAccount[]> {
    await requireUser("/setup");
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("coa_template_preview", { p_template: template });
    if (error) throw new Error(dbError(error).message);
    return (data ?? []).map((r) => ({ idx: r.idx, account: r.account, depth: r.depth, isGroup: r.is_group, rootType: r.root_type }));
}

export async function acceptInvitation(token: string): Promise<ActionResult> {
    await requireUser(`/invite/${encodeURIComponent(token)}`);

    const supabase = await createClient();
    const { data: orgId, error } = await supabase.rpc("accept_invitation", { p_token: token });
    if (error) return fail(dbError(error).message);

    await supabase.auth.refreshSession();
    const { data: org } = await supabase.from("organizations").select("slug").eq("id", orgId).single();
    redirect(org ? `/${org.slug}` : "/");
}
