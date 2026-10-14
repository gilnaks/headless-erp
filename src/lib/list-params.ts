import { createLoader, parseAsBoolean, parseAsInteger, parseAsString } from "nuqs/server";

export const PAGE_SIZES = [20, 50, 100] as const;

/** List view URL state (`?q=&sort=&desc=&page=&size=`), shared by the server page and the `DocList` client. */
export const listParsers = {
    q: parseAsString.withDefault(""),
    sort: parseAsString,
    desc: parseAsBoolean.withDefault(false),
    page: parseAsInteger.withDefault(1),
    size: parseAsInteger.withDefault(20),
};

export const loadListParams = createLoader(listParsers);

/** `?view=tree` switches a tree doctype's list route to the Tree view (ERPNext `/app/<doctype>/view/tree`). */
export const viewParsers = { view: parseAsString };

export const loadViewParams = createLoader(viewParsers);

/** Tree view URL state: "Include disabled" (filter fields are added per doctype). */
export const treeParsers = { disabled: parseAsBoolean.withDefault(false) };
