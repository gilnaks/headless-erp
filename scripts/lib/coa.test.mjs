import { describe, expect, it } from "vitest";
import { minifyJson, pythonChartToJson, treeText } from "./coa.mjs";

describe("pythonChartToJson", () => {
    it("converts the ERPNext chart literal, keeping key order", () => {
        const source = `from frappe import _

def get():
\treturn {
\t\t_("Assets"): {
\t\t\t_("Bank Accounts"): {"account_type": "Bank", "is_group": 1,},  # a group
\t\t\t"2": {"tax_rate": 1.5, "x": None, "y": True, "z": False},
\t\t\t"1": {},
\t\t},
\t\t_("It's \\"quoted\\""): {"root_type": "Equity"},
\t}
`;
        const json = pythonChartToJson(source);
        expect(json).toBe(
            '{"Assets":{"Bank Accounts":{"account_type":"Bank","is_group":1},"2":{"tax_rate":1.5,"x":null,"y":true,"z":false},"1":{}},"It\'s \\"quoted\\"":{"root_type":"Equity"}}',
        );
    });

    it("rejects code it does not understand", () => {
        expect(() => pythonChartToJson("def get():\n\treturn {_('a'): foo}")).toThrow(/unexpected identifier foo/);
    });
});

describe("minifyJson / treeText", () => {
    it("strips whitespace outside strings and extracts the tree in source order", () => {
        const doc = '{\n  "name": "X Chart",\n  "tree": {\n    "2 B": {"root_type": "Asset"},\n    "1 A": {}\n  },\n  "disabled": "No"\n}';
        const min = minifyJson(doc);
        expect(min).toBe('{"name":"X Chart","tree":{"2 B":{"root_type":"Asset"},"1 A":{}},"disabled":"No"}');
        expect(treeText(min)).toBe('{"2 B":{"root_type":"Asset"},"1 A":{}}');
    });
});
