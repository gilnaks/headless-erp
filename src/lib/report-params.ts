import { parseAsBoolean, parseAsString } from "nuqs";

/** General Ledger URL state. Dates stay empty here; the page fills the default range when they are blank. */
export const generalLedgerParsers = {
    company: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    account: parseAsString.withDefault(""),
    opening: parseAsBoolean.withDefault(false),
};

/** Stock Ledger URL state. Blank dates are filled with today minus one month through today. */
export const stockLedgerParsers = {
    company: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    item: parseAsString.withDefault(""),
    warehouse: parseAsString.withDefault(""),
    voucher_type: parseAsString.withDefault(""),
};

/** Stock Balance URL state. Blank dates are filled with today minus one month through today. Include zero defaults off. */
export const stockBalanceParsers = {
    company: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    item: parseAsString.withDefault(""),
    item_group: parseAsString.withDefault(""),
    warehouse: parseAsString.withDefault(""),
    zero: parseAsBoolean.withDefault(false),
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

/** Profit and Loss URL state. A blank year follows the fiscal year that contains today. */
export const profitAndLossParsers = {
    company: parseAsString.withDefault(""),
    basis: parseAsString.withDefault("Fiscal Year"),
    from_fy: parseAsString.withDefault(""),
    to_fy: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    periodicity: parseAsString.withDefault("Yearly"),
    accumulated: parseAsBoolean.withDefault(false),
    zero: parseAsBoolean.withDefault(false),
};

/** Cash Flow URL state. Accumulated values stay on unless the URL turns them off. */
export const cashFlowParsers = {
    company: parseAsString.withDefault(""),
    basis: parseAsString.withDefault("Fiscal Year"),
    from_fy: parseAsString.withDefault(""),
    to_fy: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    periodicity: parseAsString.withDefault("Yearly"),
    accumulated: parseAsBoolean.withDefault(true),
    opening: parseAsBoolean.withDefault(false),
};

/** Accounts dashboard URL state. Blank dates are filled from the fiscal year that contains today. */
export const dashboardParsers = {
    company: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
};

/** Balance Sheet URL state. Accumulated values stay on unless the URL turns them off. */
export const balanceSheetParsers = {
    company: parseAsString.withDefault(""),
    basis: parseAsString.withDefault("Fiscal Year"),
    from_fy: parseAsString.withDefault(""),
    to_fy: parseAsString.withDefault(""),
    from: parseAsString.withDefault(""),
    to: parseAsString.withDefault(""),
    periodicity: parseAsString.withDefault("Yearly"),
    accumulated: parseAsBoolean.withDefault(true),
    zero: parseAsBoolean.withDefault(false),
};
