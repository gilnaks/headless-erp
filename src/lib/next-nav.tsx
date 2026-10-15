import { useRouterState, useRouter as useTanStackRouter } from "@tanstack/react-router";
import type { AnchorHTMLAttributes, ReactNode } from "react";
import { refresh } from "@/lib/query-client";

function go(router: ReturnType<typeof useTanStackRouter>, href: string, replace = false) {
    if (replace) router.history.replace(href);
    else router.history.push(href);
}

/** Same shape as `next/navigation`'s `useRouter` for the shell and forms. */
export function useRouter() {
    const router = useTanStackRouter();
    return {
        push: (href: string) => go(router, href),
        replace: (href: string) => go(router, href, true),
        refresh: () => refresh(),
        back: () => window.history.back(),
    };
}

export function usePathname(): string {
    return useRouterState({ select: (state) => state.location.pathname });
}

export function useSearchParams(): URLSearchParams {
    const search = useRouterState({ select: (state) => state.location.searchStr });
    return new URLSearchParams(search.startsWith("?") ? search.slice(1) : search);
}

type LinkProps = AnchorHTMLAttributes<HTMLAnchorElement> & { href: string; children?: ReactNode; replace?: boolean };

/** Client-side link. Same `href` prop the screens already pass. */
export function Link({ href, replace, onClick, ...rest }: LinkProps) {
    const router = useTanStackRouter();
    return (
        <a
            href={href}
            onClick={(event) => {
                onClick?.(event);
                if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
                    return;
                event.preventDefault();
                go(router, href, replace);
            }}
            {...rest}
        />
    );
}
