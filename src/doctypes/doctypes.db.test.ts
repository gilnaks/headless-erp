import { createClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";
import type { Database } from "@/types/database";
import { type ChildDoctype, type Doctype, layoutFields } from "./define";
import { DOCTYPES } from "./registry";

/**
 * Descriptor <-> database consistency against a freshly reset local Supabase (`npm run test:db` in CI).
 * Needs NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY for the local stack.
 */
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) throw new Error("test:db needs NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (local Supabase)");

const db = createClient<Database>(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

async function metaOf(doctype: string) {
    const { data, error } = await db.from("doctype_meta").select("*").eq("doctype", doctype).maybeSingle();
    expect(error).toBeNull();
    return data;
}

/** PostgREST rejects unknown columns, so a zero-row select proves every name is a real column. */
async function expectColumns(table: string, columns: string[]) {
    const { error } = await db
        .from(table as Doctype["table"])
        .select([...new Set(columns)].join(","))
        .limit(0);
    expect(error?.message ?? null, `${table}: ${columns.join(", ")}`).toBeNull();
}

const columnFields = (d: Pick<Doctype, "fields">) =>
    Object.entries(d.fields)
        .filter(([, f]) => f.type !== "Table")
        .map(([name]) => name);

describe.each(DOCTYPES.map((d) => [d.doctype, d] as const))("%s", (_, d) => {
    it("matches its doctype_meta row", async () => {
        const meta = await metaOf(d.doctype);
        expect(meta).not.toBeNull();
        expect(meta).toMatchObject({
            table_name: d.table,
            module: d.module,
            is_submittable: d.submittable,
            is_child: false,
            is_single: d.single,
        });
        if (!d.single) expect(meta?.title_field).toBe(d.titleField);
    });

    it("uses only real columns for fields, list view and title", async () => {
        const tableFields = Object.keys(d.children);
        const layout = layoutFields(d).filter((f) => !tableFields.includes(f));
        await expectColumns(d.table, [
            "id",
            "org_id",
            d.titleField,
            ...columnFields(d),
            ...layout,
            ...d.listView.columns,
            ...d.listView.searchFields,
            d.listView.defaultSort.field,
        ]);
    });

    it.each(Object.entries(d.children) as [string, ChildDoctype][])(
        "child table %s is registered and uses real columns",
        async (field, child) => {
            const meta = await metaOf(child.doctype);
            expect(meta).toMatchObject({ table_name: child.table, is_child: true, parent_doctype: d.doctype, child_field: field });
            expect(d.fields[field]?.type).toBe("Table");
            await expectColumns(child.table, ["id", "org_id", ...columnFields(child), ...child.columns]);
        },
    );
});
