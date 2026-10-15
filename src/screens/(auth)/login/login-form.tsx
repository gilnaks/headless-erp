"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Tabs } from "@/components/application/tabs/tabs";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { FormInput } from "@/components/erp/form-input";
import { sendMagicLink, signInWithPassword } from "@/lib/actions/auth";
import { withNext } from "@/lib/auth/redirect";
import { applyFieldErrors } from "@/lib/forms";
import { afterRedirect } from "@/lib/navigate";
import { Link, useSearchParams } from "@/lib/next-nav";
import { type MagicLinkInput, magicLinkSchema, type PasswordLoginInput, passwordLoginSchema } from "@/lib/schemas/auth";

const QUERY_ERRORS: Record<string, string> = {
    link_invalid: "That sign-in link is invalid or has expired. Request a new one.",
};

export function LoginForm() {
    const searchParams = useSearchParams();
    const next = searchParams.get("next") ?? "/";
    const queryError = QUERY_ERRORS[searchParams.get("error") ?? ""];

    return (
        <div className="flex flex-col gap-5">
            {queryError && <FormAlert>{queryError}</FormAlert>}
            <Tabs defaultSelectedKey="password">
                <Tabs.List type="button-minimal" size="sm" fullWidth aria-label="Sign-in method">
                    <Tabs.Item id="password">Password</Tabs.Item>
                    <Tabs.Item id="magic-link">Email link</Tabs.Item>
                </Tabs.List>
                <Tabs.Panel id="password" className="pt-5">
                    <PasswordForm next={next} />
                </Tabs.Panel>
                <Tabs.Panel id="magic-link" className="pt-5">
                    <MagicLinkForm next={next} />
                </Tabs.Panel>
            </Tabs>
            <p className="text-center text-sm text-tertiary">
                No account yet?{" "}
                <Link href={withNext("/signup", next)} className="font-semibold text-brand-secondary hover:underline">
                    Sign up
                </Link>
            </p>
        </div>
    );
}

function PasswordForm({ next }: { next: string }) {
    const [error, setError] = useState<string | null>(null);
    const form = useForm<PasswordLoginInput>({
        resolver: zodResolver(passwordLoginSchema),
        defaultValues: { email: "", password: "", next },
    });

    const onSubmit = form.handleSubmit(async (values) => {
        setError(null);
        const result = await afterRedirect(signInWithPassword(values));
        if (result && !result.ok) {
            setError(result.error);
            applyFieldErrors(form.setError, result.fieldErrors);
        }
    });

    return (
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
            {error && <FormAlert>{error}</FormAlert>}
            <FormInput control={form.control} name="email" label="Email" type="email" autoComplete="email" autoFocus size="sm" />
            <FormInput control={form.control} name="password" label="Password" type="password" autoComplete="current-password" size="sm" />
            <div className="flex justify-end">
                <Link href="/forgot-password" className="text-sm font-semibold text-brand-secondary hover:underline">
                    Forgot password?
                </Link>
            </div>
            <Button type="submit" size="md" isLoading={form.formState.isSubmitting} showTextWhileLoading>
                Sign in
            </Button>
        </form>
    );
}

function MagicLinkForm({ next }: { next: string }) {
    const [error, setError] = useState<string | null>(null);
    const [sentTo, setSentTo] = useState<string | null>(null);
    const form = useForm<MagicLinkInput>({
        resolver: zodResolver(magicLinkSchema),
        defaultValues: { email: "", next },
    });

    const onSubmit = form.handleSubmit(async (values) => {
        setError(null);
        const result = await sendMagicLink(values);
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
                If an account exists for <span className="font-semibold">{sentTo}</span>, a sign-in link is on its way. It is valid for one
                hour.
            </FormAlert>
        );
    }

    return (
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
            {error && <FormAlert>{error}</FormAlert>}
            <FormInput control={form.control} name="email" label="Email" type="email" autoComplete="email" size="sm" />
            <Button type="submit" size="md" isLoading={form.formState.isSubmitting} showTextWhileLoading>
                Email me a sign-in link
            </Button>
        </form>
    );
}
