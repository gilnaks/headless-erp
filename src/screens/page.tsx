import { getAuthClaims } from "@/lib/auth/claims";
import { redirect } from "@/lib/navigate";
import { createClient } from "@/lib/supabase/client";

async function RootRedirect(): Promise<null> {
    const claims = await getAuthClaims();
    if (!claims) redirect("/login");

    const supabase = await createClient();
    const { data } = await supabase.from("organizations").select("slug").order("name").limit(1).maybeSingle();
    redirect(data ? `/${data.slug}` : "/setup");
}

export default function Home() {
    return RootRedirect();
}
