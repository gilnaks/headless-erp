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

/** Roles or a profile; `app.create_invitation` repeats every check (roles_required, already_member, invite_pending). */
export const createInvitationSchema = z
    .object({
        orgSlug: z.string().min(1),
        email: z.string().trim().toLowerCase().pipe(z.email("Enter a valid email address")),
        roleProfile: z
            .string()
            .trim()
            .nullable()
            .transform((v) => v || null),
        roles: z.array(z.string().trim().min(1)).transform((roles) => [...new Set(roles)]),
    })
    .refine((v) => v.roleProfile !== null || v.roles.length > 0, {
        message: "Choose at least one role or a role profile",
        path: ["roles"],
    });

export const invitationRefSchema = z.object({ orgSlug: z.string().min(1), id: z.guid("Unknown invitation") });

export type CreateInvitationInput = z.input<typeof createInvitationSchema>;
export type InvitationRefInput = z.input<typeof invitationRefSchema>;
export type UpdateMemberRolesInput = z.input<typeof updateMemberRolesSchema>;
export type SetMemberStatusInput = z.input<typeof setMemberStatusSchema>;
export type RemoveMemberInput = z.input<typeof removeMemberSchema>;
