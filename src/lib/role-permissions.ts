export const PERM_FIELDS = [
    "can_read",
    "can_write",
    "can_create",
    "can_delete",
    "can_submit",
    "can_cancel",
    "can_amend",
    "can_report",
    "can_export",
    "if_owner",
] as const;

export type PermField = (typeof PERM_FIELDS)[number];
export type PermFlags = Record<PermField, boolean>;
export type PermRule = PermFlags & { role: string; doctype: string };

export const PERM_LABELS: Record<PermField, string> = {
    can_read: "Read",
    can_write: "Write",
    can_create: "Create",
    can_delete: "Delete",
    can_submit: "Submit",
    can_cancel: "Cancel",
    can_amend: "Amend",
    can_report: "Report",
    can_export: "Export",
    if_owner: "Only If Creator",
};

export const SUBMIT_FIELDS: ReadonlySet<PermField> = new Set(["can_submit", "can_cancel", "can_amend"]);

/** What a checkbox implies (`app.role_permissions_validate`): Amend → Cancel → Submit → Write, and the reverse on clear. */
const REQUIRES: Partial<Record<PermField, PermField[]>> = {
    can_submit: ["can_write"],
    can_cancel: ["can_submit", "can_write"],
    can_amend: ["can_cancel", "can_submit", "can_write"],
};

/** The fields to write when `field` is set to `value`, including the dependencies it pulls in or clears. */
export function permToggle(rule: PermFlags, field: PermField, value: boolean): Partial<PermFlags> {
    const patch: Partial<PermFlags> = { [field]: value };
    if (value) {
        for (const dep of REQUIRES[field] ?? []) if (!rule[dep]) patch[dep] = true;
    } else {
        for (const [dependent, deps] of Object.entries(REQUIRES) as [PermField, PermField[]][]) {
            if (deps.includes(field) && rule[dependent]) patch[dependent] = false;
        }
    }
    return patch;
}
