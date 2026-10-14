import { fiscalYearEnd, fiscalYearName, isAutoYearName } from "@/lib/fiscal-year";
import { defineChildDoctype, defineDoctype, type FieldValues } from "../define";

/** ERPNext Fiscal Year Company (erpnext/accounts/doctype/fiscal_year_company): limits a year to companies. */
export const fiscalYearCompany = defineChildDoctype({
    doctype: "Fiscal Year Company",
    table: "fiscal_year_company",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
    },
    columns: ["company_id"],
});

/** Re-derives a generated year name ("2026", "2026-2027") from the dates; a typed name is kept. */
const renameYear = (values: FieldValues, end: string | null): FieldValues => {
    const name = fiscalYearName(String(values.year_start_date ?? ""), end ?? "");
    return name && isAutoYearName(values.year) ? { year: name } : {};
};

/**
 * ERPNext Fiscal Year (erpnext/accounts/doctype/fiscal_year). Date rules and the overlap check run in the database
 * (`app.fiscal_year_validate`, `app.fiscal_year_check_overlap`, 0114); an empty Year is named from the dates.
 */
export const fiscalYear = defineDoctype<"fiscal_year", "companies">({
    doctype: "Fiscal Year",
    table: "fiscal_year",
    module: "accounts",
    slug: "fiscal-year",
    titleField: "year",
    fields: {
        year: {
            type: "Data",
            label: "Year Name",
            description: "For e.g. 2026, 2026-2027. Left empty, it is named from the dates.",
        },
        disabled: { type: "Check", label: "Disabled" },
        is_short_year: {
            type: "Check",
            label: "Is Short/Long Year",
            description: "Less than 12 months.",
        },
        year_start_date: { type: "Date", label: "Year Start Date", required: true },
        year_end_date: { type: "Date", label: "Year End Date", required: true },
        auto_created: { type: "Check", label: "Auto Created", readOnly: true, dependsOn: (v) => Boolean(v.auto_created) },
        companies: {
            type: "Table",
            label: "Companies",
            target: "Fiscal Year Company",
            description: "Leave empty to apply the year to every company.",
        },
    },
    children: { companies: fiscalYearCompany },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["year", "disabled", "is_short_year", "auto_created"],
                        ["year_start_date", "year_end_date"],
                    ],
                },
                { label: "Companies", columns: [["companies"]] },
            ],
        },
    ],
    listView: {
        columns: ["year", "year_start_date", "year_end_date", "disabled"],
        searchFields: ["year"],
        defaultSort: { field: "year_start_date", desc: true },
    },
    triggers: {
        year_start_date: (values) => {
            const end = values.is_short_year ? String(values.year_end_date ?? "") : fiscalYearEnd(String(values.year_start_date ?? ""));
            return { ...(end && !values.is_short_year ? { year_end_date: end } : {}), ...renameYear(values, end) };
        },
        year_end_date: (values) => renameYear(values, String(values.year_end_date ?? "")),
    },
    errorFields: {
        duplicate: "year",
        fiscal_year_dates: "year_end_date",
        fiscal_year_overlap: "year_start_date",
    },
});
