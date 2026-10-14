"use client";

import { Plus } from "@untitledui/icons";
import Link from "next/link";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import type { MemberPermission } from "@/lib/queries/user-permissions";

type MemberPermissionsProps = {
    orgSlug: string;
    userId: string;
    permissions: MemberPermission[];
    canEdit: boolean;
};

/** Frappe User form "User Permissions" view: the records this member is restricted to, each opening its form. */
export function MemberPermissions({ orgSlug, userId, permissions, canEdit }: MemberPermissionsProps) {
    const base = `/${orgSlug}/setup/user-permissions`;
    return (
        <section className="flex flex-col gap-3 border-b border-secondary py-5">
            <div className="flex items-center gap-3">
                <h2 className="flex-1 text-sm font-semibold text-primary">User Permissions</h2>
                {canEdit && (
                    <Button size="sm" color="secondary" iconLeading={Plus} href={`${base}/new?user_id=${userId}`}>
                        Add user permission
                    </Button>
                )}
            </div>
            {permissions.length === 0 ? (
                <p className="text-sm text-tertiary">No restrictions: this user sees every record their roles allow.</p>
            ) : (
                <ul className="flex flex-col divide-y divide-secondary rounded-xl ring-1 ring-secondary">
                    {permissions.map((p) => (
                        <li key={p.id}>
                            <Link
                                href={`${base}/${p.id}`}
                                className="flex flex-wrap items-center gap-2 px-4 py-2.5 text-sm outline-focus-ring hover:bg-primary_hover focus-visible:outline-2"
                            >
                                <span className="text-tertiary">{p.doctype}</span>
                                <span className="font-medium text-primary">{p.record}</span>
                                {p.isDefault && (
                                    <Badge size="sm" color="brand">
                                        Default
                                    </Badge>
                                )}
                                {p.hideDescendants && (
                                    <Badge size="sm" color="gray">
                                        Without descendants
                                    </Badge>
                                )}
                                <span className="ml-auto text-xs text-tertiary">
                                    {p.applicableFor ? `Only for ${p.applicableFor}` : "All document types"}
                                </span>
                            </Link>
                        </li>
                    ))}
                </ul>
            )}
        </section>
    );
}
