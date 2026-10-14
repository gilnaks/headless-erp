import { describe, expect, it } from "vitest";
import type { FieldDef } from "@/doctypes/define";
import { linkRequests, linkTarget, linkTitle, titleKey } from "./link-titles";

const A = "00000000-0000-0000-0000-00000000000a";
const B = "00000000-0000-0000-0000-00000000000b";
const U = "00000000-0000-0000-0000-0000000000aa";

const fields: Record<string, FieldDef> = {
    user_id: { type: "Link", label: "User", target: "User" },
    doctype: { type: "Select", label: "Allow" },
    record_id: { type: "DynamicLink", label: "For Value", optionsField: "doctype" },
    note: { type: "Data", label: "Note" },
};

describe("link titles", () => {
    it("reads the target of Link and DynamicLink fields", () => {
        expect(linkTarget(fields.user_id, {})).toBe("User");
        expect(linkTarget(fields.record_id, { doctype: "Company" })).toBe("Company");
        expect(linkTarget(fields.record_id, { doctype: "" })).toBeNull();
        expect(linkTarget(fields.note, {})).toBeNull();
    });

    it("batches the ids per target doctype and skips non-uuid values", () => {
        const rows = [
            { user_id: U, doctype: "Company", record_id: A, note: A },
            { user_id: U, doctype: "Company", record_id: B },
            { user_id: "nope", doctype: "Warehouse", record_id: A },
        ];
        const requests = linkRequests(fields, ["user_id", "record_id", "note"], rows);
        expect(Object.fromEntries(requests)).toEqual({ User: [U], Company: [A, B], Warehouse: [A] });
    });

    it("resolves a cell title by its row's target", () => {
        const titles = { [titleKey("Company", A)]: "Acme", [titleKey("Warehouse", A)]: "Stores" };
        expect(linkTitle(fields.record_id, { doctype: "Company" }, A, titles)).toBe("Acme");
        expect(linkTitle(fields.record_id, { doctype: "Warehouse" }, A, titles)).toBe("Stores");
        expect(linkTitle(fields.record_id, { doctype: "Company" }, B, titles)).toBeNull();
        expect(linkTitle(fields.note, {}, A, titles)).toBeNull();
    });
});
