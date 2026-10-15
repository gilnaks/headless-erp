import { Suspense } from "react";
import { AuthHeader } from "../auth-header";
import { LoginForm } from "./login-form";

export default function LoginPage() {
    return (
        <>
            <AuthHeader title="Sign in">Welcome back. Use your password or get a sign-in link by email.</AuthHeader>
            <Suspense>
                <LoginForm />
            </Suspense>
        </>
    );
}
