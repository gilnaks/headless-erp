import { createClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database";
import { supabaseUrl } from "./env";

/** Service-role client. Provisioning, cron and tests only — never reachable from Client Components. */
export function createAdminClient() {
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) throw new Error("SUPABASE_SERVICE_ROLE_KEY is not set");
    return createClient<Database>(supabaseUrl(), key, {
        auth: { persistSession: false, autoRefreshToken: false },
    });
}
