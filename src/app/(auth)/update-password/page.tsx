import type { Metadata } from "next";
import { AuthHeader } from "../auth-header";
import { UpdatePasswordForm } from "./update-password-form";

export const metadata: Metadata = { title: "Choose a new password" };

export default function UpdatePasswordPage() {
    return (
        <>
            <AuthHeader title="Choose a new password" />
            <UpdatePasswordForm />
        </>
    );
}
