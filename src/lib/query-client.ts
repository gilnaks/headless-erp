import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient({
    defaultOptions: {
        queries: { staleTime: 0, retry: 1, refetchOnWindowFocus: true },
    },
});

/** Drop cached reads after a mutation. `tag` is `org:<orgId>:<doctype>` when a doctype is known. */
export function updateTag(tag: string) {
    const parts = tag.split(":");
    if (parts[0] === "org" && parts.length >= 3) {
        void queryClient.invalidateQueries({ queryKey: ["org", parts[1], parts.slice(2).join(":")] });
        return;
    }
    void queryClient.invalidateQueries();
}

export function refresh() {
    void queryClient.invalidateQueries();
}
