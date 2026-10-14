"use client";

import { ArrowDown, ArrowUp, Plus, Trash01 } from "@untitledui/icons";
import { type KeyboardEvent, useState } from "react";
import { type Control, type FieldValues, useFieldArray, useFormState } from "react-hook-form";
import { Button } from "@/components/base/buttons/button";
import { ButtonUtility } from "@/components/base/buttons/button-utility";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { HintText } from "@/components/base/input/hint-text";
import type { ChildDoctype, FieldDef } from "@/doctypes/define";
import { gridColumns, gridKeyTarget, moveTarget, removalOrder } from "@/doctypes/grid";
import { newChildRow } from "@/doctypes/schema";
import { cx } from "@/utils/cx";
import { FieldRenderer } from "./field-renderer";

type ChildTableProps = {
    control: Control<FieldValues>;
    name: string;
    field: FieldDef;
    child: ChildDoctype;
    orgSlug: string;
    isDisabled?: boolean;
};

/**
 * ERPNext grid (Table field): one row per child record, cells are compact field editors. ArrowUp/ArrowDown move
 * between rows; ArrowDown/Enter on the last row appends one.
 */
export function ChildTable({ control, name, field, child, orgSlug, isDisabled }: ChildTableProps) {
    const { fields: rows, append, remove, move } = useFieldArray({ control, name, keyName: "_key" });
    const { errors } = useFormState({ control, name });
    const [selected, setSelected] = useState<Set<number>>(new Set());
    const columns = gridColumns(child);
    const tableError = (errors[name] as { message?: string } | undefined)?.message;

    const focusCell = (row: number, column: string) => {
        requestAnimationFrame(() => {
            const el = document.querySelector<HTMLElement>(
                `[data-grid="${name}"][data-row="${row}"][data-col="${column}"] input, [data-grid="${name}"][data-row="${row}"][data-col="${column}"] textarea, [data-grid="${name}"][data-row="${row}"][data-col="${column}"] button`,
            );
            el?.focus();
        });
    };

    const addRow = (focusColumn?: string) => {
        append(newChildRow(child));
        if (focusColumn) focusCell(rows.length, focusColumn);
    };

    const onCellKeyDown = (event: KeyboardEvent, row: number, column: string) => {
        if (event.defaultPrevented || event.altKey || event.metaKey || event.ctrlKey || event.shiftKey) return;
        if ((event.target as HTMLElement).getAttribute("aria-expanded") === "true") return;
        if ((event.target as HTMLElement).tagName === "TEXTAREA" && event.key === "Enter") return;
        const target = gridKeyTarget(row, event.key, rows.length);
        if (!target) return;
        event.preventDefault();
        if ("add" in target) {
            if (!isDisabled) addRow(column);
        } else {
            focusCell(target.row, column);
        }
    };

    const removeSelected = () => {
        remove(removalOrder(selected, rows.length));
        setSelected(new Set());
    };

    const moveRow = (index: number, direction: "up" | "down") => {
        const target = moveTarget(index, direction, rows.length);
        if (target === null) return;
        move(index, target);
        setSelected(new Set());
    };

    const toggle = (index: number, on: boolean) => {
        setSelected((prev) => {
            const next = new Set(prev);
            if (on) next.add(index);
            else next.delete(index);
            return next;
        });
    };

    const allSelected = rows.length > 0 && selected.size === rows.length;

    return (
        <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-secondary">
                    {field.label}
                    {field.required && <span className="text-brand-tertiary"> *</span>}
                </span>
                {selected.size > 0 && !isDisabled && (
                    <Button size="sm" color="secondary-destructive" iconLeading={Trash01} onPress={removeSelected}>
                        Delete {selected.size === 1 ? "row" : `${selected.size} rows`}
                    </Button>
                )}
            </div>
            <div className={cx("overflow-x-auto rounded-lg ring-1 ring-secondary", tableError && "ring-error_subtle")}>
                <table className="w-full text-sm">
                    <thead className="bg-secondary text-xs font-semibold text-tertiary">
                        <tr>
                            <th className="w-9 px-3 py-2">
                                <Checkbox
                                    aria-label="Select all rows"
                                    isSelected={allSelected}
                                    isIndeterminate={selected.size > 0 && !allSelected}
                                    isDisabled={isDisabled || rows.length === 0}
                                    onChange={(on) => setSelected(on ? new Set(rows.map((_, i) => i)) : new Set())}
                                />
                            </th>
                            <th className="w-10 px-2 py-2 text-left">No.</th>
                            {columns.map((c) => (
                                <th key={c.name} className={cx("min-w-32 px-2 py-2", c.numeric ? "text-right" : "text-left")}>
                                    {c.field.label}
                                    {c.field.required && <span className="text-brand-tertiary"> *</span>}
                                </th>
                            ))}
                            <th className="w-20 px-2 py-2">
                                <span className="sr-only">Row actions</span>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        {rows.length === 0 && (
                            <tr>
                                <td colSpan={columns.length + 3} className="px-3 py-6 text-center text-tertiary">
                                    No rows
                                </td>
                            </tr>
                        )}
                        {rows.map((row, index) => (
                            <tr key={row._key} className="border-t border-secondary">
                                <td className="px-3 py-1.5 align-middle">
                                    <Checkbox
                                        aria-label={`Select row ${index + 1}`}
                                        isSelected={selected.has(index)}
                                        isDisabled={isDisabled}
                                        onChange={(on) => toggle(index, on)}
                                    />
                                </td>
                                <td className="px-2 py-1.5 text-tertiary tabular-nums">{index + 1}</td>
                                {columns.map((c) => (
                                    <td
                                        key={c.name}
                                        className="px-1 py-1"
                                        data-grid={name}
                                        data-row={index}
                                        data-col={c.name}
                                        onKeyDown={(e) => onCellKeyDown(e, index, c.name)}
                                    >
                                        <FieldRenderer
                                            control={control}
                                            name={`${name}.${index}.${c.name}`}
                                            field={c.field}
                                            orgSlug={orgSlug}
                                            isDisabled={isDisabled || c.field.readOnly}
                                            compact
                                        />
                                    </td>
                                ))}
                                <td className="px-1 py-1">
                                    <div className="flex justify-end">
                                        <ButtonUtility
                                            size="xs"
                                            color="tertiary"
                                            icon={ArrowUp}
                                            tooltip="Move up"
                                            isDisabled={isDisabled || index === 0}
                                            onPress={() => moveRow(index, "up")}
                                        />
                                        <ButtonUtility
                                            size="xs"
                                            color="tertiary"
                                            icon={ArrowDown}
                                            tooltip="Move down"
                                            isDisabled={isDisabled || index === rows.length - 1}
                                            onPress={() => moveRow(index, "down")}
                                        />
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
            {tableError && <HintText isInvalid>{tableError}</HintText>}
            {!isDisabled && (
                <div>
                    <Button size="sm" color="secondary" iconLeading={Plus} onPress={() => addRow(columns[0]?.name)}>
                        Add row
                    </Button>
                </div>
            )}
        </div>
    );
}
