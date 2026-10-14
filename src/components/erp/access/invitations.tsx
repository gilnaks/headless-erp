"use client";

import { Copy01, RefreshCw01, UserPlus01, XClose } from "@untitledui/icons";
import { useEffect, useState, useTransition } from "react";
import { Heading as AriaHeading } from "react-aria-components";
import { SlideoutMenu } from "@/components/application/slideout-menus/slideout-menu";
import { Table } from "@/components/application/table/table";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import { ButtonUtility } from "@/components/base/buttons/button-utility";
import { Input } from "@/components/base/input/input";
import { FormAlert } from "@/components/erp/form-alert";
import { createInvitation, resendInvitation, revokeInvitation } from "@/lib/actions/setup/invitations";
import { type InvitationRow, type InvitationStatus, invitationStatus, inviteLink } from "@/lib/invitations";
import type { RoleProfileOption } from "@/lib/queries/users";
import { formatDateTime, RoleBadges } from "./member-badges";
import { type RoleOption, RolePicker, useRoleAssignment } from "./role-picker";

const STATUS: Record<InvitationStatus, { label: string; color: "warning" | "gray" | "error" | "success" }> = {
    pending: { label: "Pending", color: "warning" },
    expired: { label: "Expired", color: "gray" },
    revoked: { label: "Revoked", color: "error" },
    accepted: { label: "Accepted", color: "success" },
};

function useOrigin(): string {
    const [origin, setOrigin] = useState("");
    useEffect(() => setOrigin(window.location.origin), []);
    return origin;
}

function useCopy(): [string | null, (key: string, text: string) => void] {
    const [copied, setCopied] = useState<string | null>(null);
    const copy = (key: string, text: string) => {
        void navigator.clipboard?.writeText(text).then(() => {
            setCopied(key);
            setTimeout(() => setCopied((c) => (c === key ? null : c)), 2000);
        });
    };
    return [copied, copy];
}

type InviteProps = { orgSlug: string; roleOptions: RoleOption[]; profiles: RoleProfileOption[] };

/** "Invite user" slideout: email + roles or profile → a link to copy (no email is sent yet, 00-setup §3.4). */
export function InviteUser({ orgSlug, roleOptions, profiles }: InviteProps) {
    const [open, setOpen] = useState(false);
    const [formKey, setFormKey] = useState(0);
    const onOpenChange = (next: boolean) => {
        setOpen(next);
        if (!next) setFormKey((k) => k + 1);
    };
    return (
        <>
            <Button size="sm" iconLeading={UserPlus01} onPress={() => setOpen(true)}>
                Invite user
            </Button>
            <SlideoutMenu isOpen={open} onOpenChange={onOpenChange} isDismissable>
                {({ close }) => (
                    <InviteForm
                        key={formKey}
                        orgSlug={orgSlug}
                        roleOptions={roleOptions}
                        profiles={profiles}
                        onClose={close}
                        onReset={() => setFormKey((k) => k + 1)}
                    />
                )}
            </SlideoutMenu>
        </>
    );
}

function InviteForm({ orgSlug, roleOptions, profiles, onClose, onReset }: InviteProps & { onClose: () => void; onReset: () => void }) {
    const assignment = useRoleAssignment({ profile: null, roles: [] }, profiles);
    const [email, setEmail] = useState("");
    const [error, setError] = useState<string | null>(null);
    const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
    const [link, setLink] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();
    const [copied, copy] = useCopy();
    const origin = useOrigin();

    const submit = () =>
        startTransition(async () => {
            setError(null);
            setFieldErrors({});
            const result = await createInvitation({ orgSlug, email, roleProfile: assignment.profile, roles: assignment.roles });
            if (!result.ok) {
                setError(result.error);
                setFieldErrors(result.fieldErrors ?? {});
                return;
            }
            if (result.data) setLink(inviteLink(origin, result.data.token));
        });

    return (
        <>
            <SlideoutMenu.Header onClose={onClose}>
                <AriaHeading slot="title" className="text-lg font-semibold text-primary">
                    Invite user
                </AriaHeading>
                <p className="text-sm text-tertiary">Share the link with the person you invite. It works for 7 days.</p>
            </SlideoutMenu.Header>
            <SlideoutMenu.Content>
                {link ? (
                    <div className="flex flex-col gap-4">
                        <FormAlert tone="success">
                            Invitation created for <span className="font-semibold">{email.trim().toLowerCase()}</span>. Copy the link and
                            send it to them; no email is sent.
                        </FormAlert>
                        <Input label="Invitation link" size="sm" value={link} isReadOnly />
                        <Button size="sm" color="secondary" iconLeading={Copy01} onPress={() => copy("new", link)}>
                            {copied === "new" ? "Copied" : "Copy link"}
                        </Button>
                    </div>
                ) : (
                    <form
                        id="invite-form"
                        noValidate
                        className="flex flex-col gap-4"
                        onSubmit={(e) => {
                            e.preventDefault();
                            submit();
                        }}
                    >
                        {error && <FormAlert>{error}</FormAlert>}
                        <Input
                            label="Email"
                            type="email"
                            size="sm"
                            isRequired
                            autoFocus
                            value={email}
                            onChange={setEmail}
                            isInvalid={Boolean(fieldErrors.email)}
                            hint={fieldErrors.email}
                        />
                        <RolePicker assignment={assignment} profiles={profiles} roleOptions={roleOptions} rolesError={fieldErrors.roles} />
                    </form>
                )}
            </SlideoutMenu.Content>
            <SlideoutMenu.Footer className="flex justify-end gap-2">
                {link ? (
                    <>
                        <Button size="sm" color="secondary" onPress={onReset}>
                            Invite another
                        </Button>
                        <Button size="sm" onPress={onClose}>
                            Done
                        </Button>
                    </>
                ) : (
                    <>
                        <Button size="sm" color="secondary" onPress={onClose} isDisabled={pending}>
                            Cancel
                        </Button>
                        <Button size="sm" type="submit" form="invite-form" isLoading={pending} showTextWhileLoading>
                            Create invitation
                        </Button>
                    </>
                )}
            </SlideoutMenu.Footer>
        </>
    );
}

/** Invitations of the org (System Managers only): status, expiry and Copy link / Resend / Revoke. */
export function InvitationList({ orgSlug, invitations }: { orgSlug: string; invitations: InvitationRow[] }) {
    const origin = useOrigin();
    const [copied, copy] = useCopy();
    const [error, setError] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();

    const run = (action: () => Promise<{ ok: boolean; error?: string; data?: { token: string } }>, copyKey?: string) =>
        startTransition(async () => {
            setError(null);
            const result = await action();
            if (!result.ok) setError(result.error ?? "Something went wrong. Try again.");
            else if (copyKey && result.data) copy(copyKey, inviteLink(origin, result.data.token));
        });

    return (
        <section className="flex flex-col gap-3">
            <h2 className="text-md font-semibold text-primary">Invitations</h2>
            {error && <FormAlert>{error}</FormAlert>}
            <div className="overflow-hidden rounded-xl ring-1 ring-secondary">
                <Table aria-label="Invitations" size="sm">
                    <Table.Header>
                        <Table.Head id="email" label="Email" isRowHeader className="px-4" />
                        <Table.Head id="roles" label="Roles" className="px-4" />
                        <Table.Head id="status" label="Status" className="px-4" />
                        <Table.Head id="expires" label="Expires" className="px-4" />
                        <Table.Head id="actions" label="" className="px-4" />
                    </Table.Header>
                    <Table.Body
                        items={invitations}
                        renderEmptyState={() => <p className="px-4 py-8 text-center text-sm text-tertiary">No invitations yet</p>}
                    >
                        {(inv) => {
                            const status = invitationStatus(inv);
                            const open = status === "pending" || status === "expired";
                            return (
                                <Table.Row id={inv.id} className="h-12">
                                    <Table.Cell className="px-4 py-2 font-medium text-primary">{inv.email}</Table.Cell>
                                    <Table.Cell className="px-4 py-2">
                                        {inv.role_profile ? (
                                            <span className="text-secondary">{inv.role_profile}</span>
                                        ) : (
                                            <RoleBadges roles={inv.roles} />
                                        )}
                                    </Table.Cell>
                                    <Table.Cell className="px-4 py-2">
                                        <Badge size="sm" color={STATUS[status].color}>
                                            {STATUS[status].label}
                                        </Badge>
                                    </Table.Cell>
                                    <Table.Cell className="px-4 py-2 tabular-nums">
                                        <time dateTime={inv.expires_at} suppressHydrationWarning>
                                            {open ? formatDateTime(inv.expires_at) : ""}
                                        </time>
                                    </Table.Cell>
                                    <Table.Cell className="px-4 py-2">
                                        {open && (
                                            <div className="flex justify-end gap-1">
                                                {status === "pending" && (
                                                    <ButtonUtility
                                                        size="xs"
                                                        color="tertiary"
                                                        icon={Copy01}
                                                        tooltip={copied === inv.id ? "Copied" : "Copy link"}
                                                        onPress={() => copy(inv.id, inviteLink(origin, inv.token))}
                                                    />
                                                )}
                                                <ButtonUtility
                                                    size="xs"
                                                    color="tertiary"
                                                    icon={RefreshCw01}
                                                    tooltip="Resend (new link, copied)"
                                                    isDisabled={pending}
                                                    onPress={() => run(() => resendInvitation({ orgSlug, id: inv.id }), inv.id)}
                                                />
                                                {status === "pending" && (
                                                    <ButtonUtility
                                                        size="xs"
                                                        color="tertiary"
                                                        icon={XClose}
                                                        tooltip="Revoke"
                                                        isDisabled={pending}
                                                        onPress={() => run(() => revokeInvitation({ orgSlug, id: inv.id }))}
                                                    />
                                                )}
                                            </div>
                                        )}
                                    </Table.Cell>
                                </Table.Row>
                            );
                        }}
                    </Table.Body>
                </Table>
            </div>
        </section>
    );
}
