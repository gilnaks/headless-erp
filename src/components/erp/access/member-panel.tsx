"use client";

import { ChevronLeft, Trash01 } from "@untitledui/icons";
import Link from "next/link";
import { useMemo, useState, useTransition } from "react";
import { Heading as AriaHeading, type Key, type Selection } from "react-aria-components";
import { Dialog, Modal, ModalOverlay } from "@/components/application/modals/modal";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import { MultiSelect } from "@/components/base/select/multi-select";
import { Select } from "@/components/base/select/select";
import { Toggle } from "@/components/base/toggle/toggle";
import { FormAlert } from "@/components/erp/form-alert";
import { removeMember, setMemberStatus, updateMemberRoles } from "@/lib/actions/setup/users";
import type { Member, RoleProfileOption } from "@/lib/queries/users";
import { formatDateTime, MemberStatusBadge } from "./member-badges";

type MemberPanelProps = {
    orgSlug: string;
    member: Member;
    roleOptions: { id: string; label: string }[];
    profiles: RoleProfileOption[];
    canEdit: boolean;
};

const NONE = "__none__";
const sameRoles = (a: string[], b: string[]) => a.length === b.length && [...a].sort().every((r, i) => r === [...b].sort()[i]);

/** Frappe User form, reduced to what an organization controls: roles (or a role profile), status and membership. */
export function MemberPanel({ orgSlug, member, roleOptions, profiles, canEdit }: MemberPanelProps) {
    const [profile, setProfile] = useState<string | null>(member.roleProfile);
    const [roles, setRoles] = useState<string[]>(member.roles);
    const [error, setError] = useState<string | null>(null);
    const [rolesError, setRolesError] = useState<string | null>(null);
    const [saving, startSaving] = useTransition();
    const [statusPending, startStatus] = useTransition();

    const profileRoles = profile ? (profiles.find((p) => p.name === profile)?.roles ?? []) : null;
    const shownRoles = profileRoles ?? roles;
    const dirty = profile !== member.roleProfile || (!profile && !sameRoles(roles, member.roles));

    const roleItems = useMemo(() => {
        const missing = shownRoles.filter((r) => !roleOptions.some((o) => o.id === r)).map((r) => ({ id: r, label: r }));
        return [...roleOptions, ...missing];
    }, [roleOptions, shownRoles]);
    const profileItems = useMemo(() => [{ id: NONE, label: "None" }, ...profiles.map((p) => ({ id: p.name, label: p.name }))], [profiles]);

    const onProfileChange = (key: Key | null) => {
        const next = key == null || key === NONE ? null : String(key);
        // Clearing the profile keeps its roles as a starting point for hand-picked roles.
        if (!next && profileRoles) setRoles(profileRoles);
        setProfile(next);
    };

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
                <div className="grid gap-x-8 gap-y-4 lg:grid-cols-2">
                    <Select
                        label="Role Profile"
                        items={profileItems}
                        size="sm"
                        placeholder="None"
                        isDisabled={!canEdit}
                        hint="Assigns the profile's roles; edit the profile to change them for everyone holding it."
                        selectedKey={profile ?? NONE}
                        onSelectionChange={onProfileChange}
                    >
                        {(item) => <Select.Item id={item.id} label={item.label} />}
                    </Select>
                    <MultiSelect
                        label="Roles"
                        items={roleItems}
                        size="sm"
                        placeholder="Select"
                        isDisabled={!canEdit || Boolean(profile)}
                        isInvalid={Boolean(rolesError)}
                        hint={
                            rolesError ??
                            (profile ? "Set by the role profile." : member.isOwner ? "The owner always keeps System Manager." : undefined)
                        }
                        selectedKeys={new Set(shownRoles)}
                        onSelectionChange={(keys: Selection) =>
                            setRoles(keys === "all" ? roleItems.map((i) => i.id) : [...keys].map(String))
                        }
                        onReset={() => setRoles([])}
                        onSelectAll={() => setRoles(roleItems.map((i) => i.id))}
                        selectedCountFormatter={() => shownRoles.join(", ")}
                    >
                        {(item) => <MultiSelect.Item id={item.id} label={item.label} />}
                    </MultiSelect>
                </div>
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
