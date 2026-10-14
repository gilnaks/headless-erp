const BASE = "http://n.invalid";

/** Appends `?next=` to an auth page link unless `next` is the default "/". */
export function withNext(pathname: string, next: string | null | undefined): string {
    const target = safeNext(next);
    return target === "/" ? pathname : `${pathname}?next=${encodeURIComponent(target)}`;
}

/** Returns `next` only when it is a same-origin absolute path; anything else (other hosts, `//x`, `/\x`, schemes) yields `fallback`. */
export function safeNext(next: string | null | undefined, fallback = "/"): string {
    if (!next?.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return fallback;
    try {
        const url = new URL(next, BASE);
        if (url.origin !== BASE) return fallback;
        return `${url.pathname}${url.search}${url.hash}`;
    } catch {
        return fallback;
    }
}
