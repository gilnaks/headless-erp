import { cookies } from "next/headers";
import { notFound } from "next/navigation";
import { type ReactNode, Suspense } from "react";
import { AppShell } from "@/components/erp/shell/app-shell";
import { ShellSkeleton } from "@/components/erp/shell/shell-skeleton";
import { requireUser } from "@/lib/auth/claims";
import { createClient } from "@/lib/supabase/server";
import { COMPANY_COOKIE } from "@/stores/session-cookie";

type OrgLayoutProps = { children: ReactNode; params: Promise<{ org: string }> };

async function OrgShell({ children, params }: OrgLayoutProps) {
    const { org: slug } = await params;
    const claims = await requireUser(`/${slug}`);
    const supabase = await createClient();

    // RLS only returns organizations the user is an active member of, so a foreign slug is a 404.
    const { data: orgs } = await supabase.from("organizations").select("id, slug, name").order("name");
    const org = orgs?.find((o) => o.slug === slug);
    if (!org) notFound();

    const [{ data: companies }, { data: profile }, cookieStore] = await Promise.all([
        supabase.from("companies").select("id, company_name, abbr").eq("org_id", org.id).order("company_name"),
        supabase.from("user_profile").select("full_name, avatar_url").eq("user_id", claims.userId).maybeSingle(),
        cookies(),
    ]);

    const cookieCompany = cookieStore.get(COMPANY_COOKIE)?.value;
    const companyId = companies?.find((c) => c.id === cookieCompany)?.id ?? companies?.[0]?.id ?? null;

    return (
        <AppShell
            org={org}
            orgs={orgs ?? []}
            companies={companies ?? []}
            companyId={companyId}
            roles={claims.orgs[org.id] ?? []}
            user={{ email: claims.email, name: profile?.full_name ?? null, avatarUrl: profile?.avatar_url ?? null }}
        >
            {children}
        </AppShell>
    );
}

export default function OrgLayout(props: OrgLayoutProps) {
    return (
        <Suspense fallback={<ShellSkeleton />}>
            <OrgShell {...props} />
        </Suspense>
    );
}
