import { describe, expect, it } from "vitest";
import type { FieldValues, TreeOptions } from "./define";
import { buildTree, childQuery, groupIds, visibleRows } from "./tree";

const tree: TreeOptions = { parentField: "parent_id", groupField: "is_group", filters: ["company_id"], disabledField: "disabled" };

const rows = [
    { id: "root", name: "All Departments", parent_id: null, company_id: null, is_group: true, disabled: false },
    { id: "eng", name: "Engineering - A", parent_id: "root", company_id: "A", is_group: true, disabled: false },
    { id: "web", name: "Web - A", parent_id: "eng", company_id: "A", is_group: false, disabled: false },
    { id: "api", name: "API - A", parent_id: "eng", company_id: "A", is_group: false, disabled: true },
    { id: "ops", name: "Operations - B", parent_id: "root", company_id: "B", is_group: false, disabled: false },
];

const ids = (rs: FieldValues[]) => rs.map((r) => r.id);

describe("visibleRows", () => {
    it("hides disabled nodes unless asked", () => {
        expect(ids(visibleRows(rows, tree, {}, false))).toEqual(["root", "eng", "web", "ops"]);
        expect(ids(visibleRows(rows, tree, {}, true))).toHaveLength(5);
    });

    it("keeps the ancestors of filtered nodes", () => {
        expect(ids(visibleRows(rows, tree, { company_id: "B" }, false))).toEqual(["root", "ops"]);
        expect(ids(visibleRows(rows, tree, { company_id: "A" }, true))).toEqual(["root", "eng", "web", "api"]);
    });

    it("ignores empty filters", () => {
        expect(ids(visibleRows(rows, tree, { company_id: "" }, true))).toHaveLength(5);
    });
});

describe("buildTree", () => {
    it("nests children under parents and sorts siblings by title", () => {
        const [root, ...others] = buildTree(rows, tree, "name");
        expect(others).toEqual([]);
        expect(root.title).toBe("All Departments");
        expect(root.children.map((c) => c.id)).toEqual(["eng", "ops"]);
        expect(root.children[0].children.map((c) => c.title)).toEqual(["API - A", "Web - A"]);
    });

    it("promotes nodes whose parent is missing to roots", () => {
        const roots = buildTree(rows.slice(1), tree, "name");
        expect(roots.map((r) => r.id)).toEqual(["eng", "ops"]);
    });

    it("lists group ids for expansion", () => {
        expect(groupIds(buildTree(rows, tree, "name"))).toEqual(["root", "eng"]);
    });
});

describe("childQuery", () => {
    const [root] = buildTree(rows, tree, "name");

    it("copies the parent's filter fields", () => {
        expect(childQuery(root.children[0], tree, { company_id: "B" })).toBe("parent_id=eng&company_id=A");
    });

    it("falls back to the active filter for nodes without one", () => {
        expect(childQuery(root, tree, { company_id: "B" })).toBe("parent_id=root&company_id=B");
        expect(childQuery(root, tree, {})).toBe("parent_id=root");
    });
});
