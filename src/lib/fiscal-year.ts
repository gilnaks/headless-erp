/** ISO date (`YYYY-MM-DD`) helpers for Fiscal Year, matching `app.fiscal_year_name` and `fiscal_year.js`. */

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const AUTO_NAME = /^\d{4}(-\d{4})?$/;

function parse(date: string): Date | null {
    if (!ISO_DATE.test(date)) return null;
    const d = new Date(`${date}T00:00:00Z`);
    return Number.isNaN(d.getTime()) ? null : d;
}

const iso = (d: Date) => d.toISOString().slice(0, 10);

/** `fiscal_year.js` `year_start_date`: start + 12 months − 1 day (end of month clamped like Frappe `add_months`). */
export function fiscalYearEnd(start: string): string | null {
    const d = parse(start);
    if (!d) return null;
    const year = d.getUTCFullYear() + 1;
    const month = d.getUTCMonth();
    const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    const next = new Date(Date.UTC(year, month, Math.min(d.getUTCDate(), lastDay)));
    next.setUTCDate(next.getUTCDate() - 1);
    return iso(next);
}

/** `get_fy_details`: "2026" within one calendar year, else "2026-2027". */
export function fiscalYearName(start: string, end: string): string | null {
    const s = parse(start);
    const e = parse(end);
    if (!s || !e) return null;
    const a = s.getUTCFullYear();
    const b = e.getUTCFullYear();
    return a === b ? String(a) : `${a}-${b}`;
}

/** `erpnext.setup.fiscal_years` (setup_wizard.js): month-day each country's fiscal year starts on; others use 01-01. */
export const COUNTRY_FISCAL_YEAR_START: Readonly<Record<string, string>> = {
    Afghanistan: "12-21",
    Australia: "07-01",
    Bangladesh: "07-01",
    "Costa Rica": "10-01",
    Egypt: "07-01",
    Ethiopia: "07-08",
    "Hong Kong": "04-01",
    India: "04-01",
    Iran: "06-23",
    Kenya: "07-01",
    Malaysia: "07-01",
    Myanmar: "04-01",
    Nepal: "07-16",
    "New Zealand": "04-01",
    Pakistan: "07-01",
    Singapore: "04-01",
    "South Africa": "03-01",
    "United Kingdom": "04-01",
};

/**
 * Setup wizard `set_fy_dates`: the country's fiscal year that contains `today`. The end is start + 12 months − 1 day
 * (the wizard's start-date handler) rather than the map's end, which is off by one in leap years for South Africa.
 */
export function defaultFiscalYear(country: string, today: string): { start: string; end: string } | null {
    const t = parse(today);
    if (!t) return null;
    const monthDay = COUNTRY_FISCAL_YEAR_START[country] ?? "01-01";
    let year = t.getUTCFullYear();
    if (`${year}-${monthDay}` > today) year -= 1;
    const start = `${year}-${monthDay}`;
    const end = fiscalYearEnd(start);
    return end ? { start, end } : null;
}

/** True when `year` is empty or looks generated from dates, so it may be re-derived when the dates change. */
export function isAutoYearName(year: unknown): boolean {
    return year === undefined || year === null || String(year).trim() === "" || AUTO_NAME.test(String(year).trim());
}
