import type { z } from "zod";

export type FieldErrors = Record<string, string>;

export type ActionResult<T = undefined> = { ok: true; data?: T } | { ok: false; error: string; fieldErrors?: FieldErrors };

export function fail(error: string, fieldErrors?: FieldErrors): { ok: false; error: string; fieldErrors?: FieldErrors } {
    return fieldErrors ? { ok: false, error, fieldErrors } : { ok: false, error };
}

/** First message per top-level field. */
export function zodFieldErrors(error: z.ZodError): FieldErrors {
    const out: FieldErrors = {};
    for (const issue of error.issues) {
        const key = String(issue.path[0] ?? "form");
        out[key] ??= issue.message;
    }
    return out;
}

const AUTH_MESSAGES: Record<string, string> = {
    invalid_credentials: "Incorrect email or password.",
    email_not_confirmed: "Confirm your email address first. Check your inbox for the link.",
    user_already_exists: "An account with this email already exists. Sign in instead.",
    email_exists: "An account with this email already exists. Sign in instead.",
    email_address_invalid: "This email address cannot be used. Check it for typos or use another one.",
    email_address_not_authorized: "Emails can only be sent to team addresses until outgoing mail (SMTP) is configured.",
    weak_password: "Choose a stronger password.",
    same_password: "The new password must differ from the current one.",
    over_email_send_rate_limit: "Too many emails sent. Wait a minute and try again.",
    over_request_rate_limit: "Too many attempts. Wait a minute and try again.",
    otp_expired: "This link has expired. Request a new one.",
    signup_disabled: "Sign-ups are disabled.",
    session_not_found: "Your session has expired. Sign in again.",
};

/** Maps a Supabase Auth error (by `code`) to a user-facing message. */
export function authErrorMessage(error: { code?: string; message?: string } | null | undefined): string {
    if (!error) return "Something went wrong. Try again.";
    if (error.code && AUTH_MESSAGES[error.code]) return AUTH_MESSAGES[error.code];
    return error.message || "Something went wrong. Try again.";
}

/**
 * App functions raise `P0001` with messages shaped `code: human text` (e.g. `slug_taken: this URL is already in use`).
 * Returns the code and the text after the colon; other errors become a generic message.
 */
export function dbError(error: { code?: string; message?: string } | null | undefined): { code: string; message: string } {
    const message = error?.message ?? "";
    const match = /^([a-z_]+):\s*(.+)$/.exec(message);
    if (error?.code === "P0001" && match) return { code: match[1], message: match[2] };
    if (error?.code === "42501") return { code: "permission_denied", message: "You do not have permission to do this." };
    if (error?.code === "23505") return { code: "duplicate", message: "A record with this name already exists." };
    if (error?.code === "23503") return { code: "linked", message: "Cannot delete or change this because other records are linked to it." };
    return { code: "unknown", message: "Something went wrong. Try again." };
}
