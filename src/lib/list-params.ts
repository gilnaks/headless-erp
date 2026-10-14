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
