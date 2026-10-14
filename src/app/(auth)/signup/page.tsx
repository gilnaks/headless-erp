import type { Metadata } from "next";
import { Suspense } from "react";
import { AuthHeader } from "../auth-header";
import { SignupForm } from "./signup-form";

export const metadata: Metadata = { title: "Sign up" };

export default function SignupPage() {
    return (
        <>
            <AuthHeader title="Create your account">You can set up your organization right after confirming your email.</AuthHeader>
            <Suspense>
                <SignupForm />
            </Suspense>
        </>
    );
}
