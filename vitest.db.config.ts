import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

/** Database-backed suites (`*.db.test.ts`); run after `supabase db reset` with local Supabase env set. */
export default defineConfig({
    resolve: {
        alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
    },
    test: {
        environment: "node",
        include: ["src/**/*.db.test.ts"],
    },
});
