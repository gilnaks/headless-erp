import type { SelectItemType } from "@/components/base/select/select";
import type { Doctype, FieldDef, OptionSource } from "@/doctypes/define";

/** A reference option; `tags` let a field narrow the list by other form values (`FieldDef.filterOptions`). */
export type ReferenceItem = SelectItemType & { tags?: string[] };

/** Option lists for `Select` / `MultiSelect` fields backed by a reference table, keyed by source. */
export type ReferenceOptions = Partial<Record<OptionSource, ReferenceItem[]>>;

/** Value = ISO code; the name rides in `supportingText`, which the ComboBox also searches. */
export function currencyItems(rows: { code: string; currency_name: string }[]): SelectItemType[] {
    return rows.map((r) => ({ id: r.code, label: r.code, supportingText: r.currency_name }));
}

/** Value = Frappe country name (the `country` column stores the name, as ERPNext does). */
export function countryItems(rows: { country_name: string }[]): SelectItemType[] {
    return rows.map((r) => ({ id: r.country_name, label: r.country_name }));
}

/** Value = template name; tagged with the countries whose charts it is (the standard charts have no tags). */
export function chartOfAccountsItems(
    templates: { name: string }[],
    countries: { template: string | null; country_name: string | null }[],
): ReferenceItem[] {
    return templates.map((t) => {
        const tags = countries.filter((c) => c.template === t.name && c.country_name).map((c) => c.country_name as string);
        return tags.length ? { id: t.name, label: t.name, tags } : { id: t.name, label: t.name };
    });
}

function sourceOf(f: FieldDef): OptionSource | null {
    return (f.type === "Select" || f.type === "MultiSelect") && typeof f.options === "string" ? (f.options as OptionSource) : null;
}

/** Reference sources a doctype's fields (header and child tables) need. */
export function optionSourcesOf(d: Pick<Doctype, "fields" | "children">): OptionSource[] {
    const fields = [...Object.values(d.fields), ...Object.values(d.children).flatMap((c) => Object.values(c.fields))];
    return [...new Set(fields.map(sourceOf).filter((s): s is OptionSource => s !== null))];
}
