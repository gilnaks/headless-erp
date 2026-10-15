import type { EmailOtpType, SupabaseClient } from "@supabase/supabase-js";
import { safeNext } from "@/lib/auth/redirect";

/** Turns an email-link landing (`/auth/callback`) into the path to open next. */
export async function completeAuthCallback(search: URLSearchParams, supabase: SupabaseClient): Promise<string> {
    const next = safeNext(search.get("next"));
    const code = search.get("code");
    const tokenHash = search.get("token_hash");
    const type = search.get("type") as EmailOtpType | null;

    let error: { message: string } | null = null;
    if (code) {
        ({ error } = await supabase.auth.exchangeCodeForSession(code));
    } else if (tokenHash && type) {
        ({ error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type }));
    } else {
        error = { message: search.get("error_description") ?? "Missing sign-in code" };
    }

    if (error) return "/login?error=link_invalid";
    return next;
}
