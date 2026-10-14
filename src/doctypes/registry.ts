import type { Doctype } from "./define";
import { company } from "./setup/company";
import { globalDefaults } from "./setup/global-defaults";

/** Every doctype with a working list/form. Keep `doctype_meta` (migrations) in sync. */
export const DOCTYPES: readonly Doctype[] = [company, globalDefaults];

export function getDoctype(module: string, slug: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.module === module && d.slug === slug);
}

export function getDoctypeByName(name: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.doctype === name);
}
