"use client";

import { Clock } from "@untitledui/icons";
import { EmptyState } from "@/components/application/empty-state/empty-state";
import { Button } from "@/components/base/buttons/button";

type PlaceholderPageProps = {
    title: string;
    description: string;
    /** e.g. "P3" — rendered as "Coming in phase P3". */
    phase?: string;
    action?: { label: string; href: string };
};

export function PlaceholderPage({ title, description, phase, action }: PlaceholderPageProps) {
    return (
        <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-1 border-b border-secondary pb-5">
                <h1 className="text-display-xs font-semibold text-primary">{title}</h1>
                {phase && <p className="text-sm text-tertiary">Coming in phase {phase}</p>}
            </div>
            <EmptyState size="md" className="py-10">
                <EmptyState.Header pattern="grid">
                    <EmptyState.FeaturedIcon icon={Clock} color="gray" theme="modern" />
                </EmptyState.Header>
                <EmptyState.Content>
                    <EmptyState.Title>{phase ? `Not built yet (phase ${phase})` : title}</EmptyState.Title>
                    <EmptyState.Description>{description}</EmptyState.Description>
                </EmptyState.Content>
                {action && (
                    <EmptyState.Footer>
                        <Button href={action.href} size="md" color="secondary">
                            {action.label}
                        </Button>
                    </EmptyState.Footer>
                )}
            </EmptyState>
        </div>
    );
}
