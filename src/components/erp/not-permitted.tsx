import { FormAlert } from "@/components/erp/form-alert";

export function NotPermitted({ action, doctype }: { action: string; doctype: string }) {
    return (
        <FormAlert>
            You do not have permission to {action} {doctype}. Ask a System Manager for access.
        </FormAlert>
    );
}
