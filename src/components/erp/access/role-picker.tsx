"use client";

import { useMemo, useState } from "react";
import type { Key, Selection } from "react-aria-components";
import { MultiSelect } from "@/components/base/select/multi-select";
import { Select } from "@/components/base/select/select";
import type { RoleProfileOption } from "@/lib/queries/users";
import { cx } from "@/utils/cx";

export type RoleOption = { id: string; label: string };

const NONE = "__none__";

/** Profile + hand-picked roles; while a profile is set its roles are shown and the roles list is read-only. */
export function useRoleAssignment(initial: { profile: string | null; roles: string[] }, profiles: RoleProfileOption[]) {
    const [profile, setProfileState] = useState(initial.profile);
    const [roles, setRoles] = useState(initial.roles);
    const profileRoles = profile ? (profiles.find((p) => p.name === profile)?.roles ?? []) : null;

    const setProfile = (next: string | null) => {
        // Clearing the profile keeps its roles as a starting point for hand-picked roles.
        if (!next && profileRoles) setRoles(profileRoles);
        setProfileState(next);
    };
    return { profile, roles, shownRoles: profileRoles ?? roles, setProfile, setRoles };
}

type RolePickerProps = {
    assignment: ReturnType<typeof useRoleAssignment>;
    profiles: RoleProfileOption[];
    roleOptions: RoleOption[];
    isDisabled?: boolean;
    rolesError?: string | null;
    rolesHint?: string;
    className?: string;
};

export function RolePicker({ assignment, profiles, roleOptions, isDisabled, rolesError, rolesHint, className }: RolePickerProps) {
    const { profile, shownRoles, setProfile, setRoles } = assignment;
    const roleItems = useMemo(() => {
        const missing = shownRoles.filter((r) => !roleOptions.some((o) => o.id === r)).map((r) => ({ id: r, label: r }));
        return [...roleOptions, ...missing];
    }, [roleOptions, shownRoles]);
    const profileItems = useMemo(() => [{ id: NONE, label: "None" }, ...profiles.map((p) => ({ id: p.name, label: p.name }))], [profiles]);

    return (
        <div className={cx("grid gap-x-8 gap-y-4", className)}>
            <Select
                label="Role Profile"
                items={profileItems}
                size="sm"
                placeholder="None"
                isDisabled={isDisabled}
                hint="Assigns the profile's roles; edit the profile to change them for everyone holding it."
                selectedKey={profile ?? NONE}
                onSelectionChange={(key: Key | null) => setProfile(key == null || key === NONE ? null : String(key))}
            >
                {(item) => <Select.Item id={item.id} label={item.label} />}
            </Select>
            <MultiSelect
                label="Roles"
                items={roleItems}
                size="sm"
                placeholder="Select"
                isDisabled={isDisabled || Boolean(profile)}
                isInvalid={Boolean(rolesError)}
                hint={rolesError ?? (profile ? "Set by the role profile." : rolesHint)}
                selectedKeys={new Set(shownRoles)}
                onSelectionChange={(keys: Selection) => setRoles(keys === "all" ? roleItems.map((i) => i.id) : [...keys].map(String))}
                onReset={() => setRoles([])}
                onSelectAll={() => setRoles(roleItems.map((i) => i.id))}
                selectedCountFormatter={() => shownRoles.join(", ")}
            >
                {(item) => <MultiSelect.Item id={item.id} label={item.label} />}
            </MultiSelect>
        </div>
    );
}
