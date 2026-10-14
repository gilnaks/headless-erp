import type { SelectItemType } from "@/components/base/select/select";
import type { Doctype, FieldDef, OptionSource } from "@/doctypes/define";

/** Option lists for `Select` fields backed by a global reference table, keyed by source. */
export type ReferenceOptions = Partial<Record<OptionSource, SelectItemType[]>>;

/** Value = ISO code; the name rides in `supportingText`, which the ComboBox also searches. */
export function currencyItems(rows: { code: string; currency_name: string }[]): SelectItemType[] {
    return rows.map((r) => ({ id: r.code, label: r.code, supportingText: r.currency_name }));
}

/** Value = Frappe country name (the `country` column stores the name, as ERPNext does). */
export function countryItems(rows: { country_name: string }[]): SelectItemType[] {
    return rows.map((r) => ({ id: r.country_name, label: r.country_name }));
}

function sourceOf(f: FieldDef): OptionSource | null {
    return f.type === "Select" && typeof f.options === "string" ? (f.options as OptionSource) : null;
}

/** Reference sources a doctype's fields (header and child tables) need. */
export function optionSourcesOf(d: Pick<Doctype, "fields" | "children">): OptionSource[] {
    const fields = [...Object.values(d.fields), ...Object.values(d.children).flatMap((c) => Object.values(c.fields))];
    return [...new Set(fields.map(sourceOf).filter((s): s is OptionSource => s !== null))];
}
