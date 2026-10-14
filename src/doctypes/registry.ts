import type { Doctype } from "./define";
import { branch } from "./setup/branch";
import { company } from "./setup/company";
import { department } from "./setup/department";
import { designation } from "./setup/designation";
import { globalDefaults } from "./setup/global-defaults";
import { role } from "./setup/role";
import { roleProfile } from "./setup/role-profile";
import { systemSettings } from "./setup/system-settings";
import { userPermission } from "./setup/user-permission";

/** Every doctype with a working list/form. Keep `doctype_meta` (migrations) in sync. */
export const DOCTYPES: readonly Doctype[] = [
    company,
    globalDefaults,
    systemSettings,
    role,
    roleProfile,
    userPermission,
    branch,
    designation,
    department,
];

export function getDoctype(module: string, slug: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.module === module && d.slug === slug);
}

export function getDoctypeByName(name: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.doctype === name);
}
