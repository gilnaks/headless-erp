import { redirect } from "next/navigation";
import { Suspense } from "react";
import { LoadingIndicator } from "@/components/application/loading-indicator/loading-indicator";
import { getAuthClaims } from "@/lib/auth/claims";
import { createClient } from "@/lib/supabase/server";

async function RootRedirect(): Promise<null> {
    const claims = await getAuthClaims();
    if (!claims) redirect("/login");

    const supabase = await createClient();
    const { data } = await supabase.from("organizations").select("slug").order("name").limit(1).maybeSingle();
    redirect(data ? `/${data.slug}` : "/setup");
}

export default function Home() {
    return (
        <main className="flex min-h-dvh items-center justify-center">
            <Suspense fallback={<LoadingIndicator type="line-simple" size="md" />}>
                <RootRedirect />
            </Suspense>
        </main>
    );
}
