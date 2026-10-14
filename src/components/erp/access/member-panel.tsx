"use client";

import { ChevronLeft, Trash01 } from "@untitledui/icons";
import Link from "next/link";
import { useState, useTransition } from "react";
import { Heading as AriaHeading } from "react-aria-components";
import { Dialog, Modal, ModalOverlay } from "@/components/application/modals/modal";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import { Toggle } from "@/components/base/toggle/toggle";
import { FormAlert } from "@/components/erp/form-alert";
import { removeMember, setMemberStatus, updateMemberRoles } from "@/lib/actions/setup/users";
import type { Member, RoleProfileOption } from "@/lib/queries/users";
import { formatDateTime, MemberStatusBadge } from "./member-badges";
import { type RoleOption, RolePicker, useRoleAssignment } from "./role-picker";

type MemberPanelProps = {
    orgSlug: string;
    member: Member;
    roleOptions: RoleOption[];
    profiles: RoleProfileOption[];
    canEdit: boolean;
};

const sameRoles = (a: string[], b: string[]) => {
    const sorted = [...b].sort();
    return a.length === b.length && [...a].sort().every((r, i) => r === sorted[i]);
};

/** Frappe User form, reduced to what an organization controls: roles (or a role profile), status and membership. */
export function MemberPanel({ orgSlug, member, roleOptions, profiles, canEdit }: MemberPanelProps) {
    const assignment = useRoleAssignment({ profile: member.roleProfile, roles: member.roles }, profiles);
    const { profile, roles } = assignment;
    const [error, setError] = useState<string | null>(null);
    const [rolesError, setRolesError] = useState<string | null>(null);
    const [saving, startSaving] = useTransition();
    const [statusPending, startStatus] = useTransition();

    const dirty = profile !== member.roleProfile || (!profile && !sameRoles(roles, member.roles));

    const save = () =>
        startSaving(async () => {
            setError(null);
            setRolesError(null);
            const result = await updateMemberRoles({ orgSlug, userId: member.userId, roleProfile: profile, roles });
            if (!result.ok) {
                setError(result.error);
                setRolesError(result.fieldErrors?.roles ?? null);
            }
        });

    const toggleStatus = (active: boolean) =>
        startStatus(async () => {
            setError(null);
            const result = await setMemberStatus({ orgSlug, userId: member.userId, status: active ? "active" : "disabled" });
            if (!result.ok) setError(result.error);
        });

    const title = member.fullName ?? member.email;

    return (
        <div className="flex flex-col">
            <header className="sticky -top-5 z-10 -mx-4 -mt-5 flex flex-wrap items-center gap-3 border-b border-secondary bg-primary px-4 py-3 lg:-top-6 lg:-mx-8 lg:-mt-6 lg:px-8">
                <div className="flex min-w-0 flex-1 flex-col">
                    <Link
                        href={`/${orgSlug}/setup/users`}
                        className="flex w-max items-center gap-1 text-xs font-medium text-tertiary hover:text-secondary"
                    >
                        <ChevronLeft aria-hidden="true" className="size-3.5" />
                        Users
                    </Link>
                    <div className="flex min-w-0 items-center gap-2">
                        <h1 className="truncate text-lg font-semibold text-primary">{title}</h1>
                        {member.isOwner && (
                            <Badge size="sm" color="brand">
                                Owner
                            </Badge>
                        )}
                        <MemberStatusBadge status={member.status} />
                        {dirty && (
                            <Badge size="sm" color="warning">
                                Not Saved
                            </Badge>
                        )}
                    </div>
                </div>
                {canEdit && (
                    <Button size="sm" onPress={save} isLoading={saving} isDisabled={!dirty} showTextWhileLoading>
                        Save
                    </Button>
                )}
            </header>

            <div className="flex flex-col gap-3 pt-4">
                {error && <FormAlert>{error}</FormAlert>}
                {!canEdit && <FormAlert tone="info">You can view this user but not change it.</FormAlert>}
            </div>

            <section className="flex flex-col gap-3 border-b border-secondary py-5">
                <h2 className="text-sm font-semibold text-primary">Account</h2>
                <dl className="grid gap-x-8 gap-y-3 text-sm sm:grid-cols-2">
                    <div>
                        <dt className="text-tertiary">Email</dt>
                        <dd className="text-primary">{member.email}</dd>
                    </div>
                    <div>
                        <dt className="text-tertiary">Member since</dt>
                        <dd className="text-primary tabular-nums" suppressHydrationWarning>
                            {formatDateTime(member.createdAt)}
                        </dd>
                    </div>
                    {member.lastSignInAt && (
                        <div>
                            <dt className="text-tertiary">Last sign-in</dt>
                            <dd className="text-primary tabular-nums" suppressHydrationWarning>
                                {formatDateTime(member.lastSignInAt)}
                            </dd>
                        </div>
                    )}
                </dl>
            </section>

            <section className="flex flex-col gap-3 border-b border-secondary py-5">
                <h2 className="text-sm font-semibold text-primary">Roles</h2>
                <RolePicker
                    assignment={assignment}
                    profiles={profiles}
                    roleOptions={roleOptions}
                    isDisabled={!canEdit}
                    rolesError={rolesError}
                    rolesHint={member.isOwner ? "The owner always keeps System Manager." : undefined}
                    className="lg:grid-cols-2"
                />
            </section>

            <section className="flex flex-col gap-3 border-b border-secondary py-5">
                <h2 className="text-sm font-semibold text-primary">Access</h2>
                <Toggle
                    label="Active"
                    hint={
                        member.isOwner
                            ? "The organization owner cannot be disabled."
                            : "Disabled users keep their roles but cannot open this organization."
                    }
                    isSelected={member.status === "active"}
                    isDisabled={!canEdit || member.isOwner || statusPending}
                    onChange={toggleStatus}
                />
            </section>

            {canEdit && !member.isOwner && <RemoveMember orgSlug={orgSlug} member={member} title={title} />}
        </div>
    );
}

function RemoveMember({ orgSlug, member, title }: { orgSlug: string; member: Member; title: string }) {
    const [open, setOpen] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();

    const confirm = () =>
        startTransition(async () => {
            setError(null);
            const result = await removeMember({ orgSlug, userId: member.userId });
            if (result && !result.ok) setError(result.error);
        });

    return (
        <section className="flex flex-col items-start gap-3 py-5">
            <h2 className="text-sm font-semibold text-primary">Remove from organization</h2>
            <p className="text-sm text-tertiary">The account stays, but loses access to this organization and its user permissions here.</p>
            <Button size="sm" color="secondary-destructive" iconLeading={Trash01} onPress={() => setOpen(true)}>
                Remove user
            </Button>
            <ModalOverlay isOpen={open} onOpenChange={setOpen} isDismissable={!pending}>
                <Modal className="max-w-md">
                    <Dialog aria-label="Remove user">
                        <div className="flex flex-col gap-4 p-6">
                            <AriaHeading slot="title" className="text-lg font-semibold text-primary">
                                Remove {title}?
                            </AriaHeading>
                            <p className="text-sm text-tertiary">
                                <span className="font-medium text-secondary">{member.email}</span> will lose access to this organization.
                                You can invite them again later.
                            </p>
                            {error && <FormAlert>{error}</FormAlert>}
                            <div className="flex justify-end gap-2">
                                <Button size="sm" color="secondary" onPress={() => setOpen(false)} isDisabled={pending}>
                                    Cancel
                                </Button>
                                <Button size="sm" color="primary-destructive" onPress={confirm} isLoading={pending} showTextWhileLoading>
                                    Remove
                                </Button>
                            </div>
                        </div>
                    </Dialog>
                </Modal>
            </ModalOverlay>
        </section>
    );
}
