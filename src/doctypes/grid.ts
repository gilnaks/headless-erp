import type { ChildDoctype, FieldDef } from "./define";

/** Pure ChildTable logic (frappe `GridRow`), kept out of the component so it can be tested without a DOM. */

export type GridColumn = { name: string; field: FieldDef; numeric: boolean };

const NUMERIC = new Set(["Int", "Float", "Currency", "Percent"]);

export function gridColumns(child: ChildDoctype): GridColumn[] {
    return child.columns.flatMap((name) => {
        const field = child.fields[name];
        return field ? [{ name, field, numeric: NUMERIC.has(field.type) }] : [];
    });
}

/** Target index for moving row `index` one step up or down, or null at the edge. */
export function moveTarget(index: number, direction: "up" | "down", count: number): number | null {
    const target = direction === "up" ? index - 1 : index + 1;
    return target < 0 || target >= count ? null : target;
}

/**
 * Keyboard navigation inside the grid: ArrowUp/ArrowDown move to the same column in the previous/next row.
 * `add` = the key should append a row (ArrowDown or Enter on the last row, like ERPNext).
 */
export function gridKeyTarget(index: number, key: string, count: number): { row: number } | { add: true } | null {
    if (key === "ArrowUp") return index > 0 ? { row: index - 1 } : null;
    if (key === "ArrowDown" || key === "Enter") return index < count - 1 ? { row: index + 1 } : { add: true };
    return null;
}

/** Indices to remove, highest first so `useFieldArray.remove` keeps the remaining indices stable. */
export function removalOrder(selected: Iterable<number>, count: number): number[] {
    return [...new Set(selected)].filter((i) => i >= 0 && i < count).sort((a, b) => b - a);
}

/** Form path of a sibling field in the same row: `links.0.link_id` + `link_doctype` -> `links.0.link_doctype`. */
export function siblingPath(name: string, sibling: string): string {
    const dot = name.lastIndexOf(".");
    return dot < 0 ? sibling : `${name.slice(0, dot + 1)}${sibling}`;
}
