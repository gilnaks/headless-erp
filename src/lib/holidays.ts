import type { FieldValues } from "@/doctypes/define";

/** Holiday List weekly off options (ERPNext `weekly_off` Select). */
export const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] as const;

export type LocalHoliday = { date: string; name: string };

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const DAY_MS = 86_400_000;

function utc(date: string): number {
    const [y, m, d] = date.split("-").map(Number);
    return Date.UTC(y, m - 1, d);
}

const iso = (ms: number) => new Date(ms).toISOString().slice(0, 10);

function range(values: FieldValues): { from: string; to: string } {
    const from = String(values.from_date ?? "");
    const to = String(values.to_date ?? "");
    if (!DATE.test(from) || !DATE.test(to)) throw new Error("Please set From Date and To Date first.");
    if (from > to) throw new Error("To Date cannot be before From Date.");
    return { from, to };
}

const rowsOf = (values: FieldValues): FieldValues[] => (Array.isArray(values.holidays) ? (values.holidays as FieldValues[]) : []);

/** `update_total_holidays`: half days count 0.5. */
export function totalHolidays(rows: FieldValues[]): number {
    return rows.reduce((sum, row) => sum + (row.is_half_day ? 0.5 : 1), 0);
}

/** `get_weekly_off_date_list`: every `weekday` from `from` to `to`, inclusive (ISO dates). */
export function weeklyOffDates(from: string, to: string, weekday: string): string[] {
    const target = WEEKDAYS.indexOf(weekday as (typeof WEEKDAYS)[number]);
    if (target < 0) return [];
    const start = utc(from);
    const end = utc(to);
    const offset = (target - new Date(start).getUTCDay() + 7) % 7;
    const dates: string[] = [];
    for (let t = start + offset * DAY_MS; t <= end; t += 7 * DAY_MS) dates.push(iso(t));
    return dates;
}

function withRows(rows: FieldValues[]): FieldValues {
    return { holidays: rows, total_holidays: String(totalHolidays(rows)) };
}

/** `get_weekly_off_dates`: appends the weekly off days that are not listed yet. */
export function addWeeklyHolidays(values: FieldValues): FieldValues {
    const weeklyOff = String(values.weekly_off ?? "");
    if (!weeklyOff) throw new Error("Please select weekly off day.");
    const { from, to } = range(values);
    const rows = rowsOf(values);
    const existing = new Set(rows.map((r) => String(r.holiday_date)));
    const added = weeklyOffDates(from, to, weeklyOff)
        .filter((date) => !existing.has(date))
        .map((date) => ({ holiday_date: date, description: weeklyOff, weekly_off: true, is_half_day: Boolean(values.is_half_day) }));
    return withRows([...rows, ...added]);
}

/** `get_local_holidays` (after the lookup): appends holidays inside the dates that are not listed yet. */
export function addLocalHolidays(values: FieldValues, holidays: LocalHoliday[]): FieldValues {
    const { from, to } = range(values);
    const rows = rowsOf(values);
    const existing = new Set(rows.map((r) => String(r.holiday_date)));
    const added: FieldValues[] = [];
    for (const h of holidays) {
        if (h.date < from || h.date > to || existing.has(h.date)) continue;
        existing.add(h.date);
        added.push({ holiday_date: h.date, description: h.name, weekly_off: false, is_half_day: false });
    }
    return withRows([...rows, ...added]);
}

/** `clear_table`. */
export function clearHolidays(): FieldValues {
    return withRows([]);
}
