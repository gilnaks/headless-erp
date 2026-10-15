import { useQuery } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { FormAlert } from "@/components/erp/form-alert";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { NotFoundError, Redirecting } from "@/lib/navigate";
import NotFound from "@/screens/not-found";

type AsyncPageProps = {
    queryKey: readonly unknown[];
    load: () => Promise<ReactNode>;
};

/** Runs a page loader through the query cache so a mutation can invalidate it. */
export function AsyncPage({ queryKey, load }: AsyncPageProps) {
    const query = useQuery({
        queryKey,
        queryFn: () => load(),
        retry: (failureCount, error) => !(error instanceof NotFoundError) && !(error instanceof Redirecting) && failureCount < 1,
    });

    if (query.isLoading) return <PageSkeleton />;
    if (query.error instanceof NotFoundError) return <NotFound />;
    if (query.error instanceof Redirecting) return <PageSkeleton />;
    if (query.error) return <FormAlert>{query.error.message}</FormAlert>;
    return query.data;
}
