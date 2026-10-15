import { createClient } from "npm:@supabase/supabase-js@2";

type Job = {
    kind: "account" | "platform";
    orgId: string;
    companyId?: string | null;
    accountId?: string | null;
    userName?: string | null;
    userEmail?: string | null;
    to: string[];
    cc?: string[];
    subject: string;
    html: string;
    reference?: { doctype: string; id: string };
    sentBy: string;
};

type Account = {
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

const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) => Response.json(body, { status, headers: cors });

function formatAddress(name: string | null | undefined, email: string): string {
    const display = name?.replace(/["\\<>\r\n]/g, "").trim();
    return display ? `"${display}" <${email}>` : email;
}

function platformSender(): { accountId: null; apiKey: string; from: string; replyTo?: string; signature: null; footer: null } | null {
    const dry = Deno.env.get("EMAIL_DRY_RUN") === "1";
    const apiKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("EMAIL_FROM");
    if (apiKey && from) return { accountId: null, apiKey, from, signature: null, footer: null };
    if (dry) return { accountId: null, apiKey: "dry-run", from: from || "no-reply@example.invalid", signature: null, footer: null };
    return null;
}

function accountSender(account: Account, user: { name?: string | null; email?: string | null }) {
    const name = account.always_use_account_name_as_sender_name ? account.email_account_name : (user.name ?? account.email_account_name);
    const replyTo =
        !account.always_use_account_email_id_as_sender && user.email && user.email.toLowerCase() !== account.email_id ? user.email : undefined;
    return {
        accountId: account.email_account_id,
        apiKey: account.api_key,
        from: formatAddress(name, account.email_id),
        ...(replyTo ? { replyTo } : {}),
        signature: account.add_signature ? account.signature : null,
        footer: account.footer,
    };
}

async function sendViaResend(apiKey: string, message: { from: string; to: string[]; cc?: string[]; subject: string; html: string; replyTo?: string }) {
    if (Deno.env.get("EMAIL_DRY_RUN") === "1") return { ok: true as const, id: `dry-run-${crypto.randomUUID()}` };
    const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
            from: message.from,
            to: message.to,
            ...(message.cc?.length ? { cc: message.cc } : {}),
            subject: message.subject,
            html: message.html,
            ...(message.replyTo ? { reply_to: message.replyTo } : {}),
        }),
        signal: AbortSignal.timeout(15_000),
    });
    const body = (await response.json().catch(() => null)) as { id?: string; message?: string } | null;
    if (!response.ok || !body?.id) return { ok: false as const, error: body?.message ?? `The email provider answered ${response.status}.` };
    return { ok: true as const, id: body.id };
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const auth = req.headers.get("Authorization");
    if (!url || !anon || !serviceKey || !auth) return json({ ok: false, error: "Email is not configured." }, 500);

    const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
    const { data: userData } = await userClient.auth.getUser();
    const user = userData.user;
    if (!user) return json({ ok: false, error: "Not signed in." }, 401);

    const job = (await req.json()) as Job;
    if (!job?.orgId || !job.to?.length || !job.subject || !job.html || job.sentBy !== user.id) {
        return json({ ok: false, error: "The email could not be sent." });
    }

    const { data: member } = await userClient.from("org_members").select("user_id").eq("org_id", job.orgId).eq("user_id", user.id).maybeSingle();
    if (!member) return json({ ok: false, error: "Not a member of this organization." }, 403);

    const { data: cleanHtml, error: cleanError } = await userClient.rpc("sanitize_html", { p_html: job.html });
    if (cleanError || cleanHtml == null) return json({ ok: false, error: "The message could not be prepared." });

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
    let sender: ReturnType<typeof platformSender> | ReturnType<typeof accountSender> = null;
    if (job.kind === "account") {
        const { data, error } = await admin.rpc("email_sender", {
            p_org: job.orgId,
            ...(job.companyId ? { p_company: job.companyId } : {}),
            ...(job.accountId ? { p_account: job.accountId } : {}),
        });
        if (error) return json({ ok: false, error: `Could not load the email account: ${error.message}` });
        const account = (data as Account[] | null)?.[0];
        if (account) sender = accountSender(account, { name: job.userName, email: job.userEmail });
        else if (job.accountId) return json({ ok: false, error: "Save an API key first, and keep the account enabled with outgoing email on." });
    }
    sender ??= platformSender();
    if (!sender) {
        const error =
            job.kind === "platform"
                ? "Email is not set up for this site."
                : "Email is not set up. Add an Email Account with an API key in Setup → Email Account.";
        return json({ ok: false, error });
    }

    const html = [cleanHtml, sender.signature && `<div class="signature">${sender.signature}</div>`, sender.footer].filter(Boolean).join("\n");
    let result: { ok: true; id: string } | { ok: false; error: string };
    try {
        result = await sendViaResend(sender.apiKey, { from: sender.from, to: job.to, cc: job.cc, subject: job.subject, html, replyTo: sender.replyTo });
    } catch (e) {
        result = { ok: false, error: `Could not reach the email provider: ${e instanceof Error ? e.message : String(e)}` };
    }

    const { error: logError } = await admin.from("email_log").insert({
        org_id: job.orgId,
        email_account_id: sender.accountId,
        sender: sender.from,
        reference_doctype: job.reference?.doctype ?? null,
        reference_id: job.reference?.id ?? null,
        recipients: job.to,
        cc: job.cc ?? [],
        subject: job.subject,
        status: result.ok ? "Sent" : "Error",
        provider_message_id: result.ok ? result.id : null,
        error: result.ok ? null : result.error,
        sent_by: job.sentBy,
    });
    if (logError) console.error("email_log insert failed", logError.message);

    return result.ok
        ? json({ ok: true, id: result.id, from: sender.from, dryRun: Deno.env.get("EMAIL_DRY_RUN") === "1" })
        : json({ ok: false, error: result.error });
});
