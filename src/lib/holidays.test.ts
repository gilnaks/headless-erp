import { describe, expect, it } from "vitest";
import { addLocalHolidays, addWeeklyHolidays, clearHolidays, totalHolidays, weeklyOffDates } from "./holidays";

const base = { from_date: "2026-01-01", to_date: "2026-01-31", weekly_off: "Sunday", is_half_day: false, holidays: [] };

describe("weeklyOffDates", () => {
    it("lists every matching weekday inside the range", () => {
        expect(weeklyOffDates("2026-01-01", "2026-01-31", "Sunday")).toEqual(["2026-01-04", "2026-01-11", "2026-01-18", "2026-01-25"]);
    });

    it("includes the first and last day when they match", () => {
        expect(weeklyOffDates("2026-01-04", "2026-01-18", "Sunday")).toEqual(["2026-01-04", "2026-01-11", "2026-01-18"]);
        expect(weeklyOffDates("2026-01-01", "2026-01-01", "Thursday")).toEqual(["2026-01-01"]);
    });

    it("ignores unknown weekdays", () => {
        expect(weeklyOffDates("2026-01-01", "2026-01-31", "Someday")).toEqual([]);
    });
});

describe("addWeeklyHolidays", () => {
    it("appends weekly offs with the weekday as description and recomputes the total", () => {
        const next = addWeeklyHolidays({ ...base, is_half_day: true });
        expect(next.holidays).toHaveLength(4);
        expect((next.holidays as Record<string, unknown>[])[0]).toEqual({
            holiday_date: "2026-01-04",
            description: "Sunday",
            weekly_off: true,
            is_half_day: true,
        });
        expect(next.total_holidays).toBe("2");
    });

    it("skips dates already listed", () => {
        const existing = [{ id: "x", holiday_date: "2026-01-11", description: "Party", weekly_off: false, is_half_day: false }];
        const next = addWeeklyHolidays({ ...base, holidays: existing });
        expect((next.holidays as Record<string, unknown>[]).map((r) => r.holiday_date)).toEqual([
            "2026-01-11",
            "2026-01-04",
            "2026-01-18",
            "2026-01-25",
        ]);
        expect((next.holidays as Record<string, unknown>[])[0]).toBe(existing[0]);
    });

    it("needs a weekly off and valid dates", () => {
        expect(() => addWeeklyHolidays({ ...base, weekly_off: "" })).toThrow("Please select weekly off day.");
        expect(() => addWeeklyHolidays({ ...base, to_date: "" })).toThrow("Please set From Date and To Date first.");
        expect(() => addWeeklyHolidays({ ...base, to_date: "2025-12-31" })).toThrow("To Date cannot be before From Date.");
    });
});

describe("addLocalHolidays", () => {
    it("keeps holidays inside the range that are not listed yet", () => {
        const next = addLocalHolidays({ ...base, holidays: [{ holiday_date: "2026-01-06", description: "Kept", weekly_off: false }] }, [
            { date: "2025-12-25", name: "Christmas" },
            { date: "2026-01-01", name: "New Year" },
            { date: "2026-01-06", name: "Epiphany" },
            { date: "2026-02-01", name: "Later" },
        ]);
        expect((next.holidays as Record<string, unknown>[]).map((r) => r.description)).toEqual(["Kept", "New Year"]);
        expect(next.total_holidays).toBe("2");
    });
});

describe("totals", () => {
    it("counts half days as 0.5", () => {
        expect(totalHolidays([{ is_half_day: true }, { is_half_day: false }, {}])).toBe(2.5);
    });

    it("clears the table", () => {
        expect(clearHolidays()).toEqual({ holidays: [], total_holidays: "0" });
    });
});
