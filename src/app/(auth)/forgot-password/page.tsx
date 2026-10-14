import type { Metadata } from "next";
import { AuthHeader } from "../auth-header";
import { ForgotPasswordForm } from "./forgot-password-form";

export const metadata: Metadata = { title: "Reset password" };

export default function ForgotPasswordPage() {
    return (
        <>
            <AuthHeader title="Reset your password">We will email you a link to choose a new password.</AuthHeader>
            <ForgotPasswordForm />
        </>
    );
}
