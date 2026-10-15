import { createClient as createSupabaseClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database";
import { supabasePublishableKey, supabaseUrl } from "./env";

let browser: SupabaseClient<Database> | undefined;

/** Browser Supabase client. Session lives in local storage and refreshes itself. */
export function createClient() {
    browser ??= createSupabaseClient<Database>(supabaseUrl(), supabasePublishableKey(), {
        auth: {
            persistSession: true,
            autoRefreshToken: true,
            detectSessionInUrl: false,
        },
    });
    return browser;
}
