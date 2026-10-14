"use client";

import { createContext, useContext, useMemo } from "react";
import type { Key } from "react-aria-components";
import { type Control, type FieldValues, useController } from "react-hook-form";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { HintText } from "@/components/base/input/hint-text";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { TextArea } from "@/components/base/textarea/textarea";
import type { FieldDef, OptionSource } from "@/doctypes/define";
import type { ReferenceOptions } from "@/lib/reference-options";
import { LinkField } from "./link-field";

/** Reference-table options (Currency, Country) loaded by the route and shared by every field in the form. */
export const ReferenceOptionsContext = createContext<ReferenceOptions>({});

export type FieldRendererProps = {
    control: Control<FieldValues>;
    name: string;
    field: FieldDef;
    orgSlug: string;
    isDisabled?: boolean;
    /** Grid cell: no visible label or hint (the column header labels it). */
    compact?: boolean;
};

const NONE = "__none__";

const NUMERIC_INPUT: Partial<Record<FieldDef["type"], "numeric" | "decimal">> = {
    Int: "numeric",
    Float: "decimal",
    Currency: "decimal",
    Percent: "decimal",
};

/** Renders one ERPNext field (by `fieldtype`) bound to React Hook Form. Table fields are rendered by `ChildTable`. */
export function FieldRenderer(props: FieldRendererProps) {
    const { field } = props;
    switch (field.type) {
        case "Table":
            return null;
        case "Link":
            return <LinkField {...props} />;
        case "Check":
            return <CheckField {...props} />;
        case "Text":
            return <TextField {...props} />;
        case "Select":
            return Array.isArray(field.options) ? <FixedSelectField {...props} /> : <SourceSelectField {...props} />;
        default:
            return <InputField {...props} />;
    }
}

function labelProps(field: FieldDef, compact?: boolean) {
    return compact ? { "aria-label": field.label } : { label: field.label };
}

function InputField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    const numeric = NUMERIC_INPUT[field.type];
    return (
        <Input
            {...labelProps(field, compact)}
            ref={f.ref}
            name={f.name}
            type={field.type === "Date" ? "date" : "text"}
            inputMode={numeric}
            size="sm"
            value={typeof f.value === "string" ? f.value : ""}
            onChange={f.onChange}
            onBlur={f.onBlur}
            placeholder={field.placeholder}
            isRequired={field.required}
            isDisabled={isDisabled}
            isInvalid={Boolean(fieldState.error)}
            hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
            inputClassName={numeric ? "tabular-nums text-right" : undefined}
        />
    );
}

function TextField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    return (
        <TextArea
            {...labelProps(field, compact)}
            textAreaRef={f.ref}
            name={f.name}
            size="sm"
            rows={compact ? 1 : 3}
            value={typeof f.value === "string" ? f.value : ""}
            onChange={f.onChange}
            onBlur={f.onBlur}
            placeholder={field.placeholder}
            isRequired={field.required}
            isDisabled={isDisabled}
            isInvalid={Boolean(fieldState.error)}
            hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
        />
    );
}

function CheckField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    return (
        <div className="flex flex-col gap-1.5 pt-1">
            <Checkbox
                {...labelProps(field, compact)}
                ref={f.ref}
                name={f.name}
                isSelected={Boolean(f.value)}
                onChange={f.onChange}
                onBlur={f.onBlur}
                isDisabled={isDisabled}
                isInvalid={Boolean(fieldState.error)}
                hint={compact ? undefined : field.description}
            />
            {fieldState.error && !compact && <HintText isInvalid>{fieldState.error.message}</HintText>}
        </div>
    );
}

function FixedSelectField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    const items = useMemo(() => {
        const options = (field.options as readonly string[]).filter(Boolean).map((o) => ({ id: o, label: o }));
        return field.required ? options : [{ id: NONE, label: "None" }, ...options];
    }, [field.options, field.required]);
    const value = typeof f.value === "string" && f.value ? f.value : null;
    return (
        <Select
            {...labelProps(field, compact)}
            items={items}
            size="sm"
            placeholder={field.placeholder ?? "Select"}
            isRequired={field.required}
            isDisabled={isDisabled}
            isInvalid={Boolean(fieldState.error)}
            hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
            selectedKey={value}
            onSelectionChange={(key: Key | null) => f.onChange(key == null || key === NONE ? "" : String(key))}
            onBlur={f.onBlur}
            name={f.name}
        >
            {(item) => <Select.Item id={item.id} label={item.label} />}
        </Select>
    );
}

function SourceSelectField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    const items = useContext(ReferenceOptionsContext)[field.options as OptionSource] ?? [];
    return (
        <Select.ComboBox
            {...labelProps(field, compact)}
            items={items}
            size="sm"
            shortcut={false}
            placeholder={field.placeholder ?? "Search"}
            isRequired={field.required}
            isDisabled={isDisabled}
            isInvalid={Boolean(fieldState.error)}
            hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
            selectedKey={typeof f.value === "string" && f.value ? f.value : null}
            onSelectionChange={(key: Key | null) => f.onChange(key == null ? "" : String(key))}
            onBlur={f.onBlur}
            name={f.name}
        >
            {(item) => <Select.Item id={item.id} label={item.label} supportingText={item.supportingText} />}
        </Select.ComboBox>
    );
}
