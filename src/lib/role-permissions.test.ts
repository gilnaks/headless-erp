import { describe, expect, it } from "vitest";
import { PERM_FIELDS, type PermFlags, permToggle } from "./role-permissions";

const none = Object.fromEntries(PERM_FIELDS.map((f) => [f, false])) as PermFlags;

describe("permToggle", () => {
    it("sets a plain flag on its own", () => {
        expect(permToggle(none, "can_read", true)).toEqual({ can_read: true });
    });

    it("amend pulls in cancel, submit and write", () => {
        expect(permToggle({ ...none, can_read: true }, "can_amend", true)).toEqual({
            can_amend: true,
            can_cancel: true,
            can_submit: true,
            can_write: true,
        });
    });

    it("only adds dependencies that are missing", () => {
        expect(permToggle({ ...none, can_write: true, can_submit: true }, "can_cancel", true)).toEqual({ can_cancel: true });
    });

    it("clearing write clears submit, cancel and amend", () => {
        const all = { ...none, can_write: true, can_submit: true, can_cancel: true, can_amend: true };
        expect(permToggle(all, "can_write", false)).toEqual({ can_write: false, can_submit: false, can_cancel: false, can_amend: false });
    });

    it("clearing submit leaves write alone", () => {
        const all = { ...none, can_write: true, can_submit: true, can_cancel: true };
        expect(permToggle(all, "can_submit", false)).toEqual({ can_submit: false, can_cancel: false });
    });
});
