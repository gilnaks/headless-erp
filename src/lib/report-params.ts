import { parseAsBoolean, parseAsString } from "nuqs";

/** General Ledger URL state. Dates stay empty here; the page fills the default range when they are blank. */
export const generalLedgerParsers = {
    company: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    account: parseAsString.withDefault(""),
    opening: parseAsBoolean.withDefault(false),
};
