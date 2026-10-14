"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { FormInput } from "@/components/erp/form-input";
import { sendPasswordReset } from "@/lib/actions/auth";
import { applyFieldErrors } from "@/lib/forms";
import { type ForgotPasswordInput, forgotPasswordSchema } from "@/lib/schemas/auth";

export function ForgotPasswordForm() {
    const [error, setError] = useState<string | null>(null);
    const [sentTo, setSentTo] = useState<string | null>(null);
    const form = useForm<ForgotPasswordInput>({
        resolver: zodResolver(forgotPasswordSchema),
        defaultValues: { email: "" },
    });

    const onSubmit = form.handleSubmit(async (values) => {
        setError(null);
        const result = await sendPasswordReset(values);
        if (result.ok) {
            setSentTo(values.email);
        } else {
            setError(result.error);
            applyFieldErrors(form.setError, result.fieldErrors);
        }
    });

    return (
        <div className="flex flex-col gap-4">
            {sentTo ? (
                <FormAlert tone="success">
                    If an account exists for <span className="font-semibold">{sentTo}</span>, a reset link is on its way.
                </FormAlert>
            ) : (
                <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
                    {error && <FormAlert>{error}</FormAlert>}
                    <FormInput control={form.control} name="email" label="Email" type="email" autoComplete="email" autoFocus size="sm" />
                    <Button type="submit" size="md" isLoading={form.formState.isSubmitting} showTextWhileLoading>
                        Send reset link
                    </Button>
                </form>
            )}
            <p className="text-center text-sm text-tertiary">
                <Link href="/login" className="font-semibold text-brand-secondary hover:underline">
                    Back to sign in
                </Link>
            </p>
        </div>
    );
}
