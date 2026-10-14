import type { EmailOtpType } from "@supabase/supabase-js";
import { type NextRequest, NextResponse } from "next/server";
import { safeNext } from "@/lib/auth/redirect";
import { createClient } from "@/lib/supabase/server";

/** Landing point for email links (signup confirmation, magic link, password recovery, invites). */
export async function GET(request: NextRequest) {
    const { searchParams, origin } = request.nextUrl;
    const next = safeNext(searchParams.get("next"));
    const code = searchParams.get("code");
    const tokenHash = searchParams.get("token_hash");
    const type = searchParams.get("type") as EmailOtpType | null;

    const supabase = await createClient();
    let error: { message: string } | null = null;

    if (code) {
        ({ error } = await supabase.auth.exchangeCodeForSession(code));
    } else if (tokenHash && type) {
        ({ error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type }));
    } else {
        error = { message: searchParams.get("error_description") ?? "Missing sign-in code" };
    }

    if (error) {
        const url = new URL("/login", origin);
        url.searchParams.set("error", "link_invalid");
        return NextResponse.redirect(url);
    }
    return NextResponse.redirect(new URL(next, origin));
}
