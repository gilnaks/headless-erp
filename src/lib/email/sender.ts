import { createAdminClient } from "@/lib/supabase/admin";
import { isDryRun, sendViaResend } from "./transport";

/** A row of `public.email_sender` (the organization's Email Account with its decrypted key). */
export type SenderAccount = {
    email_account_id: string;
    email_account_name: string;
    email_id: string;
    api_key: string;
    always_use_account_email_id_as_sender: boolean;
    always_use_account_name_as_sender_name: boolean;
    add_signature: boolean;
    signature: string | null;
    footer: string | null;
};

export type Sender = {
    accountId: string | null;
    apiKey: string;
    from: string;
    replyTo?: string;
    signature: string | null;
    footer: string | null;
};

/** The person sending: their name and address are used unless the account says otherwise. */
export type SendingUser = { name?: string | null; email?: string | null };

const DRY_RUN_FROM = "no-reply@example.invalid";

export function formatAddress(name: string | null | undefined, email: string): string {
    const display = name?.replace(/["\\<>\r\n]/g, "").trim();
    return display ? `"${display}" <${email}>` : email;
}

/** The platform sender (`RESEND_API_KEY` + `EMAIL_FROM`), used when the organization has no outgoing account. */
export function platformSender(env: Record<string, string | undefined> = process.env): Sender | null {
    const apiKey = env.RESEND_API_KEY;
    const from = env.EMAIL_FROM;
    if (apiKey && from) return { accountId: null, apiKey, from, signature: null, footer: null };
    if (env.EMAIL_DRY_RUN === "1") return { accountId: null, apiKey: "dry-run", from: from || DRY_RUN_FROM, signature: null, footer: null };
    return null;
}

/**
 * Frappe Email Account sender options: the provider only accepts the account's (verified) address, so it is always
 * the From address; the user's address becomes Reply-To unless `always_use_account_email_id_as_sender`. The display
 * name is the account name when `always_use_account_name_as_sender_name`, else the user's name.
 */
export function accountSender(account: SenderAccount, user: SendingUser = {}): Sender {
    const name = account.always_use_account_name_as_sender_name ? account.email_account_name : (user.name ?? account.email_account_name);
    const replyTo =
        !account.always_use_account_email_id_as_sender && user.email && user.email.toLowerCase() !== account.email_id
            ? user.email
            : undefined;
    return {
        accountId: account.email_account_id,
        apiKey: account.api_key,
        from: formatAddress(name, account.email_id),
        ...(replyTo ? { replyTo } : {}),
        signature: account.add_signature ? account.signature : null,
        footer: account.footer,
    };
}

/**
 * Sending account for an organization (Frappe `get_outgoing_email_account`): the given account, else the company's
 * account, else the organization's default outgoing account, else the platform sender. Null = email is not set up.
 * Callers must have authorized the user for the organization: this reads credentials with the service role.
 */
export async function resolveSender(
    orgId: string,
    options: { companyId?: string | null; accountId?: string | null; user?: SendingUser } = {},
): Promise<Sender | null> {
    const admin = createAdminClient();
    const { data, error } = await admin.rpc("email_sender", {
        p_org: orgId,
        ...(options.companyId ? { p_company: options.companyId } : {}),
        ...(options.accountId ? { p_account: options.accountId } : {}),
    });
    if (error) throw new Error(`Could not load the email account: ${error.message}`);
    const account = (data as SenderAccount[] | null)?.[0];
    if (account) return accountSender(account, options.user);
    return options.accountId ? null : platformSender();
}

/** Appends the account's signature and footer (Frappe `get_formatted_html`). */
export function withSignature(html: string, sender: Pick<Sender, "signature" | "footer">): string {
    return [html, sender.signature && `<div class="signature">${sender.signature}</div>`, sender.footer].filter(Boolean).join("\n");
}

export type OutgoingEmail = {
    orgId: string;
    to: string[];
    cc?: string[];
    subject: string;
    html: string;
    reference?: { doctype: string; id: string };
    sentBy: string;
};

export type DeliveryResult = { ok: true; id: string; from: string; dryRun: boolean } | { ok: false; error: string };

/** Sends with `sender` and records the attempt in `email_log` (append-only, written with the service role). */
export async function deliver(sender: Sender, email: OutgoingEmail): Promise<DeliveryResult> {
    const html = withSignature(email.html, sender);
    const result = await sendViaResend(sender.apiKey, {
        from: sender.from,
        to: email.to,
        cc: email.cc,
        subject: email.subject,
        html,
        replyTo: sender.replyTo,
    });

    const admin = createAdminClient();
    const { error } = await admin.from("email_log").insert({
        org_id: email.orgId,
        email_account_id: sender.accountId,
        sender: sender.from,
        reference_doctype: email.reference?.doctype ?? null,
        reference_id: email.reference?.id ?? null,
        recipients: email.to,
        cc: email.cc ?? [],
        subject: email.subject,
        status: result.ok ? "Sent" : "Error",
        provider_message_id: result.ok ? result.id : null,
        error: result.ok ? null : result.error,
        sent_by: email.sentBy,
    });
    if (error) console.error("email_log insert failed", error.message);

    return result.ok ? { ok: true, id: result.id, from: sender.from, dryRun: isDryRun() } : result;
}
