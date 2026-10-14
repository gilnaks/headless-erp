import { Badge } from "@/components/base/badges/badges";

const STATUS: Record<string, { label: string; color: "success" | "gray" | "warning" }> = {
    active: { label: "Active", color: "success" },
    disabled: { label: "Disabled", color: "gray" },
    invited: { label: "Invited", color: "warning" },
};

export function MemberStatusBadge({ status }: { status: string }) {
    const s = STATUS[status] ?? { label: status, color: "gray" as const };
    return (
        <Badge size="sm" color={s.color}>
            {s.label}
        </Badge>
    );
}

export function RoleBadges({ roles, max = 3 }: { roles: string[]; max?: number }) {
    if (!roles.length) return <span className="text-quaternary">No roles</span>;
    const shown = roles.slice(0, max);
    return (
        <div className="flex flex-wrap gap-1">
            {shown.map((role) => (
                <Badge key={role} size="sm" color="gray">
                    {role}
                </Badge>
            ))}
            {roles.length > max && (
                <Badge size="sm" color="gray">
                    +{roles.length - max}
                </Badge>
            )}
        </div>
    );
}

export function formatDateTime(value: string | null): string {
    if (!value) return "";
    return new Date(value).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}
