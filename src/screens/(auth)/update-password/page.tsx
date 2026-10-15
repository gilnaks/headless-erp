import { AuthHeader } from "../auth-header";
import { UpdatePasswordForm } from "./update-password-form";

export default function UpdatePasswordPage() {
    return (
        <>
            <AuthHeader title="Choose a new password" />
            <UpdatePasswordForm />
        </>
    );
}
