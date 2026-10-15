import { z } from "zod";
import { requireUser } from "@/lib/auth/claims";
import { dispatchEmail } from "@/lib/email/dispatch";
import { type ActionResult, dbError, fail } from "@/lib/errors";
import { getOrgBySlug } from "@/lib/queries/doc";
import { createClient } from "@/lib/supabase/client";

const testEmailSchema = z.object({ orgSlug: z.string().min(1), id: z.uuid() });

/** "Send test email" on an Email Account: sends a short message through that account to the signed-in user. */
export async function sendTestEmail(input: z.input<typeof testEmailSchema>): Promise<ActionResult<{ to: string }>> {
    const parsed = testEmailSchema.safeParse(input);
    if (!parsed.success) return fail("Save the Email Account first.");
    const { orgSlug, id } = parsed.data;
    const claims = await requireUser(`/${orgSlug}/setup/email-account/${id}`);
    if (!claims.email) return fail("Your account has no email address.");
    const org = await getOrgBySlug(orgSlug);
    if (!org) return fail("Organization not found.");

    // RLS: only users who can read Email Accounts get past this.
    const supabase = await createClient();
    const { data: account, error } = await supabase
        .from("email_account")
        .select("id, email_account_name")
        .eq("org_id", org.id)
        .eq("id", id)
        .maybeSingle();
    if (error) return fail(dbError(error).message);
    if (!account) return fail("Email Account not found.");

    const result = await dispatchEmail({
        kind: "account",
        orgId: org.id,
        accountId: account.id,
        userEmail: claims.email,
        to: [claims.email],
        subject: `Test email from ${account.email_account_name}`,
        html: `<p>This is a test email sent through the <b>${account.email_account_name.replace(/[<>&"]/g, "")}</b> email account.</p>`,
        reference: { doctype: "Email Account", id: account.id },
        sentBy: claims.userId,
    });
    if (!result.ok) return fail(`The test email was not sent: ${result.error}`);
    return { ok: true, data: { to: claims.email } };
}
