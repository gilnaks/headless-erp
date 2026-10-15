"use client";

import { AlertCircle } from "@untitledui/icons";
import { EmptyState } from "@/components/application/empty-state/empty-state";
import { Button } from "@/components/base/buttons/button";

export default function OrgError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
    return (
        <EmptyState size="md" className="py-16">
            <EmptyState.Header pattern="grid">
                <EmptyState.FeaturedIcon icon={AlertCircle} color="error" theme="modern" />
            </EmptyState.Header>
            <EmptyState.Content>
                <EmptyState.Title>Something went wrong</EmptyState.Title>
                <EmptyState.Description>
                    This page failed to load. Try again; if it keeps happening, share reference {error.digest ?? "n/a"} with support.
                </EmptyState.Description>
            </EmptyState.Content>
            <EmptyState.Footer>
                <Button size="md" onPress={reset}>
                    Try again
                </Button>
            </EmptyState.Footer>
        </EmptyState>
    );
}
