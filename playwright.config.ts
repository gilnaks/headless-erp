import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig, devices } from "@playwright/test";

/** CI exports these. Locally they come from `.env.local` for the hosted project. */
function loadEnvLocal() {
    try {
        const text = readFileSync(resolve(process.cwd(), ".env.local"), "utf8");
        for (const line of text.split(/\r?\n/)) {
            if (!line || line.startsWith("#") || !line.includes("=")) continue;
            const key = line.slice(0, line.indexOf("=")).trim();
            let value = line.slice(line.indexOf("=") + 1).trim();
            if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))
                value = value.slice(1, -1);
            if (!process.env[key]) process.env[key] = value;
        }
    } catch {
        // The file is absent in CI.
    }
}

loadEnvLocal();

/**
 * Smoke tests against the Vite preview (`npm run build` first) and the hosted project (or CI's local stack).
 * Needs the same env as the app plus SUPABASE_SERVICE_ROLE_KEY.
 */
const baseURL = process.env.APP_URL ?? "http://localhost:3000";

export default defineConfig({
    testDir: "e2e",
    globalSetup: "./e2e/global-setup.ts",
    timeout: 120_000,
    expect: { timeout: 15_000 },
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
        command: "npx vite preview --host 127.0.0.1 --port 3000 --strictPort",
        url: `${baseURL}/health`,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
    },
});
