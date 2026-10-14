import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";

/** One confirmed user per spec (env prefix → email local part and profile), so specs never share organizations. */
const USERS = [
    { env: "E2E", local: "smoke", first_name: "Smoke", last_name: "Test" },
    { env: "E2E_ACCESS", local: "access", first_name: "Access", last_name: "Admin" },
    { env: "E2E_USERS", local: "users", first_name: "Users", last_name: "Admin" },
    { env: "E2E_INVITER", local: "inviter", first_name: "Inviting", last_name: "Owner" },
    { env: "E2E_INVITEE", local: "invitee", first_name: "Invited", last_name: "Member" },
    { env: "E2E_PERMS", local: "perms", first_name: "Perms", last_name: "Admin" },
    { env: "E2E_RESTRICTOR", local: "restrictor", first_name: "Restricting", last_name: "Owner" },
    { env: "E2E_RESTRICTED", local: "restricted", first_name: "Restricted", last_name: "Member" },
    { env: "E2E_BRANCH", local: "branch", first_name: "Branch", last_name: "Admin" },
    { env: "E2E_DESIGNATION", local: "designation", first_name: "Designation", last_name: "Admin" },
    { env: "E2E_DEPARTMENT", local: "department", first_name: "Department", last_name: "Admin" },
    { env: "E2E_HOLIDAYS", local: "holidays", first_name: "Holidays", last_name: "Admin" },
    { env: "E2E_FISCAL", local: "fiscal", first_name: "Fiscal", last_name: "Admin" },
    { env: "E2E_ONBOARDING", local: "onboarding", first_name: "Onboarding", last_name: "Owner" },
] as const;

/**
 * Creates confirmed users for the run (sign-up requires email confirmation, which the tests cannot click).
 * Credentials reach the tests through env vars (`<env>_EMAIL`, `<env>_PASSWORD`), which Playwright passes on to workers.
 */
export default async function globalSetup() {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) throw new Error("e2e needs NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (local Supabase)");

    const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const stamp = Date.now();
    for (const user of USERS) {
        const email = `${user.local}-${stamp}@example.com`;
        const password = `Smoke-${randomUUID()}`;
        const { error } = await admin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: { first_name: user.first_name, last_name: user.last_name },
        });
        if (error) throw error;
        process.env[`${user.env}_EMAIL`] = email;
        process.env[`${user.env}_PASSWORD`] = password;
    }
}
