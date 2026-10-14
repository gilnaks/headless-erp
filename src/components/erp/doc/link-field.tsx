"use client";

import { useEffect, useRef, useState } from "react";
import type { Key } from "react-aria-components";
import { type Control, type FieldValues, useController } from "react-hook-form";
import { Select } from "@/components/base/select/select";
import type { FieldDef } from "@/doctypes/define";
import { type LinkOption, searchLink } from "@/lib/actions/doc";

type LinkFieldProps = {
    control: Control<FieldValues>;
    name: string;
    field: FieldDef;
    orgSlug: string;
    isDisabled?: boolean;
    /** Grid cell: no visible label or hint. */
    compact?: boolean;
};

const DEBOUNCE_MS = 250;

/** ERPNext Link: an async combobox over the target doctype's title field; the stored value is the record id. */
export function LinkField({ control, name, field, orgSlug, isDisabled, compact }: LinkFieldProps) {
    const { field: f, fieldState } = useController({ control, name });
    const value = typeof f.value === "string" ? f.value : "";
    const target = field.target ?? "";
    const [items, setItems] = useState<LinkOption[]>([]);
    const [loaded, setLoaded] = useState(false);
    const request = useRef(0);
    const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

    const load = (q: string) => {
        const seq = ++request.current;
        void searchLink({ orgSlug, doctype: target, q, ids: value ? [value] : [] }).then((options) => {
            if (seq !== request.current) return;
            setItems(options);
            setLoaded(true);
        });
    };

    // React Aria opens the menu on focus/typing only if options already exist, so form fields preload; grid cells
    // load on focus to avoid one request per row. A stored id always needs its label.
    // biome-ignore lint/correctness/useExhaustiveDependencies: only when the stored value changes
    useEffect(() => {
        if (!compact || (value && !items.some((i) => i.id === value))) load("");
    }, [value]);

    useEffect(
        () => () => {
            if (timer.current) clearTimeout(timer.current);
        },
        [],
    );

    const onInputChange = (q: string) => {
        if (timer.current) clearTimeout(timer.current);
        timer.current = setTimeout(() => load(q), DEBOUNCE_MS);
    };

    return (
        <Select.ComboBox
            label={compact ? undefined : field.label}
            aria-label={compact ? field.label : undefined}
            items={items}
            size="sm"
            shortcut={false}
            placeholder={field.placeholder ?? (compact ? "" : `Select ${target}`)}
            isRequired={field.required}
            isDisabled={isDisabled}
            isInvalid={Boolean(fieldState.error)}
            hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
            selectedKey={value || null}
            onSelectionChange={(key: Key | null) => f.onChange(key == null ? "" : String(key))}
            onInputChange={onInputChange}
            onFocus={() => {
                if (!loaded) load("");
            }}
            onBlur={f.onBlur}
            name={f.name}
        >
            {(item) => <Select.Item id={item.id} label={item.label} />}
        </Select.ComboBox>
    );
}
