"use server";

import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, dbError, fail, zodFieldErrors } from "@/lib/errors";
import { type CreateOrganizationInput, createOrganizationSchema } from "@/lib/schemas/organization";
import { createClient } from "@/lib/supabase/server";

export async function createOrganization(input: CreateOrganizationInput): Promise<ActionResult> {
    await requireUser("/setup");
    const parsed = createOrganizationSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const supabase = await createClient();
    const { data, error } = await supabase.rpc("create_organization", { p: parsed.data });
    if (error) {
        const { code, message } = dbError(error);
        if (code === "slug_taken" || code === "slug_reserved" || code === "invalid_slug")
            return fail("Choose a different URL.", { slug: message });
        return fail(message);
    }

    // Re-issue the access token so `app.orgs` in the JWT includes the new organization.
    await supabase.auth.refreshSession();
    redirect(`/${(data as { slug: string }).slug}`);
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
