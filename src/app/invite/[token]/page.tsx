import type { Metadata } from "next";
import { Suspense } from "react";
import { Button } from "@/components/base/buttons/button";
import { getAuthClaims } from "@/lib/auth/claims";
import { AcceptInvitation } from "./accept-invitation";

export const metadata: Metadata = { title: "Invitation" };

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

    return (
        <>
            <p className="text-sm text-tertiary">
                You are signed in as <span className="font-semibold text-secondary">{claims.email}</span>. Accept to join the organization.
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
