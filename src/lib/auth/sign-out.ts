import { createClient } from "@/lib/supabase/client";

/** Ends the browser session and returns to the sign-in screen. */
export async function signOut(): Promise<void> {
    await createClient().auth.signOut({ scope: "local" });
    window.location.assign("/login");
}
