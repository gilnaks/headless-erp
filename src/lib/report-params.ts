import { parseAsBoolean, parseAsString } from "nuqs";

/** General Ledger URL state. Dates stay empty here; the page fills the default range when they are blank. */
export const generalLedgerParsers = {
    company: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    account: parseAsString.withDefault(""),
    opening: parseAsBoolean.withDefault(false),
};

/** Trial Balance URL state. A blank year and blank dates are filled from the fiscal year that contains today. */
export const trialBalanceParsers = {
    company: parseAsString.withDefault(""),
    fiscal_year: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    zero: parseAsBoolean.withDefault(false),
    groups: parseAsBoolean.withDefault(true),
    net: parseAsBoolean.withDefault(true),
};

/** Trial Balance for Party URL state. A blank year and blank dates follow the fiscal year that contains today. */
export const trialBalanceForPartyParsers = {
    company: parseAsString.withDefault(""),
    fiscal_year: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    party_type: parseAsString.withDefault("Customer"),
    party: parseAsString.withDefault(""),
    zero: parseAsBoolean.withDefault(false),
    exclude: parseAsBoolean.withDefault(true),
};
