"use client";

import { SearchLg } from "@untitledui/icons";
import { type ReactNode, useMemo, useState } from "react";
import { Table } from "@/components/application/table/table";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import { Input } from "@/components/base/input/input";
import type { Member } from "@/lib/queries/users";
import { formatDateTime, MemberStatusBadge, RoleBadges } from "./member-badges";

type MemberListProps = { orgSlug: string; members: Member[]; actions?: ReactNode };

const matches = (m: Member, term: string) => [m.fullName, m.email, m.roleProfile, ...m.roles].some((v) => v?.toLowerCase().includes(term));

/** Frappe User list for one organization: members with their roles, status and last sign-in. */
export function MemberList({ orgSlug, members, actions }: MemberListProps) {
    const [search, setSearch] = useState("");
    const term = search.trim().toLowerCase();
    const rows = useMemo(() => (term ? members.filter((m) => matches(m, term)) : members), [members, term]);

    return (
        <div className="flex flex-col gap-4">
            <header className="flex flex-wrap items-center gap-3">
                <h1 className="flex-1 text-lg font-semibold text-primary">Users</h1>
                {actions}
            </header>

            <Input
                aria-label="Search users"
                size="sm"
                icon={SearchLg}
                placeholder="Search name, email or role"
                value={search}
                onChange={setSearch}
                className="max-w-xs"
            />

            <div className="overflow-hidden rounded-xl ring-1 ring-secondary">
                <Table aria-label="Users" size="sm">
                    <Table.Header>
                        <Table.Head id="user" label="User" isRowHeader className="px-4" />
                        <Table.Head id="roles" label="Roles" className="px-4" />
                        <Table.Head id="status" label="Status" className="px-4" />
                        <Table.Head id="last_sign_in" label="Last sign-in" className="px-4" />
                    </Table.Header>
                    <Table.Body
                        items={rows}
                        renderEmptyState={() => (
                            <div className="flex flex-col items-center gap-3 px-4 py-12 text-center">
                                <p className="text-sm font-semibold text-primary">
                                    {term ? `No user matches "${search.trim()}"` : "No users yet"}
                                </p>
                                {term && (
                                    <Button size="sm" color="secondary" onPress={() => setSearch("")}>
                                        Clear search
                                    </Button>
                                )}
                            </div>
                        )}
                    >
                        {(m) => (
                            <Table.Row id={m.userId} href={`/${orgSlug}/setup/users/${m.userId}`} className="h-12 cursor-pointer">
                                <Table.Cell className="px-4 py-2">
                                    <div className="flex min-w-0 flex-col">
                                        <span className="flex items-center gap-2 truncate font-medium text-primary">
                                            {m.fullName ?? m.email}
                                            {m.isOwner && (
                                                <Badge size="sm" color="brand">
                                                    Owner
                                                </Badge>
                                            )}
                                        </span>
                                        {m.fullName && <span className="truncate text-xs text-tertiary">{m.email}</span>}
                                    </div>
                                </Table.Cell>
                                <Table.Cell className="px-4 py-2">
                                    <RoleBadges roles={m.roles} />
                                </Table.Cell>
                                <Table.Cell className="px-4 py-2">
                                    <MemberStatusBadge status={m.status} />
                                </Table.Cell>
                                <Table.Cell className="px-4 py-2 tabular-nums">
                                    <time dateTime={m.lastSignInAt ?? undefined} suppressHydrationWarning>
                                        {formatDateTime(m.lastSignInAt)}
                                    </time>
                                </Table.Cell>
                            </Table.Row>
                        )}
                    </Table.Body>
                </Table>
            </div>
            <p className="text-sm text-tertiary tabular-nums">
                {rows.length} of {members.length} users
            </p>
        </div>
    );
}
