import { ONBOARDING_STEP_KEYS, type OnboardingState, type OnboardingStepKey } from "@/lib/onboarding";
import { loadProfitAndLoss, type ProfitAndLossChart } from "@/lib/queries/profit-and-loss";
import { createClient } from "@/lib/supabase/client";

function isoDate(date: Date): string {
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

/** Yearly Profit and Loss for the org's only company, or the first company when there are several. */
export async function loadHomeProfitChart(orgId: string): Promise<ProfitAndLossChart | null> {
    const supabase = createClient();
    const { data: companies } = await supabase.from("companies").select("id").eq("org_id", orgId).order("name").limit(1);
    const company = companies?.[0]?.id;
    if (!company) return null;
    const { data: years } = await supabase
        .from("fiscal_year")
        .select("id, year_start_date, year_end_date")
        .eq("org_id", orgId)
        .order("year_start_date", { ascending: false });
    const today = isoDate(new Date());
    const current = (years ?? []).find((year) => year.year_start_date <= today && year.year_end_date >= today) ?? years?.[0];
    if (!current) return null;
    const report = await loadProfitAndLoss({
        company,
        basis: "Fiscal Year",
        fromFiscalYear: current.id,
        toFiscalYear: current.id,
        from: current.year_start_date,
        to: current.year_end_date,
        periodicity: "Yearly",
        accumulated: false,
        showZero: false,
    });
    if (report.error) return null;
    return report.chart;
}

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
