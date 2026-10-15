/**
 * Home onboarding checklist (erpnext/setup/module_onboarding/organization_onboarding; docs/modules/00-setup.md §7).
 * Keys match the `onboarding_progress.step` check constraint (0126); `path` is below `/[org]`.
 */
export const ONBOARDING_STEPS = [
    {
        step: "invite_users",
        title: "Invite your team",
        description: "Add the people you work with and choose what they can see.",
        path: "setup/users",
    },
    {
        step: "accounting",
        title: "Get your books ready",
        description: "Check your chart of accounts and taxes, and add the bank account you use.",
        path: "accounts",
    },
    {
        step: "selling",
        title: "Make your first sale",
        description: "Add an item and a customer, bill them and collect the payment.",
        path: "selling",
    },
    {
        step: "buying",
        title: "Order from your suppliers",
        description: "Add a supplier, order from them and pay their bill.",
        path: "buying",
    },
    {
        step: "stock",
        title: "Keep track of your stock",
        description: "Set up your warehouses and enter the stock you have today.",
        path: "stock",
    },
    {
        step: "manufacturing",
        title: "Plan and run production",
        description: "Write down what goes into a product and make it with a work order.",
        path: "manufacturing",
    },
    {
        step: "projects",
        title: "Plan and deliver projects",
        description: "Break a project into tasks and log the time your team spends.",
        path: "projects",
    },
    {
        step: "assets",
        title: "Track what your business owns",
        description: "Record an asset and see what it's worth year by year.",
        path: "assets",
    },
] as const;

export type OnboardingStepKey = (typeof ONBOARDING_STEPS)[number]["step"];

export const ONBOARDING_STEP_KEYS = ONBOARDING_STEPS.map((s) => s.step) as [OnboardingStepKey, ...OnboardingStepKey[]];

export type OnboardingStepState = { step: OnboardingStepKey; status: "open" | "completed" | "skipped" };

export type OnboardingState = { steps: OnboardingStepState[]; dismissed: boolean };

/** Frappe Module Onboarding: the card hides once it is dismissed or every step is completed or skipped. */
export function showOnboarding(state: OnboardingState): boolean {
    return !state.dismissed && state.steps.some((s) => s.status === "open");
}
