import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";

/**
 * Creates a confirmed user for the run (sign-up requires email confirmation, which the smoke test cannot click).
 * Credentials reach the tests through env vars, which Playwright passes on to workers.
 */
export default async function globalSetup() {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) throw new Error("e2e needs NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (local Supabase)");

    const email = `smoke-${Date.now()}@example.com`;
    const password = `Smoke-${randomUUID()}`;
    const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const { error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { first_name: "Smoke", last_name: "Test" },
    });
    if (error) throw error;

    process.env.E2E_EMAIL = email;
    process.env.E2E_PASSWORD = password;
}
