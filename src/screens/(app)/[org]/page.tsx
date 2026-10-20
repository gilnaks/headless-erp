import { NumberCards, ProfitAndLossChart } from "@/components/erp/home/home-cards";
import { OnboardingCard } from "@/components/erp/home/onboarding-card";
import { PlaceholderPage } from "@/components/erp/placeholder-page";
import { notFound } from "@/lib/navigate";
import { showOnboarding } from "@/lib/onboarding";
import { getOrgBySlug } from "@/lib/queries/doc";
import { countCompanies, getOnboarding, loadHomeProfitChart } from "@/lib/queries/home";
import { getMyRoles } from "@/lib/queries/role-permissions";

type OrgPageProps = { params: Promise<{ org: string }> };

/** Home workspace (erpnext/setup/workspace/home/home.json): onboarding, Profit and Loss chart, number cards. */
async function OrgHomeBody({ params }: OrgPageProps) {
    const { org: slug } = await params;
    const org = await getOrgBySlug(slug);
    if (!org) notFound();

    const [companies, roles, onboarding, profit] = await Promise.all([
        countCompanies(org.id),
        getMyRoles(org.id),
        getOnboarding(org.id),
        loadHomeProfitChart(org.id),
    ]);
    if (companies === 0) {
        return (
            <PlaceholderPage
                title={`Welcome to ${org.name}`}
                description="Your organization is ready. Next comes the setup wizard: first company, fiscal year, chart of accounts and defaults."
            />
        );
    }

    return (
        <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-1 border-b border-secondary pb-5">
                <h1 className="text-display-xs font-semibold text-primary">Home</h1>
                <p className="text-sm text-tertiary">{org.name}</p>
            </div>
            {roles.includes("System Manager") && showOnboarding(onboarding) && (
                <OnboardingCard orgSlug={org.slug} steps={onboarding.steps} />
            )}
            <ProfitAndLossChart chart={profit} />
            <NumberCards />
        </div>
    );
}

export default function OrgHomePage(props: OrgPageProps) {
    return OrgHomeBody(props);
}
