import type { FieldValues, TreeOptions } from "./define";

export type TreeNode = { id: string; title: string; isGroup: boolean; row: FieldValues; children: TreeNode[] };

/** Active Tree view filters: Link field -> id ("" = any). */
export type TreeFilterValues = Record<string, string>;

const str = (value: unknown) => (typeof value === "string" ? value : "");

/**
 * Rows shown by the Tree view: those matching every filter (and enabled, unless `includeDisabled`), plus their
 * ancestors so each match stays reachable from a root (ERPNext keeps "All Departments" above a company's departments).
 */
export function visibleRows(rows: FieldValues[], tree: TreeOptions, filters: TreeFilterValues, includeDisabled: boolean): FieldValues[] {
    const byId = new Map(rows.map((r) => [str(r.id), r]));
    const keep = new Set<string>();
    for (const row of rows) {
        if (!includeDisabled && tree.disabledField && row[tree.disabledField]) continue;
        if (!Object.entries(filters).every(([field, value]) => !value || row[field] === value)) continue;
        let current: FieldValues | undefined = row;
        while (current && !keep.has(str(current.id))) {
            keep.add(str(current.id));
            current = byId.get(str(current[tree.parentField]));
        }
    }
    return rows.filter((r) => keep.has(str(r.id)));
}

/** Nests rows under their parent; rows whose parent is absent become roots. Siblings sort by title. */
export function buildTree(rows: FieldValues[], tree: TreeOptions, titleField: string): TreeNode[] {
    const nodes = new Map<string, TreeNode>(
        rows.map((row) => [
            str(row.id),
            { id: str(row.id), title: str(row[titleField]) || str(row.id), isGroup: Boolean(row[tree.groupField]), row, children: [] },
        ]),
    );
    const roots: TreeNode[] = [];
    for (const node of nodes.values()) {
        const parent = nodes.get(str(node.row[tree.parentField]));
        if (parent && parent !== node) parent.children.push(node);
        else roots.push(node);
    }
    const sort = (list: TreeNode[]) => {
        list.sort((a, b) => a.title.localeCompare(b.title));
        for (const n of list) sort(n.children);
    };
    sort(roots);
    return roots;
}

/** Ids of every group node, for expanding the whole tree. */
export function groupIds(nodes: TreeNode[]): string[] {
    return nodes.flatMap((n) => (n.isGroup ? [n.id, ...groupIds(n.children)] : groupIds(n.children)));
}

/**
 * Query for "Add child" (`new?<parentField>=<id>&...`): filter fields come from the parent node, else from the active
 * filter (the root has no company; ERPNext `add_node` takes the company from the tree filter).
 */
export function childQuery(node: TreeNode, tree: TreeOptions, filters: TreeFilterValues): string {
    const params = new URLSearchParams({ [tree.parentField]: node.id });
    for (const field of tree.filters ?? []) {
        const value = str(node.row[field]) || filters[field] || "";
        if (value) params.set(field, value);
    }
    return params.toString();
}
