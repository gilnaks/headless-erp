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

/** True when `year` is empty or looks generated from dates, so it may be re-derived when the dates change. */
export function isAutoYearName(year: unknown): boolean {
    return year === undefined || year === null || String(year).trim() === "" || AUTO_NAME.test(String(year).trim());
}
