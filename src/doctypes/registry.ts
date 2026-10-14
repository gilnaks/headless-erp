import type { Doctype } from "./define";
import { company } from "./setup/company";
import { globalDefaults } from "./setup/global-defaults";
import { role } from "./setup/role";
import { roleProfile } from "./setup/role-profile";
import { systemSettings } from "./setup/system-settings";
import { userPermission } from "./setup/user-permission";

/** Every doctype with a working list/form. Keep `doctype_meta` (migrations) in sync. */
export const DOCTYPES: readonly Doctype[] = [company, globalDefaults, systemSettings, role, roleProfile, userPermission];

export function getDoctype(module: string, slug: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.module === module && d.slug === slug);
}

export function getDoctypeByName(name: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.doctype === name);
}
