import { describe, expect, it } from "vitest";
import { fiscalYearEnd, fiscalYearName, isAutoYearName } from "./fiscal-year";

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

describe("isAutoYearName", () => {
    it("accepts empty and generated names only", () => {
        expect(isAutoYearName("")).toBe(true);
        expect(isAutoYearName(undefined)).toBe(true);
        expect(isAutoYearName("2026")).toBe(true);
        expect(isAutoYearName("2026-2027")).toBe(true);
        expect(isAutoYearName("FY 2026")).toBe(false);
    });
});
