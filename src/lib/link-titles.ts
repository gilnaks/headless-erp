import type { FieldDef, FieldValues } from "@/doctypes/define";

export type LinkOption = { id: string; label: string };

/** Titles of linked records, keyed by `titleKey(doctype, id)`. */
export type LinkTitles = Record<string, string>;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function titleKey(doctype: string, id: string): string {
    return `${doctype}:${id}`;
}

/** Target doctype of a Link (fixed) or DynamicLink (read from the sibling field) in `row`. */
export function linkTarget(field: FieldDef | undefined, row: FieldValues): string | null {
    if (field?.type === "Link") return field.target ?? null;
    if (field?.type === "DynamicLink" && field.optionsField) {
        const target = row[field.optionsField];
        return typeof target === "string" && target ? target : null;
    }
    return null;
}

/** Record ids to resolve per target doctype for the given columns, so a list needs one query per doctype. */
export function linkRequests(fields: Record<string, FieldDef>, columns: string[], rows: FieldValues[]): Map<string, string[]> {
    const wanted = new Map<string, Set<string>>();
    for (const row of rows) {
        for (const column of columns) {
            const target = linkTarget(fields[column], row);
            const id = row[column];
            if (!target || typeof id !== "string" || !UUID.test(id)) continue;
            if (!wanted.has(target)) wanted.set(target, new Set());
            wanted.get(target)?.add(id);
        }
    }
    return new Map([...wanted].map(([doctype, ids]) => [doctype, [...ids]]));
}

/** Title for a Link / DynamicLink cell, or null when the field is not a link or the title is unknown. */
export function linkTitle(field: FieldDef | undefined, row: FieldValues, value: unknown, titles: LinkTitles): string | null {
    const target = linkTarget(field, row);
    if (!target || typeof value !== "string") return null;
    return titles[titleKey(target, value)] ?? null;
}
