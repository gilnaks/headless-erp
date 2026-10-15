import { AuthHeader } from "../auth-header";
import { ForgotPasswordForm } from "./forgot-password-form";

export default function ForgotPasswordPage() {
    return (
        <>
            <AuthHeader title="Reset your password">We will email you a link to choose a new password.</AuthHeader>
            <ForgotPasswordForm />
        </>
    );
}
