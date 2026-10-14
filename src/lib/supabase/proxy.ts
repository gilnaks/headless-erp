import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import { orgsFromClaims } from "@/lib/auth/orgs";
import type { Database } from "@/types/database";
import { supabasePublishableKey, supabaseUrl } from "./env";

const PUBLIC_PREFIXES = ["/login", "/signup", "/forgot-password", "/invite", "/auth", "/health"];

function isPublic(pathname: string): boolean {
    return pathname === "/" || PUBLIC_PREFIXES.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

/** Refreshes the Supabase session and applies route guards. Performs no data authorization. */
export async function updateSession(request: NextRequest) {
    let response = NextResponse.next({ request });

    const supabase = createServerClient<Database>(supabaseUrl(), supabasePublishableKey(), {
        cookies: {
            getAll() {
                return request.cookies.getAll();
            },
            setAll(cookiesToSet, headers) {
                for (const { name, value } of cookiesToSet) request.cookies.set(name, value);
                response = NextResponse.next({ request });
                for (const { name, value, options } of cookiesToSet) response.cookies.set(name, value, options);
                for (const [key, value] of Object.entries(headers ?? {})) response.headers.set(key, value);
            },
        },
    });

    // Must run immediately after client creation: it refreshes expired tokens.
    const { data } = await supabase.auth.getClaims();
    const userId = data?.claims?.sub;
    const { pathname } = request.nextUrl;

    if (!userId && !isPublic(pathname)) {
        const url = request.nextUrl.clone();
        url.pathname = "/login";
        url.search = "";
        url.searchParams.set("next", `${pathname}${request.nextUrl.search}`);
        return NextResponse.redirect(url);
    }

    if (userId && (pathname === "/login" || pathname === "/signup")) {
        return redirectKeepingCookies(request, response, "/");
    }

    if (userId && pathname === "/" && Object.keys(orgsFromClaims(data?.claims as Record<string, unknown>)).length === 0) {
        return redirectKeepingCookies(request, response, "/setup");
    }

    return response;
}

/** Redirects while carrying over any session cookies refreshed above. */
function redirectKeepingCookies(request: NextRequest, response: NextResponse, pathname: string) {
    const url = request.nextUrl.clone();
    url.pathname = pathname;
    url.search = "";
    const redirect = NextResponse.redirect(url);
    for (const cookie of response.cookies.getAll()) redirect.cookies.set(cookie);
    return redirect;
}
