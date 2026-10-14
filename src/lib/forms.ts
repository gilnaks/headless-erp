import type { FieldValues, Path, UseFormSetError } from "react-hook-form";
import type { FieldErrors } from "@/lib/errors";

/** Copies server-side field errors from an ActionResult onto a React Hook Form instance. */
export function applyFieldErrors<T extends FieldValues>(setError: UseFormSetError<T>, fieldErrors: FieldErrors | undefined) {
    for (const [name, message] of Object.entries(fieldErrors ?? {})) {
        setError(name as Path<T>, { type: "server", message });
    }
}
