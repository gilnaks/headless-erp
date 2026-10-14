"use client";

import type { Key } from "react-aria-components";
import { type Control, type FieldValues, type Path, useController } from "react-hook-form";
import { Select, type SelectItemType } from "@/components/base/select/select";

type FormComboBoxProps<T extends FieldValues> = {
    control: Control<T>;
    name: Path<T>;
    label: string;
    items: SelectItemType[];
    placeholder?: string;
    hint?: string;
    size?: "sm" | "md" | "lg";
    isRequired?: boolean;
};

/** Searchable Untitled UI `Select.ComboBox` bound to a React Hook Form string field (value = item id). */
export function FormComboBox<T extends FieldValues>({
    control,
    name,
    label,
    items,
    placeholder,
    hint,
    size = "sm",
    isRequired,
}: FormComboBoxProps<T>) {
    const { field, fieldState } = useController({ control, name });
    return (
        <Select.ComboBox
            label={label}
            items={items}
            size={size}
            shortcut={false}
            placeholder={placeholder}
            isRequired={isRequired}
            isInvalid={Boolean(fieldState.error)}
            hint={fieldState.error?.message ?? hint}
            selectedKey={field.value || null}
            onSelectionChange={(key: Key | null) => field.onChange(key == null ? "" : String(key))}
            onBlur={field.onBlur}
            name={field.name}
        >
            {(item) => <Select.Item id={item.id} label={item.label} supportingText={item.supportingText} />}
        </Select.ComboBox>
    );
}
