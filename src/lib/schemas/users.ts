import { z } from "zod";

const memberRef = {
    orgSlug: z.string().min(1),
    userId: z.guid("Unknown user"),
};

/** A profile wins over hand-picked roles (frappe User.validate copies the profile's roles). */
export const updateMemberRolesSchema = z.object({
    ...memberRef,
    roleProfile: z
        .string()
        .trim()
        .nullable()
        .transform((v) => v || null),
    roles: z.array(z.string().trim().min(1)).transform((roles) => [...new Set(roles)]),
});

export const setMemberStatusSchema = z.object({ ...memberRef, status: z.enum(["active", "disabled"]) });

export const removeMemberSchema = z.object(memberRef);

export type UpdateMemberRolesInput = z.input<typeof updateMemberRolesSchema>;
export type SetMemberStatusInput = z.input<typeof setMemberStatusSchema>;
export type RemoveMemberInput = z.input<typeof removeMemberSchema>;
