"use client";

import { createContext, useContext, useMemo } from "react";
import type { Key, Selection } from "react-aria-components";
import { type Control, type FieldValues, useController, useWatch } from "react-hook-form";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { HintText } from "@/components/base/input/hint-text";
import { Input } from "@/components/base/input/input";
import { MultiSelect } from "@/components/base/select/multi-select";
import { Select } from "@/components/base/select/select";
import { TextArea } from "@/components/base/textarea/textarea";
import type { FieldDef, OptionSource } from "@/doctypes/define";
import type { ReferenceOptions } from "@/lib/reference-options";
import { cx } from "@/utils/cx";
import { AttachImageField } from "./attach-image-field";
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
        case "DynamicLink":
            return <DynamicLinkField {...props} />;
        case "Check":
            return <CheckField {...props} />;
        case "Text":
            return <TextField {...props} />;
        case "Select":
            return Array.isArray(field.options) ? <FixedSelectField {...props} /> : <SourceSelectField {...props} />;
        case "MultiSelect":
            return <MultiSelectField {...props} />;
        case "Color":
            return <ColorField {...props} />;
        case "AttachImage":
            return <AttachImageField {...props} />;
        default:
            return <InputField {...props} />;
    }
}

/** ERPNext Dynamic Link: a Link whose target doctype is the value of `field.optionsField`. */
function DynamicLinkField(props: FieldRendererProps) {
    const target = useWatch({ control: props.control, name: props.field.optionsField ?? "" });
    return <LinkField {...props} target={typeof target === "string" ? target : ""} />;
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

const HEX_COLOR = /^#[0-9a-f]{6}$/i;

/** ERPNext Color: a hex value typed or picked with the native colour picker. */
function ColorField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    const value = typeof f.value === "string" ? f.value : "";
    return (
        <div className="flex items-start gap-2">
            <Input
                {...labelProps(field, compact)}
                ref={f.ref}
                name={f.name}
                size="sm"
                className="flex-1"
                value={value}
                onChange={f.onChange}
                onBlur={f.onBlur}
                placeholder="#3366ff"
                isRequired={field.required}
                isDisabled={isDisabled}
                isInvalid={Boolean(fieldState.error)}
                hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
            />
            <input
                type="color"
                aria-label={`Pick ${field.label}`}
                value={HEX_COLOR.test(value) ? value.toLowerCase() : "#000000"}
                onChange={(e) => f.onChange(e.target.value)}
                disabled={isDisabled}
                className={cx(
                    "h-9 w-10 shrink-0 cursor-pointer rounded-lg bg-primary p-1 ring-1 ring-primary ring-inset disabled:cursor-not-allowed disabled:opacity-50",
                    !compact && "mt-6",
                )}
            />
        </div>
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
            rows={compact ? 1 : field.html ? 8 : 3}
            textAreaClassName={field.html ? "font-mono text-xs" : undefined}
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

/** `text[]` column: a searchable checkbox list; the trigger shows the selected labels. */
function MultiSelectField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    const sourced = useContext(ReferenceOptionsContext);
    const items = useMemo(() => {
        const listed = Array.isArray(field.options)
            ? (field.options as readonly string[]).filter(Boolean).map((o) => ({ id: o, label: o }))
            : (sourced[field.options as OptionSource] ?? []);
        const values: string[] = Array.isArray(f.value) ? f.value : [];
        // Keep stored values that are no longer offered (e.g. a disabled role) visible and removable.
        const missing = values.filter((v) => !listed.some((i) => i.id === v)).map((v) => ({ id: v, label: v }));
        return [...listed, ...missing];
    }, [field.options, sourced, f.value]);
    const selected: string[] = Array.isArray(f.value) ? f.value : [];
    const set = (keys: string[]) => {
        f.onChange(keys);
        f.onBlur();
    };
    return (
        <MultiSelect
            label={compact ? undefined : field.label}
            items={items}
            size="sm"
            placeholder={field.placeholder ?? "Select"}
            isRequired={field.required}
            isDisabled={isDisabled}
            isInvalid={Boolean(fieldState.error)}
            hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
            selectedKeys={new Set(selected)}
            onSelectionChange={(keys: Selection) => set(keys === "all" ? items.map((i) => String(i.id)) : [...keys].map(String))}
            onReset={() => set([])}
            onSelectAll={() => set(items.map((i) => String(i.id)))}
            selectedCountFormatter={() => selected.join(", ")}
        >
            {(item) => <MultiSelect.Item id={item.id} label={item.label} />}
        </MultiSelect>
    );
}

function SourceSelectField({ control, name, field, isDisabled, compact }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    const all = useContext(ReferenceOptionsContext)[field.options as OptionSource] ?? [];
    const values = useWatch({ control, disabled: !field.filterOptions });
    const { filterOptions } = field;
    const items = useMemo(
        () => (filterOptions ? all.filter((item) => item.id === f.value || filterOptions(item, values ?? {})) : all),
        [all, filterOptions, values, f.value],
    );
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
