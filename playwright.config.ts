import { defineConfig, devices } from "@playwright/test";

/**
 * Smoke tests against the built app (`npm run build` first) and a local Supabase stack. Needs the same env as the
 * app plus SUPABASE_SERVICE_ROLE_KEY (CI exports them from `supabase status -o env`).
 */
const baseURL = process.env.APP_URL ?? "http://localhost:3000";

export default defineConfig({
    testDir: "e2e",
    globalSetup: "./e2e/global-setup.ts",
    fullyParallel: false,
    forbidOnly: Boolean(process.env.CI),
    retries: process.env.CI ? 1 : 0,
    workers: 1,
    reporter: process.env.CI ? [["github"], ["html", { open: "never" }]] : "list",
    use: {
        baseURL,
        trace: "retain-on-failure",
        screenshot: "only-on-failure",
    },
    projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
    webServer: {
        command: "npm run start",
        url: `${baseURL}/health`,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
    },
});
