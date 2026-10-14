import { describe, expect, it } from "vitest";
import { defineChildDoctype } from "./define";
import { gridColumns, gridKeyTarget, moveTarget, removalOrder } from "./grid";
import { newChildRow } from "./schema";

// Any child-shaped table works; the grid only reads the descriptor.
const fixture = defineChildDoctype({
    doctype: "ZZ Grid Row",
    table: "companies",
    fields: {
        company_name: { type: "Data", label: "Item", required: true },
        credit_limit: { type: "Currency", label: "Amount", default: 0 },
        is_group: { type: "Check", label: "Flag" },
    },
    columns: ["company_name", "credit_limit", "is_group", "abbr"],
});

describe("gridColumns", () => {
    it("keeps column order, skips undeclared fields and flags numeric columns", () => {
        expect(gridColumns(fixture).map((c) => [c.name, c.numeric])).toEqual([
            ["company_name", false],
            ["credit_limit", true],
            ["is_group", false],
        ]);
    });
});

describe("newChildRow", () => {
    it("applies ERPNext defaults in input shape", () => {
        expect(newChildRow(fixture)).toEqual({ company_name: "", credit_limit: "0", is_group: false });
    });
});

describe("moveTarget", () => {
    it("moves within bounds and stops at the edges", () => {
        expect(moveTarget(1, "up", 3)).toBe(0);
        expect(moveTarget(1, "down", 3)).toBe(2);
        expect(moveTarget(0, "up", 3)).toBeNull();
        expect(moveTarget(2, "down", 3)).toBeNull();
    });
});

describe("gridKeyTarget", () => {
    it("navigates rows and appends past the last row", () => {
        expect(gridKeyTarget(1, "ArrowUp", 3)).toEqual({ row: 0 });
        expect(gridKeyTarget(0, "ArrowUp", 3)).toBeNull();
        expect(gridKeyTarget(0, "ArrowDown", 3)).toEqual({ row: 1 });
        expect(gridKeyTarget(2, "ArrowDown", 3)).toEqual({ add: true });
        expect(gridKeyTarget(2, "Enter", 3)).toEqual({ add: true });
        expect(gridKeyTarget(0, "Tab", 3)).toBeNull();
    });
});

describe("removalOrder", () => {
    it("dedupes, drops out-of-range indices and sorts descending", () => {
        expect(removalOrder([0, 2, 2, 5, -1], 3)).toEqual([2, 0]);
        expect(removalOrder(new Set<number>(), 3)).toEqual([]);
    });
});
