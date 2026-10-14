import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { findLink } from "@/config/navigation";
import { type ChildDoctype, type Doctype, defineDoctype, docPath, layoutFields } from "./define";
import { DOCTYPES, getDoctype, getDoctypeByName } from "./registry";
import { formToPayload, formValuesFor, newChildRow, schemaFor } from "./schema";
import { company } from "./setup/company";

const migrations = readdirSync(join(process.cwd(), "supabase/migrations"))
    .filter((f) => f.endsWith(".sql"))
    .map((f) => readFileSync(join(process.cwd(), "supabase/migrations", f), "utf8"))
    .join("\n");

describe("registry", () => {
    it("has unique doctype names and module/slug pairs", () => {
        expect(new Set(DOCTYPES.map((d) => d.doctype)).size).toBe(DOCTYPES.length);
        expect(new Set(DOCTYPES.map(docPath)).size).toBe(DOCTYPES.length);
    });

    it("looks doctypes up by route and by name", () => {
        expect(getDoctype("setup", "company")).toBe(company);
        expect(getDoctypeByName("Company")).toBe(company);
        expect(getDoctype("setup", "nope")).toBeUndefined();
    });

    it.each(DOCTYPES.map((d) => [d.doctype, d] as const))("%s is registered in doctype_meta by a migration", (_, d) => {
        expect(migrations).toContain(`'${d.doctype}', '${d.table}'`);
    });

    it.each(DOCTYPES.map((d) => [d.doctype, d] as const))("%s has a doctype entry in the navigation", (_, d) => {
        const link = findLink(docPath(d));
        expect(link?.target).toEqual({ kind: "doctype", doctype: d.doctype });
    });

    it.each(DOCTYPES.map((d) => [d.doctype, d] as const))("%s places every field in the layout exactly once", (_, d) => {
        const placed = layoutFields(d);
        expect(new Set(placed).size).toBe(placed.length);
        expect([...placed].sort()).toEqual(Object.keys(d.fields).sort());
    });

    it.each(DOCTYPES.map((d) => [d.doctype, d] as const))("%s maps only real error codes onto declared fields", (_, d) => {
        const builtIn = ["duplicate", "linked", "permission_denied"];
        for (const [code, field] of Object.entries(d.errorFields)) {
            expect(d.fields[field], `${code} -> ${field}`).toBeDefined();
            if (!builtIn.includes(code)) expect(migrations, code).toMatch(new RegExp(`'${code}: `));
        }
    });
});

describe("schemaFor (Company)", () => {
    const schema = schemaFor(company);
    const valid = formValuesFor(company, { company_name: "Acme", abbr: "AC", default_currency: "USD", country: "Netherlands" });

    it("starts new documents with ERPNext defaults", () => {
        const blank = formValuesFor(company);
        expect(blank.create_chart_of_accounts_based_on).toBe("Standard Template");
        expect(blank.chart_of_accounts).toBe("Standard");
        expect(blank.enable_perpetual_inventory).toBe(true);
        expect(blank.is_group).toBe(false);
        expect(blank.credit_limit).toBe("0");
        expect(blank.tax_id).toBe("");
    });

    it("accepts a valid document", () => {
        expect(schema.safeParse(valid).success).toBe(true);
    });

    it("reports required fields by label", () => {
        const result = schema.safeParse({ ...valid, company_name: "", abbr: "" });
        expect(result.success).toBe(false);
        const issues = result.error?.issues.map((i) => [i.path[0], i.message]);
        expect(issues).toEqual(
            expect.arrayContaining([
                ["company_name", "Company is required"],
                ["abbr", "Abbr is required"],
            ]),
        );
    });

    it("validates select options, numbers, dates and links", () => {
        const result = schema.safeParse({
            ...valid,
            valuation_method: "LIFO-ish",
            credit_limit: "12abc",
            date_of_establishment: "15/03/2026",
            parent_id: "not-a-uuid",
        });
        const paths = result.error?.issues.map((i) => i.path[0]);
        expect(paths).toEqual(expect.arrayContaining(["valuation_method", "credit_limit", "date_of_establishment", "parent_id"]));
    });
});

describe("formToPayload (Company)", () => {
    const values = formValuesFor(company, {
        company_name: "  Acme  ",
        abbr: "AC",
        default_currency: "USD",
        country: "Netherlands",
        credit_limit: "1500.50",
        reporting_currency: "USD",
    });

    it("converts empty strings to null, parses numbers, trims text and drops read-only fields", () => {
        const payload = formToPayload(company, values, { isNew: true });
        expect(payload.company_name).toBe("Acme");
        expect(payload.tax_id).toBeNull();
        expect(payload.credit_limit).toBe(1500.5);
        expect(payload.is_group).toBe(false);
        expect(payload).not.toHaveProperty("reporting_currency");
        expect(payload.create_chart_of_accounts_based_on).toBe("Standard Template");
    });

    it("drops set-only-once fields when editing", () => {
        const payload = formToPayload(company, values, { isNew: false });
        expect(payload).not.toHaveProperty("create_chart_of_accounts_based_on");
        expect(payload).not.toHaveProperty("chart_of_accounts");
        expect(payload.company_name).toBe("Acme");
    });
});

describe("child tables and dependsOn (fixture doctype)", () => {
    const item: ChildDoctype = {
        doctype: "Fixture Item",
        table: "companies",
        fields: {
            item: { type: "Data", label: "Item", required: true },
            qty: { type: "Float", label: "Qty", default: 1 },
        },
        columns: ["item", "qty"],
    };
    const fixture: Doctype = defineDoctype<"companies", "items">({
        doctype: "Fixture",
        table: "companies",
        module: "setup",
        slug: "fixture",
        titleField: "company_name",
        fields: {
            company_name: { type: "Data", label: "Title", required: true },
            is_group: { type: "Check", label: "Has Reason" },
            tax_id: { type: "Data", label: "Reason", required: true, dependsOn: (v) => v.is_group === true },
            items: { type: "Table", label: "Items", target: "Fixture Item", required: true },
        },
        children: { items: item },
        tabs: [{ label: "Details", sections: [{ columns: [["company_name", "is_group", "tax_id"], ["items"]] }] }],
        listView: { columns: ["company_name"], searchFields: ["company_name"], defaultSort: { field: "company_name" } },
    });
    const schema = schemaFor(fixture);

    it("skips mandatory checks for fields hidden by dependsOn (frappe: hidden fields are not mandatory)", () => {
        const base = { company_name: "T", is_group: false, tax_id: "", items: [newChildRow(item)] };
        base.items[0].item = "Widget";
        expect(schema.safeParse(base).success).toBe(true);
        const shown = schema.safeParse({ ...base, is_group: true });
        expect(shown.error?.issues.map((i) => i.path[0])).toEqual(["tax_id"]);
    });

    it("requires rows in mandatory tables and validates each row", () => {
        const empty = schema.safeParse({ company_name: "T", is_group: false, tax_id: "", items: [] });
        expect(empty.error?.issues.map((i) => i.path[0])).toContain("items");
        const badRow = schema.safeParse({ company_name: "T", is_group: false, tax_id: "", items: [{ item: "", qty: "x" }] });
        expect(badRow.error?.issues.map((i) => i.path.join("."))).toEqual(expect.arrayContaining(["items.0.item", "items.0.qty"]));
    });

    it("keeps child ids, drops invalid ones and converts row values", () => {
        const id = "3f0c2a52-8a43-4b8e-9d55-0d3f0b6a1e11";
        const payload = formToPayload(
            fixture,
            {
                company_name: "T",
                is_group: false,
                tax_id: "",
                items: [
                    { id, item: "A", qty: "2.5" },
                    { id: "tmp-1", item: "B", qty: "" },
                ],
            },
            { isNew: false },
        );
        expect(payload.items).toEqual([
            { id, item: "A", qty: 2.5 },
            { item: "B", qty: null },
        ]);
    });

    it("loads stored child rows into form values", () => {
        const values = formValuesFor(fixture, { company_name: "T", items: [{ id: "x", item: "A", qty: 3 }] });
        expect(values.items).toEqual([{ id: "x", item: "A", qty: "3" }]);
        expect(newChildRow(item)).toEqual({ item: "", qty: "1" });
    });
});
