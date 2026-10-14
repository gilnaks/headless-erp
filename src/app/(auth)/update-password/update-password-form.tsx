"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { FormInput } from "@/components/erp/form-input";
import { updatePassword } from "@/lib/actions/auth";
import { applyFieldErrors } from "@/lib/forms";
import { MIN_PASSWORD_LENGTH, type UpdatePasswordInput, updatePasswordSchema } from "@/lib/schemas/auth";

export function UpdatePasswordForm() {
    const [error, setError] = useState<string | null>(null);
    const form = useForm<UpdatePasswordInput>({
        resolver: zodResolver(updatePasswordSchema),
        defaultValues: { password: "", confirm: "" },
    });

    const onSubmit = form.handleSubmit(async (values) => {
        setError(null);
        const result = await updatePassword(values);
        if (result && !result.ok) {
            setError(result.error);
            applyFieldErrors(form.setError, result.fieldErrors);
        }
    });

    return (
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
            {error && <FormAlert>{error}</FormAlert>}
            <FormInput
                control={form.control}
                name="password"
                label="New password"
                type="password"
                autoComplete="new-password"
                autoFocus
                hint={`At least ${MIN_PASSWORD_LENGTH} characters.`}
                size="sm"
            />
            <FormInput
                control={form.control}
                name="confirm"
                label="Confirm password"
                type="password"
                autoComplete="new-password"
                size="sm"
            />
            <Button type="submit" size="md" isLoading={form.formState.isSubmitting} showTextWhileLoading>
                Update password
            </Button>
        </form>
    );
}
