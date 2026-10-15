import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { findLink } from "@/config/navigation";
import { type ChildDoctype, type Doctype, defineDoctype, docPath, layoutFields } from "./define";
import { DOCTYPES, getDoctype, getDoctypeByName } from "./registry";
import { formToPayload, formValuesFor, newChildRow, prefillValues, schemaFor } from "./schema";
import { company } from "./setup/company";
import { roleProfile } from "./setup/role-profile";
import { userPermission } from "./setup/user-permission";

const migrations = readdirSync(join(process.cwd(), "supabase/migrations"))
    .filter((f) => f.endsWith(".sql"))
    .map((f) => readFileSync(join(process.cwd(), "supabase/migrations", f), "utf8"))
    .join("\n");

describe("registry", () => {
    it("has unique doctype names and module/slug pairs", () => {
        expect(new Set(DOCTYPES.map((d) => d.doctype)).size).toBe(DOCTYPES.length);
        expect(new Set(DOCTYPES.map(docPath)).size).toBe(DOCTYPES.length);
        // The print route addresses doctypes by slug alone (`/print/<slug>/<id>`).
        expect(new Set(DOCTYPES.map((d) => d.slug)).size).toBe(DOCTYPES.length);
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

describe("single doctypes", () => {
    const settings = defineDoctype({
        doctype: "Fixture Settings",
        table: "companies",
        module: "setup",
        slug: "fixture-settings",
        single: true,
        fields: { company_name: { type: "Data", label: "Name" } },
        tabs: [{ label: "Details", sections: [{ columns: [["company_name"]] }] }],
    });

    it("default to an id title, an empty list view and not submittable", () => {
        expect(settings.single).toBe(true);
        expect(settings.submittable).toBe(false);
        expect(settings.titleField).toBe("id");
        expect(settings.listView.columns).toEqual([]);
    });

    it("are regular documents by default", () => {
        expect(company.single).toBe(false);
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

describe("DynamicLink (User Permission)", () => {
    const schema = schemaFor(userPermission);
    const userId = "00000000-0000-0000-0000-0000000000a1";
    const companyId = "00000000-0000-0000-0000-0000000000c1";
    const valid = {
        user_id: userId,
        doctype: "Company",
        record_id: companyId,
        applicable_for: "",
        is_default: false,
        hide_descendants: false,
    };

    it("needs a record id for the selected doctype", () => {
        expect(schema.safeParse(valid).success).toBe(true);
        expect(schema.safeParse({ ...valid, record_id: "Acme" }).success).toBe(false);
        const missing = schema.safeParse({ ...valid, record_id: "" });
        expect(missing.error?.issues[0]?.path).toEqual(["record_id"]);
    });

    it("sends an empty Applicable For as null (all document types)", () => {
        expect(formToPayload(userPermission, valid, { isNew: true })).toEqual({ ...valid, applicable_for: null });
    });

    it("offers Hide Descendants for tree targets only", () => {
        const dependsOn = userPermission.fields.hide_descendants.dependsOn;
        expect(dependsOn?.({ doctype: "Company" })).toBe(true);
        expect(dependsOn?.({ doctype: "Role" })).toBe(false);
    });

    it("prefills a new document from the URL query", () => {
        expect(prefillValues(userPermission, { user_id: userId, is_default: "1", nope: "x" })).toEqual({
            user_id: userId,
            is_default: true,
        });
        expect(prefillValues(userPermission, {})).toBeNull();
        expect(formValuesFor(userPermission, prefillValues(userPermission, { user_id: userId }) ?? undefined).user_id).toBe(userId);
    });
});

describe("MultiSelect (Role Profile)", () => {
    const schema = schemaFor(roleProfile);

    it("loads text[] values as string arrays and starts empty", () => {
        expect(formValuesFor(roleProfile).roles).toEqual([]);
        expect(formValuesFor(roleProfile, { name: "Sales", roles: ["Sales User", "Stock User"] }).roles).toEqual([
            "Sales User",
            "Stock User",
        ]);
    });

    it("accepts arrays of strings and rejects other shapes", () => {
        expect(schema.safeParse({ name: "Sales", roles: ["Sales User"] }).success).toBe(true);
        expect(schema.safeParse({ name: "Sales", roles: "Sales User" }).success).toBe(false);
    });

    it("trims and de-duplicates values in the payload", () => {
        const payload = formToPayload(
            roleProfile,
            { name: " Sales ", roles: [" Sales User", "Sales User", "", "Stock User"] },
            { isNew: true },
        );
        expect(payload).toEqual({ name: "Sales", roles: ["Sales User", "Stock User"] });
    });

    it("validates fixed options and treats an empty array as missing", () => {
        const fixture = defineDoctype({
            doctype: "Fixture Profile",
            table: "role_profile",
            module: "setup",
            slug: "fixture-profile",
            titleField: "name",
            fields: { roles: { type: "MultiSelect", label: "Roles", options: ["A", "B"], required: true } },
            tabs: [{ label: "Details", sections: [{ columns: [["roles"]] }] }],
            listView: { columns: ["name"], searchFields: ["name"], defaultSort: { field: "name" } },
        });
        const s = schemaFor(fixture);
        expect(s.safeParse({ roles: ["A"] }).success).toBe(true);
        expect(s.safeParse({ roles: ["C"] }).error?.issues[0].path).toEqual(["roles"]);
        expect(s.safeParse({ roles: [] }).error?.issues[0].message).toBe("Roles is required");
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
