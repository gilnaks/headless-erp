// Fails when src/types/database.ts is stale against the local database (after `supabase db reset`).
// Local generation emits unformatted TypeScript without the `__InternalSupabase` block, while the committed file comes
// from the dev project, so both sides are formatted with Biome and stripped of that block and of comments before
// comparing. Pass `--linked` to compare against the dev project instead. On failure the generated file is written to
// test-results/ (uploaded by CI).
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

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
        .replace(/^\s*__InternalSupabase: \{[^}]*\};\n/m, "")
        .split("\n")
        .filter((line) => line.trim() !== "" && !line.trim().startsWith("//"));

const raw = execFileSync("npx", ["supabase", "gen", "types", "typescript", source, "--schema", "public,app"], {
    encoding: "utf8",
    shell,
    maxBuffer: 64 * 1024 * 1024,
});
const generated = normalise(raw);
const committed = normalise(readFileSync("src/types/database.ts", "utf8"));

const first = generated.findIndex((line, i) => line !== committed[i]);
const mismatch = first !== -1 || generated.length !== committed.length;

if (mismatch) {
    const at = first === -1 ? Math.min(generated.length, committed.length) : first;
    mkdirSync("test-results", { recursive: true });
    writeFileSync("test-results/database.generated.ts", raw);
    console.error(`src/types/database.ts is stale (first difference at normalised line ${at + 1}):\n`);
    for (let i = Math.max(0, at - 3); i < at + 8; i++) {
        const mark = generated[i] === committed[i] ? " " : "!";
        console.error(`${mark} committed: ${committed[i] ?? "<eof>"}\n${mark} generated: ${generated[i] ?? "<eof>"}`);
    }
    console.error("\nRegenerate with `npm run db:types:linked` (dev project) or `npm run db:types` (local) and commit.");
    process.exit(1);
}
console.log("src/types/database.ts is up to date");
