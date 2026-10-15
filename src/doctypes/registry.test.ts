import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { DOCTYPES } from "./registry";

/** `(doctype, table_name)` pairs registered by `insert into public.doctype_meta` statements in the migrations. */
function registeredDoctypes(): Map<string, string> {
    const dir = join(process.cwd(), "supabase", "migrations");
    const registered = new Map<string, string>();
    for (const file of readdirSync(dir)
        .filter((f) => f.endsWith(".sql"))
        .sort()) {
        const sql = readFileSync(join(dir, file), "utf8");
        for (const insert of sql.matchAll(/insert into public\.doctype_meta\s*\([^)]*\)\s*values([\s\S]*?)(?:on conflict|;)/gi)) {
            for (const row of insert[1].matchAll(/\(\s*'([^']+)'\s*,\s*'([^']+)'/g)) registered.set(row[1], row[2]);
        }
    }
    return registered;
}

describe("registry vs migrations", () => {
    const registered = registeredDoctypes();

    it.each(DOCTYPES.map((d) => [d.doctype, d]))("%s is registered in doctype_meta with its table", (_name, d) => {
        expect(registered.get(d.doctype)).toBe(d.table);
        for (const child of Object.values(d.children)) expect(registered.get(child.doctype)).toBe(child.table);
    });
});
