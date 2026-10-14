import type { Metadata } from "next";
import { Suspense } from "react";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { getAuthClaims } from "@/lib/auth/claims";
import type { InvitationStatus } from "@/lib/invitations";
import { createClient } from "@/lib/supabase/server";
import { AcceptInvitation } from "./accept-invitation";

export const metadata: Metadata = { title: "Invitation" };

type InvitationPreview = { org_name: string; email: string; state: InvitationStatus };

const CLOSED: Record<Exclude<InvitationStatus, "pending">, string> = {
    accepted: "This invitation has already been accepted.",
    expired: "This invitation has expired. Ask the person who invited you to resend it.",
    revoked: "This invitation has been revoked.",
};

async function InviteBody({ params }: { params: Promise<{ token: string }> }) {
    const { token } = await params;
    const claims = await getAuthClaims();
    const next = `/invite/${encodeURIComponent(token)}`;

    if (!claims) {
        return (
            <>
                <p className="text-sm text-tertiary">Sign in or create an account with the email address the invitation was sent to.</p>
                <div className="flex flex-col gap-3">
                    <Button href={`/login?next=${encodeURIComponent(next)}`} size="md">
                        Sign in to accept
                    </Button>
                    <Button href={`/signup?next=${encodeURIComponent(next)}`} size="md" color="secondary">
                        Create an account
                    </Button>
                </div>
            </>
        );
    }

    const supabase = await createClient();
    const { data } = await supabase.rpc("invitation_preview", { p_token: token });
    const preview = data as InvitationPreview | null;

    if (!preview) return <FormAlert>This invitation link is not valid. Ask for a new one.</FormAlert>;
    if (preview.state !== "pending") return <FormAlert>{CLOSED[preview.state]}</FormAlert>;

    const signedInAs = <span className="font-semibold text-secondary">{claims.email}</span>;
    if (claims.email?.toLowerCase() !== preview.email) {
        return (
            <>
                <FormAlert>
                    This invitation to <span className="font-semibold">{preview.org_name}</span> was sent to{" "}
                    <span className="font-semibold">{preview.email}</span>, but you are signed in as {signedInAs}.
                </FormAlert>
                <form action="/auth/signout" method="post">
                    <Button type="submit" size="md" color="secondary" className="w-full">
                        Sign out and switch account
                    </Button>
                </form>
            </>
        );
    }

    return (
        <>
            <p className="text-sm text-tertiary">
                You are signed in as {signedInAs}. Accept to join <span className="font-semibold text-secondary">{preview.org_name}</span>.
            </p>
            <AcceptInvitation token={token} />
        </>
    );
}

export default function InvitePage({ params }: { params: Promise<{ token: string }> }) {
    return (
        <main className="flex min-h-dvh flex-col items-center bg-secondary px-4 py-12 sm:justify-center">
            <div className="flex w-full max-w-sm flex-col gap-4 rounded-xl bg-primary p-6 shadow-sm ring-1 ring-secondary sm:p-8">
                <h1 className="text-display-xs font-semibold text-primary">You have been invited</h1>
                <Suspense>
                    <InviteBody params={params} />
                </Suspense>
            </div>
        </main>
    );
}
