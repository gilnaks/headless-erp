"use client";

import { ArrowRight, CheckCircle } from "@untitledui/icons";
import { useState, useTransition } from "react";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import { ProgressBar } from "@/components/base/progress-indicators/progress-indicators";
import { dismissOnboarding, skipOnboardingStep } from "@/lib/actions/onboarding";
import { Link } from "@/lib/next-nav";
import { ONBOARDING_STEPS, type OnboardingStepKey, type OnboardingStepState } from "@/lib/onboarding";

type OnboardingCardProps = { orgSlug: string; steps: OnboardingStepState[] };

/** Home workspace onboarding ("Get to know ERPNext", Organization Onboarding): System Managers only. */
export function OnboardingCard({ orgSlug, steps }: OnboardingCardProps) {
    const [pending, startTransition] = useTransition();
    const [error, setError] = useState<string | null>(null);
    const status = new Map(steps.map((s) => [s.step, s.status]));
    const shown = ONBOARDING_STEPS.filter((s) => status.has(s.step));
    const done = steps.filter((s) => s.status !== "open").length;

    const run = (action: () => Promise<{ ok: boolean; error?: string }>) =>
        startTransition(async () => {
            setError(null);
            const result = await action();
            if (!result.ok) setError(result.error ?? "Something went wrong.");
        });
    const skip = (step: OnboardingStepKey) => run(() => skipOnboardingStep({ orgSlug, step }));

    return (
        <section aria-label="Get started" className="flex flex-col gap-4 rounded-xl bg-primary p-5 ring-1 ring-secondary">
            <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="flex flex-col gap-1">
                    <h2 className="text-md font-semibold text-primary">Get started</h2>
                    <p className="text-sm text-tertiary">A few steps to set up your organization.</p>
                </div>
                <Button size="sm" color="tertiary" isDisabled={pending} onPress={() => run(() => dismissOnboarding({ orgSlug }))}>
                    Dismiss
                </Button>
            </div>
            <ProgressBar
                value={done}
                max={Math.max(steps.length, 1)}
                labelPosition="right"
                valueFormatter={(v) => `${v} of ${steps.length} done`}
            />
            {error && <p className="text-sm text-error-primary">{error}</p>}
            <ul className="flex flex-col divide-y divide-secondary">
                {shown.map((s) => {
                    const state = status.get(s.step);
                    return (
                        <li key={s.step} aria-label={s.title} className="flex items-center gap-3 py-3">
                            {state === "completed" ? (
                                <CheckCircle aria-hidden="true" className="size-5 shrink-0 text-fg-success-primary" />
                            ) : (
                                <span aria-hidden="true" className="size-5 shrink-0 rounded-full ring-1 ring-primary ring-inset" />
                            )}
                            <div className="flex min-w-0 flex-1 flex-col">
                                <span className="text-sm font-medium text-primary">{s.title}</span>
                                <span className="text-sm text-tertiary">{s.description}</span>
                            </div>
                            {state === "open" ? (
                                <div className="flex shrink-0 items-center gap-1">
                                    <Button size="sm" color="link-gray" isDisabled={pending} onPress={() => skip(s.step)}>
                                        Skip
                                    </Button>
                                    <Link
                                        href={`/${orgSlug}/${s.path}`}
                                        className="flex items-center gap-1 rounded-md px-2 py-1 text-sm font-semibold text-brand-secondary outline-focus-ring hover:text-brand-secondary_hover focus-visible:outline-2"
                                    >
                                        Start
                                        <ArrowRight aria-hidden="true" className="size-4" />
                                    </Link>
                                </div>
                            ) : (
                                <Badge size="sm" color={state === "completed" ? "success" : "gray"}>
                                    {state === "completed" ? "Done" : "Skipped"}
                                </Badge>
                            )}
                        </li>
                    );
                })}
            </ul>
        </section>
    );
}
