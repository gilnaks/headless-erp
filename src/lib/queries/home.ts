import { ONBOARDING_STEP_KEYS, type OnboardingState, type OnboardingStepKey } from "@/lib/onboarding";
import { createClient } from "@/lib/supabase/client";

/** The org's onboarding checklist (RLS: members read). */
export async function getOnboarding(orgId: string): Promise<OnboardingState> {
    const supabase = await createClient();
    const [{ data: rows, error }, { data: org }] = await Promise.all([
        supabase.from("onboarding_progress").select("step, completed_at, skipped_at").eq("org_id", orgId).order("idx"),
        supabase.from("organizations").select("onboarding_dismissed_at").eq("id", orgId).maybeSingle(),
    ]);
    if (error) throw new Error("Could not load the onboarding checklist");
    return {
        steps: (rows ?? [])
            .filter((r) => (ONBOARDING_STEP_KEYS as readonly string[]).includes(r.step))
            .map((r) => ({
                step: r.step as OnboardingStepKey,
                status: r.completed_at ? "completed" : r.skipped_at ? "skipped" : "open",
            })),
        dismissed: Boolean(org?.onboarding_dismissed_at),
    };
}

/** Companies in the org; zero means the setup wizard has not run. */
export async function countCompanies(orgId: string): Promise<number> {
    const supabase = await createClient();
    const { count } = await supabase.from("companies").select("id", { count: "exact", head: true }).eq("org_id", orgId);
    return count ?? 0;
}
