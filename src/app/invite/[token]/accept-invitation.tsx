"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { acceptInvitation } from "@/lib/actions/organization";

export function AcceptInvitation({ token }: { token: string }) {
    const [error, setError] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();

    return (
        <div className="flex flex-col gap-3">
            {error && <FormAlert>{error}</FormAlert>}
            <Button
                size="md"
                isLoading={pending}
                showTextWhileLoading
                onPress={() =>
                    startTransition(async () => {
                        setError(null);
                        const result = await acceptInvitation(token);
                        if (result && !result.ok) setError(result.error);
                    })
                }
            >
                Accept invitation
            </Button>
        </div>
    );
}
