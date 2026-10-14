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

// Biome keeps an object expanded when the input breaks right after `{`, so those breaks are removed first. The CLI's
// built-in generator (local) is newer than the hosted one (dev project): it adds `ComputedFields`, spells empty args
// `Record<PropertyKey, never>` and types generated columns as `never` in Insert/Update. Those spellings are unified.
const normalise = (text) =>
    format(
        text
            .split(/\r?\n/)
            .filter((line) => !line.trim().startsWith("//"))
            .join("\n")
            .replace(/__InternalSupabase: \{[^}]*\};?/, "")
            .replace(/Omit<\s*(Database\[[^<>]*?\]\[["']Row["']\]),\s*Database\[[^<>]*?\]\[["']ComputedFields["']\],?\s*>/g, "$1")
            .replace(/ComputedFields: never;?/g, "")
            .replace(/Record<PropertyKey, never>/g, "never")
            .replace(/([{[])\s+/g, "$1 ")
            .replace(/\s+([}\]])/g, " $1")
            .replace(/([^,{;\s])\s*\n\s*("?\w+"?\??:)/g, "$1; $2"),
    )
        .split("\n")
        .filter((line) => line.trim() !== "");

/** Generated columns: `name?: never` in Insert/Update on one side; dropped from both sides. */
const dropGeneratedColumns = (a, b) => {
    const names = new Set([...a, ...b].map((line) => line.match(/^\s*(\w+)\?: never;$/)?.[1]).filter(Boolean));
    const keep = (line) => !names.has(line.match(/^\s*(\w+)\?: /)?.[1]);
    return [a.filter(keep), b.filter(keep)];
};

const raw = execFileSync("npx", ["supabase", "gen", "types", "typescript", source, "--schema", "public,app"], {
    encoding: "utf8",
    shell,
    maxBuffer: 64 * 1024 * 1024,
});
const [generated, committed] = dropGeneratedColumns(normalise(raw), normalise(readFileSync("src/types/database.ts", "utf8")));

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
