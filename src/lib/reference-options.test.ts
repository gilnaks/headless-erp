import { describe, expect, it } from "vitest";
import { defineChildDoctype } from "@/doctypes/define";
import { company } from "@/doctypes/setup/company";
import { roleProfile } from "@/doctypes/setup/role-profile";
import { countryItems, currencyItems, optionSourcesOf } from "./reference-options";

describe("reference option items", () => {
    it("keys currencies by ISO code and carries the name for search", () => {
        expect(currencyItems([{ code: "USD", currency_name: "US Dollar" }])).toEqual([
            { id: "USD", label: "USD", supportingText: "US Dollar" },
        ]);
    });

    it("keys countries by their Frappe name", () => {
        expect(countryItems([{ country_name: "United States" }])).toEqual([{ id: "United States", label: "United States" }]);
    });
});

describe("optionSourcesOf", () => {
    it("lists each reference source a doctype uses once", () => {
        expect(optionSourcesOf(company).sort()).toEqual(["Country", "Currency"]);
    });

    it("includes MultiSelect sources", () => {
        expect(optionSourcesOf(roleProfile)).toEqual(["Role"]);
    });

    it("includes child table fields and ignores fixed option lists", () => {
        const child = defineChildDoctype({
            doctype: "Fixture Row",
            table: "companies",
            fields: { default_currency: { type: "Select", label: "Currency", options: "Currency" } },
            columns: ["default_currency"],
        });
        const d = { fields: { domain: { type: "Select" as const, label: "Domain", options: ["A", "B"] } }, children: { rows: child } };
        expect(optionSourcesOf(d)).toEqual(["Currency"]);
    });
});
