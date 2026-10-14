// Fails when src/types/database.ts is stale against the local database (after `supabase db reset`).
// The committed file is generated from the dev project, which can report a different PostgREST
// version than local Supabase, so that line is ignored. Pass `--linked` to compare against the dev project.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const source = process.argv.includes("--linked") ? "--linked" : "--local";

const normalise = (text) =>
    text
        .replace(/\r\n/g, "\n")
        .replace(/PostgrestVersion: "[^"]*"/, 'PostgrestVersion: "*"')
        .trimEnd()
        .split("\n");

const generated = normalise(
    execFileSync("npx", ["supabase", "gen", "types", "typescript", source, "--schema", "public,app"], {
        encoding: "utf8",
        shell: process.platform === "win32",
        maxBuffer: 64 * 1024 * 1024,
    }),
);
const committed = normalise(readFileSync("src/types/database.ts", "utf8"));

const diffs = [];
for (let i = 0; i < Math.max(generated.length, committed.length); i++) {
    if (generated[i] !== committed[i])
        diffs.push(`line ${i + 1}\n  committed: ${committed[i] ?? "<eof>"}\n  generated: ${generated[i] ?? "<eof>"}`);
}

if (diffs.length) {
    console.error(`src/types/database.ts is stale (${diffs.length} differing lines). First differences:\n`);
    console.error(diffs.slice(0, 10).join("\n"));
    console.error("\nRegenerate with `npm run db:types:linked` (dev project) or `npm run db:types` (local) and commit.");
    process.exit(1);
}
console.log("src/types/database.ts is up to date");
