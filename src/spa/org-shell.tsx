import { useQuery } from "@tanstack/react-query";
import { Outlet, useParams } from "@tanstack/react-router";
import { FormAlert } from "@/components/erp/form-alert";
import { AppShell } from "@/components/erp/shell/app-shell";
import { ClaimsRefresher } from "@/components/erp/shell/claims-refresher";
import { ShellSkeleton } from "@/components/erp/shell/shell-skeleton";
import { NotFoundError, Redirecting } from "@/lib/navigate";
import { loadOrgShell } from "@/screens/(app)/[org]/layout";
import NotFound from "@/screens/not-found";

/** Org chrome. Reloads when the slug changes; child routes render through the outlet. */
export function OrgShell() {
    const { org: slug } = useParams({ strict: false }) as { org: string };
    const query = useQuery({
        queryKey: ["org-shell", slug],
        queryFn: () => loadOrgShell(slug),
        retry: (failureCount, error) => !(error instanceof NotFoundError) && !(error instanceof Redirecting) && failureCount < 1,
    });

    if (query.isLoading) return <ShellSkeleton />;
    if (query.error instanceof NotFoundError) return <NotFound />;
    if (query.error instanceof Redirecting) return <ShellSkeleton />;
    if (query.error || !query.data) return <FormAlert>{query.error?.message ?? "The organization could not be loaded."}</FormAlert>;

    const data = query.data;
    return (
        <AppShell
            org={data.org}
            orgs={data.orgs}
            companies={data.companies}
            companyId={data.companyId}
            roles={data.roles}
            creatable={data.creatable}
            user={data.user}
        >
            {data.stale && <ClaimsRefresher signature={data.signature} />}
            <Outlet />
        </AppShell>
    );
}
