import { createClient } from "@/lib/supabase/client";

export type EmailJob = {
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

export type DispatchResult = { ok: true; id: string; from: string; dryRun: boolean } | { ok: false; error: string };

/** Asks the `send-email` Edge Function to send. The browser never sees the provider key. */
export async function dispatchEmail(job: EmailJob): Promise<DispatchResult> {
    const supabase = createClient();
    const { data, error } = await supabase.functions.invoke("send-email", { body: job });
    if (data && typeof data === "object" && "ok" in data) return data as DispatchResult;
    return { ok: false, error: error?.message || "The email was not sent." };
}
