import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "@/types/database";
import { supabasePublishableKey, supabaseUrl } from "./env";

export async function createClient() {
    const cookieStore = await cookies();

    return createServerClient<Database>(supabaseUrl(), supabasePublishableKey(), {
        cookies: {
            getAll() {
                return cookieStore.getAll();
            },
            setAll(cookiesToSet) {
                try {
                    for (const { name, value, options } of cookiesToSet) cookieStore.set(name, value, options);
                } catch {
                    // Server Components cannot set cookies; proxy.ts refreshes the session instead.
                }
            },
        },
    });
}
