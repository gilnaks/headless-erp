export type EmailMessage = {
    /** `Name <address>` or a bare address. */
    from: string;
    to: string[];
    cc?: string[];
    subject: string;
    html: string;
    text?: string;
    replyTo?: string;
};

export type SendResult = { ok: true; id: string } | { ok: false; error: string };

const RESEND_URL = "https://api.resend.com/emails";

/** `EMAIL_DRY_RUN=1` (CI, e2e): nothing leaves the server; sends succeed with a fake provider id. */
export function isDryRun(): boolean {
    return process.env.EMAIL_DRY_RUN === "1";
}

/** Sends one message through the Resend HTTP API (https://resend.com/docs/api-reference/emails/send-email). */
export async function sendViaResend(apiKey: string, message: EmailMessage, fetchImpl: typeof fetch = fetch): Promise<SendResult> {
    if (isDryRun()) return { ok: true, id: `dry-run-${crypto.randomUUID()}` };

    let response: Response;
    try {
        response = await fetchImpl(RESEND_URL, {
            method: "POST",
            headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({
                from: message.from,
                to: message.to,
                ...(message.cc?.length ? { cc: message.cc } : {}),
                subject: message.subject,
                html: message.html,
                ...(message.text ? { text: message.text } : {}),
                ...(message.replyTo ? { reply_to: message.replyTo } : {}),
            }),
            signal: AbortSignal.timeout(15_000),
        });
    } catch (e) {
        return { ok: false, error: `Could not reach the email provider: ${e instanceof Error ? e.message : String(e)}` };
    }

    const body = (await response.json().catch(() => null)) as { id?: string; message?: string } | null;
    if (!response.ok || !body?.id) {
        return { ok: false, error: body?.message ?? `The email provider answered ${response.status}.` };
    }
    return { ok: true, id: body.id };
}
