"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { safeNext } from "@/lib/auth/redirect";
import { type ActionResult, authErrorMessage, fail, zodFieldErrors } from "@/lib/errors";
import {
    type ForgotPasswordInput,
    forgotPasswordSchema,
    type MagicLinkInput,
    magicLinkSchema,
    type PasswordLoginInput,
    passwordLoginSchema,
    type SignupInput,
    signupSchema,
    type UpdatePasswordInput,
    updatePasswordSchema,
} from "@/lib/schemas/auth";
import { createClient } from "@/lib/supabase/server";

const RATE_LIMIT_CODES = new Set(["over_email_send_rate_limit", "over_request_rate_limit"]);

/** Base URL for email links; must be covered by the Auth redirect allow-list (`/auth/callback**`). */
async function appUrl(): Promise<string> {
    const origin = (await headers()).get("origin");
    return origin ?? process.env.APP_URL ?? "http://localhost:3000";
}

async function callbackUrl(next: string): Promise<string> {
    return `${await appUrl()}/auth/callback?next=${encodeURIComponent(safeNext(next))}`;
}

export async function signInWithPassword(input: PasswordLoginInput): Promise<ActionResult> {
    const parsed = passwordLoginSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const supabase = await createClient();
    const { error } = await supabase.auth.signInWithPassword({ email: parsed.data.email, password: parsed.data.password });
    if (error) return fail(authErrorMessage(error));

    redirect(safeNext(parsed.data.next));
}

export async function sendMagicLink(input: MagicLinkInput): Promise<ActionResult> {
    const parsed = magicLinkSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const supabase = await createClient();
    const { error } = await supabase.auth.signInWithOtp({
        email: parsed.data.email,
        options: { shouldCreateUser: false, emailRedirectTo: await callbackUrl(parsed.data.next ?? "/") },
    });
    // Unknown addresses also error here; report success anyway so the form does not reveal which emails have accounts.
    if (error && RATE_LIMIT_CODES.has(error.code ?? "")) return fail(authErrorMessage(error));
    return { ok: true };
}

export async function signUp(input: SignupInput): Promise<ActionResult<{ confirmEmail: boolean }>> {
    const parsed = signupSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const { email, password, first_name, last_name, next } = parsed.data;
    const supabase = await createClient();
    const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { first_name, last_name }, emailRedirectTo: await callbackUrl(next ?? "/") },
    });
    if (error) return fail(authErrorMessage(error));

    if (data.session) redirect(safeNext(next));
    return { ok: true, data: { confirmEmail: true } };
}

export async function sendPasswordReset(input: ForgotPasswordInput): Promise<ActionResult> {
    const parsed = forgotPasswordSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const supabase = await createClient();
    const { error } = await supabase.auth.resetPasswordForEmail(parsed.data.email, {
        redirectTo: await callbackUrl("/update-password"),
    });
    if (error && RATE_LIMIT_CODES.has(error.code ?? "")) return fail(authErrorMessage(error));
    return { ok: true };
}

export async function updatePassword(input: UpdatePasswordInput): Promise<ActionResult> {
    const parsed = updatePasswordSchema.safeParse(input);
    if (!parsed.success) return fail("Check the highlighted fields.", zodFieldErrors(parsed.error));

    const supabase = await createClient();
    const { error } = await supabase.auth.updateUser({ password: parsed.data.password });
    if (error) return fail(authErrorMessage(error));

    redirect("/");
}
