"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { FormInput } from "@/components/erp/form-input";
import { signUp } from "@/lib/actions/auth";
import { withNext } from "@/lib/auth/redirect";
import { applyFieldErrors } from "@/lib/forms";
import { MIN_PASSWORD_LENGTH, type SignupInput, signupSchema } from "@/lib/schemas/auth";

export function SignupForm() {
    const next = useSearchParams().get("next") ?? "/";
    const [error, setError] = useState<string | null>(null);
    const [sentTo, setSentTo] = useState<string | null>(null);
    const form = useForm<SignupInput>({
        resolver: zodResolver(signupSchema),
        defaultValues: { first_name: "", last_name: "", email: "", password: "", next },
    });

    const onSubmit = form.handleSubmit(async (values) => {
        setError(null);
        const result = await signUp(values);
        if (!result) return;
        if (result.ok) {
            setSentTo(values.email);
        } else {
            setError(result.error);
            applyFieldErrors(form.setError, result.fieldErrors);
        }
    });

    if (sentTo) {
        return (
            <FormAlert tone="success">
                Check <span className="font-semibold">{sentTo}</span> for a confirmation link. It signs you in and takes you to the next
                step.
            </FormAlert>
        );
    }

    return (
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
            {error && <FormAlert>{error}</FormAlert>}
            <div className="grid grid-cols-2 gap-3">
                <FormInput control={form.control} name="first_name" label="First name" autoComplete="given-name" autoFocus size="sm" />
                <FormInput control={form.control} name="last_name" label="Last name" autoComplete="family-name" size="sm" />
            </div>
            <FormInput control={form.control} name="email" label="Email" type="email" autoComplete="email" size="sm" />
            <FormInput
                control={form.control}
                name="password"
                label="Password"
                type="password"
                autoComplete="new-password"
                hint={`At least ${MIN_PASSWORD_LENGTH} characters.`}
                size="sm"
            />
            <Button type="submit" size="md" isLoading={form.formState.isSubmitting} showTextWhileLoading>
                Create account
            </Button>
            <p className="text-center text-sm text-tertiary">
                Already have an account?{" "}
                <Link href={withNext("/login", next)} className="font-semibold text-brand-secondary hover:underline">
                    Sign in
                </Link>
            </p>
        </form>
    );
}
