import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { connection } from "next/server";
import type { Database } from "@/types/database";
import { supabasePublishableKey, supabaseUrl } from "./env";

export async function createClient() {
    // supabase-js reads Date.now() (token expiry), which cacheComponents rejects during prerendering.
    await connection();
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
