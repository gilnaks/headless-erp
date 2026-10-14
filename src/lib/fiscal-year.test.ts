import { describe, expect, it } from "vitest";
import { defaultFiscalYear, fiscalYearEnd, fiscalYearName, isAutoYearName } from "./fiscal-year";

describe("fiscalYearEnd", () => {
    it("ends one day before the same date next year", () => {
        expect(fiscalYearEnd("2026-01-01")).toBe("2026-12-31");
        expect(fiscalYearEnd("2026-04-01")).toBe("2027-03-31");
        expect(fiscalYearEnd("2026-07-15")).toBe("2027-07-14");
    });

    it("clamps a leap day like Frappe add_months", () => {
        expect(fiscalYearEnd("2024-02-29")).toBe("2025-02-27");
    });

    it("ignores invalid dates", () => {
        expect(fiscalYearEnd("")).toBeNull();
        expect(fiscalYearEnd("2026-13-01")).toBeNull();
    });
});

describe("fiscalYearName", () => {
    it("uses one year or start-end", () => {
        expect(fiscalYearName("2026-01-01", "2026-12-31")).toBe("2026");
        expect(fiscalYearName("2026-04-01", "2027-03-31")).toBe("2026-2027");
        expect(fiscalYearName("2026-04-01", "")).toBeNull();
    });
});

describe("defaultFiscalYear", () => {
    it("uses the calendar year for countries without an entry", () => {
        expect(defaultFiscalYear("Philippines", "2026-10-15")).toEqual({ start: "2026-01-01", end: "2026-12-31" });
        expect(defaultFiscalYear("", "2026-01-01")).toEqual({ start: "2026-01-01", end: "2026-12-31" });
    });

    it("starts this year once the country's start date has passed", () => {
        expect(defaultFiscalYear("India", "2026-10-15")).toEqual({ start: "2026-04-01", end: "2027-03-31" });
        expect(defaultFiscalYear("India", "2026-04-01")).toEqual({ start: "2026-04-01", end: "2027-03-31" });
    });

    it("starts last year before the country's start date", () => {
        expect(defaultFiscalYear("Australia", "2026-03-10")).toEqual({ start: "2025-07-01", end: "2026-06-30" });
        expect(defaultFiscalYear("Afghanistan", "2026-12-20")).toEqual({ start: "2025-12-21", end: "2026-12-20" });
    });

    it("ends on the leap day when the year needs it", () => {
        expect(defaultFiscalYear("South Africa", "2027-06-01")).toEqual({ start: "2027-03-01", end: "2028-02-29" });
    });

    it("ignores invalid dates", () => {
        expect(defaultFiscalYear("India", "today")).toBeNull();
    });
});

describe("isAutoYearName", () => {
    it("accepts empty and generated names only", () => {
        expect(isAutoYearName("")).toBe(true);
        expect(isAutoYearName(undefined)).toBe(true);
        expect(isAutoYearName("2026")).toBe(true);
        expect(isAutoYearName("2026-2027")).toBe(true);
        expect(isAutoYearName("FY 2026")).toBe(false);
    });
});
