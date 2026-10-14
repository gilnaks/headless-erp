// Fails when src/types/database.ts is stale against the local database (after `supabase db reset`).
// Local generation emits unformatted TypeScript while the committed file comes from the dev project (formatted), so
// both sides go through Biome's formatter first; the PostgREST version line is ignored because it differs between
// local and hosted Supabase. Pass `--linked` to compare against the dev project instead.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const source = process.argv.includes("--linked") ? "--linked" : "--local";
const shell = process.platform === "win32";

const format = (text) =>
    execFileSync("npx", ["biome", "format", "--stdin-file-path=scripts/database-types-check.ts"], {
        input: text,
        encoding: "utf8",
        shell,
        maxBuffer: 64 * 1024 * 1024,
    });

const normalise = (text) =>
    format(text.replace(/\r\n/g, "\n"))
        .replace(/PostgrestVersion: "[^"]*"/, 'PostgrestVersion: "*"')
        .split("\n")
        .filter((line) => line.trim() !== "");

const generated = normalise(
    execFileSync("npx", ["supabase", "gen", "types", "typescript", source, "--schema", "public,app"], {
        encoding: "utf8",
        shell,
        maxBuffer: 64 * 1024 * 1024,
    }),
);
const committed = normalise(readFileSync("src/types/database.ts", "utf8"));

const diffs = [];
for (let i = 0; i < Math.max(generated.length, committed.length); i++) {
    if (generated[i] !== committed[i]) diffs.push(`line ${i + 1}\n  committed: ${committed[i] ?? "<eof>"}\n  generated: ${generated[i] ?? "<eof>"}`);
}

if (diffs.length) {
    console.error(`src/types/database.ts is stale (${diffs.length} differing lines after formatting). First differences:\n`);
    console.error(diffs.slice(0, 10).join("\n"));
    console.error("\nRegenerate with `npm run db:types:linked` (dev project) or `npm run db:types` (local) and commit.");
    process.exit(1);
}
console.log("src/types/database.ts is up to date");
