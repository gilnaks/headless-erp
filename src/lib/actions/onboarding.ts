"use server";

import { refresh } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, dbError, fail } from "@/lib/errors";
import { ONBOARDING_STEP_KEYS } from "@/lib/onboarding";
import { getOrgBySlug } from "@/lib/queries/doc";
import { createClient } from "@/lib/supabase/server";

const skipSchema = z.object({ orgSlug: z.string().min(1), step: z.enum(ONBOARDING_STEP_KEYS) });
const dismissSchema = z.object({ orgSlug: z.string().min(1) });

/** Marks a checklist step as skipped (`app.onboarding_skip`: System Manager only). */
export async function skipOnboardingStep(input: z.infer<typeof skipSchema>): Promise<ActionResult> {
    const parsed = skipSchema.safeParse(input);
    if (!parsed.success) return fail("Unknown onboarding step.");
    await requireUser(`/${parsed.data.orgSlug}`);
    const org = await getOrgBySlug(parsed.data.orgSlug);
    if (!org) return fail("Organization not found.");
    const supabase = await createClient();
    const { error } = await supabase.rpc("onboarding_skip", { p_org: org.id, p_step: parsed.data.step });
    if (error) return fail(dbError(error).message);
    refresh();
    return { ok: true };
}

/** Hides the checklist for the whole organization (`app.onboarding_dismiss`: System Manager only). */
export async function dismissOnboarding(input: z.infer<typeof dismissSchema>): Promise<ActionResult> {
    const parsed = dismissSchema.safeParse(input);
    if (!parsed.success) return fail("Organization not found.");
    await requireUser(`/${parsed.data.orgSlug}`);
    const org = await getOrgBySlug(parsed.data.orgSlug);
    if (!org) return fail("Organization not found.");
    const supabase = await createClient();
    const { error } = await supabase.rpc("onboarding_dismiss", { p_org: org.id });
    if (error) return fail(dbError(error).message);
    refresh();
    return { ok: true };
}
