"use client";

import { useQuery } from "@tanstack/react-query";
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
    /** DynamicLink: target doctype read from the sibling field (overrides `field.target`). */
    target?: string;
};

const DEBOUNCE_MS = 250;

function useDebounced(value: string, ms: number): string {
    const [debounced, setDebounced] = useState(value);
    useEffect(() => {
        const timer = setTimeout(() => setDebounced(value), ms);
        return () => clearTimeout(timer);
    }, [value, ms]);
    return debounced;
}

/** ERPNext Link: an async combobox over the target doctype's title field; the stored value is the record id. */
export function LinkField({ control, name, field, orgSlug, isDisabled, compact, target: dynamicTarget }: LinkFieldProps) {
    const { field: f, fieldState } = useController({ control, name });
    const value = typeof f.value === "string" ? f.value : "";
    const target = dynamicTarget ?? field.target ?? "";
    const [query, setQuery] = useState("");
    const [opened, setOpened] = useState(!compact);
    const debounced = useDebounced(query, DEBOUNCE_MS);
    const shownTarget = useRef(target);

    // A record id of the previous doctype means nothing for the new one.
    // biome-ignore lint/correctness/useExhaustiveDependencies: only when the target doctype changes
    useEffect(() => {
        if (target === shownTarget.current) return;
        shownTarget.current = target;
        setQuery("");
        setOpened(!compact);
        f.onChange("");
    }, [target]);

    const result = useQuery({
        queryKey: ["link", orgSlug, target, debounced, value],
        queryFn: ({ signal }) => searchLink({ orgSlug, doctype: target, q: debounced, ids: value ? [value] : [], signal }),
        enabled: Boolean(target) && (opened || Boolean(value)),
        staleTime: 30_000,
        placeholderData: (previous, previousQuery) => (previousQuery?.queryKey[2] === target ? previous : undefined),
    });
    const items: LinkOption[] = result.data ?? [];

    return (
        <Select.ComboBox
            label={compact ? undefined : field.label}
            aria-label={compact ? field.label : undefined}
            items={items}
            size="sm"
            shortcut={false}
            // Results arrive after typing starts; without this the menu stays closed when the first keystroke found no options.
            allowsEmptyCollection
            placeholder={field.placeholder ?? (compact ? "" : target ? `Select ${target}` : `Select ${field.label}`)}
            isRequired={field.required}
            isDisabled={isDisabled || !target}
            isInvalid={Boolean(fieldState.error)}
            hint={compact ? undefined : (fieldState.error?.message ?? field.description)}
            selectedKey={value || null}
            onSelectionChange={(key: Key | null) => f.onChange(key == null ? "" : String(key))}
            onInputChange={setQuery}
            onFocus={() => setOpened(true)}
            onBlur={f.onBlur}
            name={f.name}
        >
            {(item) => <Select.Item id={item.id} label={item.label} />}
        </Select.ComboBox>
    );
}
