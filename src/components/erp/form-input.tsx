"use client";

import { type Control, type FieldValues, type Path, useController } from "react-hook-form";
import { Input, type InputProps } from "@/components/base/input/input";

type FormInputProps<T extends FieldValues> = Omit<InputProps, "name" | "value" | "defaultValue" | "onChange" | "onBlur" | "isInvalid"> & {
    control: Control<T>;
    name: Path<T>;
};

/** Untitled UI `Input` bound to a React Hook Form field; the field error replaces the hint. */
export function FormInput<T extends FieldValues>({ control, name, hint, ...props }: FormInputProps<T>) {
    const { field, fieldState } = useController({ control, name });
    return (
        <Input
            {...props}
            ref={field.ref}
            name={field.name}
            value={field.value ?? ""}
            onChange={field.onChange}
            onBlur={field.onBlur}
            isInvalid={Boolean(fieldState.error)}
            hint={fieldState.error?.message ?? hint}
        />
    );
}
