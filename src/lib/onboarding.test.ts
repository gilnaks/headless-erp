import { describe, expect, it } from "vitest";
import { ONBOARDING_STEP_KEYS, showOnboarding } from "./onboarding";

describe("showOnboarding", () => {
    const steps = ONBOARDING_STEP_KEYS.map((step) => ({ step, status: "open" as const }));

    it("shows the card while a step is open", () => {
        expect(showOnboarding({ steps, dismissed: false })).toBe(true);
    });

    it("hides it once every step is completed or skipped", () => {
        const done = steps.map((s, i) => ({ ...s, status: i % 2 ? ("completed" as const) : ("skipped" as const) }));
        expect(showOnboarding({ steps: done, dismissed: false })).toBe(false);
    });

    it("hides it when dismissed", () => {
        expect(showOnboarding({ steps, dismissed: true })).toBe(false);
    });

    it("lists the eight ported steps (Quality dropped)", () => {
        expect(ONBOARDING_STEP_KEYS).toEqual([
            "invite_users",
            "accounting",
            "selling",
            "buying",
            "stock",
            "manufacturing",
            "projects",
            "assets",
        ]);
    });
});
