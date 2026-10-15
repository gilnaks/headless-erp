const PUBLIC_EXACT = new Set(["/login", "/signup", "/forgot-password", "/update-password", "/auth/callback", "/health"]);

/** Paths that render without a session. Everything else sends the visitor to sign in. */
export function isPublicPath(pathname: string): boolean {
    if (PUBLIC_EXACT.has(pathname)) return true;
    return pathname.startsWith("/invite/");
}

/** Where a signed-out visit to `pathname` should go, or null when the path is public. */
export function signedOutRedirect(pathname: string): string | null {
    if (isPublicPath(pathname)) return null;
    const next = pathname === "/" ? null : pathname;
    return next ? `/login?next=${encodeURIComponent(next)}` : "/login";
}
