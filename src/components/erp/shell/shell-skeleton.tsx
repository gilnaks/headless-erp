const placeholders = (count: number, prefix: string) => Array.from({ length: count }, (_, n) => `${prefix}-${n}`);

const RAIL = placeholders(7, "rail");
const SIDEBAR = placeholders(8, "side");
const ROWS = placeholders(6, "row");

/** Static stand-in for AppShell while the org layout loads (same rail/sidebar/top bar geometry). */
export function ShellSkeleton() {
    return (
        <div className="flex h-dvh overflow-hidden bg-primary" aria-busy="true">
            <div className="flex max-lg:hidden">
                <div className="flex w-16 flex-col items-center gap-2 border-r border-secondary py-3">
                    <div className="mb-3 size-9 animate-pulse rounded-lg bg-tertiary" />
                    {RAIL.map((key) => (
                        <div key={key} className="size-10 animate-pulse rounded-md bg-secondary" />
                    ))}
                </div>
                <div className="flex w-60 flex-col gap-2 border-r border-secondary px-3 py-4">
                    <div className="mb-2 h-4 w-24 animate-pulse rounded bg-tertiary" />
                    {SIDEBAR.map((key) => (
                        <div key={key} className="h-8 animate-pulse rounded-md bg-secondary" />
                    ))}
                </div>
            </div>
            <div className="flex min-w-0 flex-1 flex-col">
                <div className="flex h-14 items-center gap-3 border-b border-secondary px-4">
                    <div className="h-6 w-40 animate-pulse rounded bg-secondary" />
                    <div className="ml-auto size-8 animate-pulse rounded-full bg-secondary" />
                </div>
                <div className="px-4 py-5 lg:px-8 lg:py-6">
                    <PageSkeleton />
                </div>
            </div>
        </div>
    );
}

export function PageSkeleton() {
    return (
        <div className="flex flex-col gap-4" aria-busy="true">
            <div className="h-7 w-56 animate-pulse rounded bg-tertiary" />
            <div className="h-4 w-80 animate-pulse rounded bg-secondary" />
            <div className="mt-4 flex flex-col gap-2">
                {ROWS.map((key) => (
                    <div key={key} className="h-9 animate-pulse rounded bg-secondary" />
                ))}
            </div>
        </div>
    );
}
