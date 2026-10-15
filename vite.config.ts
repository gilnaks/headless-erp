import path from "node:path";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import type { Connect } from "vite";
import { defineConfig } from "vite";

const root = path.dirname(fileURLToPath(import.meta.url));

/** Playwright and uptime checks read `/health` before the SPA boots. */
function health(): import("vite").Plugin {
    const respond: Connect.NextHandleFunction = (req, res, next) => {
        const url = req.url?.split("?")[0];
        if (url !== "/health") {
            next();
            return;
        }
        res.setHeader("content-type", "application/json");
        res.end(JSON.stringify({ ok: true }));
    };
    return {
        name: "health",
        configureServer(server) {
            server.middlewares.use(respond);
        },
        configurePreviewServer(server) {
            server.middlewares.use(respond);
        },
    };
}

export default defineConfig({
    envPrefix: ["VITE_", "NEXT_PUBLIC_"],
    plugins: [react(), health()],
    resolve: { alias: { "@": path.resolve(root, "src") } },
    server: { port: 3000, strictPort: true },
    preview: { port: 3000, strictPort: true },
});
