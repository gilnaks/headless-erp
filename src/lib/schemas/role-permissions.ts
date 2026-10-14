import { z } from "zod";
import { PERM_FIELDS } from "@/lib/role-permissions";

const rule = {
    orgSlug: z.string().min(1),
    role: z.string().trim().min(1, "Select a role"),
    doctype: z.string().trim().min(1, "Select a document type"),
};

export const setPermissionSchema = z.object({
    ...rule,
    patch: z.partialRecord(z.enum(PERM_FIELDS), z.boolean()).refine((p) => Object.keys(p).length > 0, "Nothing to change"),
});

export const ruleSchema = z.object(rule);

export const resetDoctypeSchema = z.object({ orgSlug: rule.orgSlug, doctype: rule.doctype });

export type SetPermissionInput = z.input<typeof setPermissionSchema>;
export type RuleInput = z.input<typeof ruleSchema>;
export type ResetDoctypeInput = z.input<typeof resetDoctypeSchema>;
