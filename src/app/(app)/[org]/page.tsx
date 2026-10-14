import { Suspense } from "react";
import { PlaceholderPage } from "@/components/erp/placeholder-page";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { createClient } from "@/lib/supabase/server";

type OrgPageProps = { params: Promise<{ org: string }> };

async function OrgHomeBody({ params }: OrgPageProps) {
    const { org: slug } = await params;
    const supabase = await createClient();
    const { data: org } = await supabase.from("organizations").select("id, name").eq("slug", slug).maybeSingle();
    const { count } = org
        ? await supabase.from("companies").select("id", { count: "exact", head: true }).eq("org_id", org.id)
        : { count: 0 };

    const description =
        (count ?? 0) === 0
            ? "Your organization is ready. Next comes the setup wizard: first company, fiscal year, chart of accounts and defaults. Until then, use the module rail to explore what is planned."
            : "The home workspace (onboarding checklist, number cards and charts) is planned for phase P1. Use the module rail to explore.";

    return <PlaceholderPage title={`Welcome to ${org?.name ?? slug}`} description={description} phase="P1" />;
}

export default function OrgHomePage(props: OrgPageProps) {
    return (
        <Suspense fallback={<PageSkeleton />}>
            <OrgHomeBody {...props} />
        </Suspense>
    );
}
