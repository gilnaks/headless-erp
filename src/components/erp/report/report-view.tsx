"use client";

import type { ReactNode } from "react";
import { Table } from "@/components/application/table/table";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { cx } from "@/utils/cx";

export type ReportColumn = { field: string; label: string; amount?: boolean };
export type ReportRow = Record<string, unknown> & { row_type?: string };

const AMOUNTS = new Set(["debit", "credit", "balance", "opening_debit", "opening_credit", "closing_debit", "closing_credit"]);

function formatAmount(value: unknown): string {
    if (value === null || value === undefined || value === "") return "";
    const amount = Number(value);
    return Number.isFinite(amount)
        ? amount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
        : String(value);
}

function isAmountColumn(column: ReportColumn): boolean {
    return column.amount === true || AMOUNTS.has(column.field);
}

function formatCell(column: ReportColumn, value: unknown): string {
    if (isAmountColumn(column)) return formatAmount(value);
    if (value === null || value === undefined) return "";
    return String(value);
}

function csvEscape(value: unknown): string {
    const text = value === null || value === undefined ? "" : String(value);
    return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function downloadCsv(filename: string, columns: ReportColumn[], rows: ReportRow[]) {
    const header = columns.map((column) => csvEscape(column.label)).join(",");
    const body = rows.map((row) => columns.map((column) => csvEscape(formatCell(column, row[column.field]))).join(",")).join("\n");
    const blob = new Blob([`${header}\n${body}`], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
}

type ReportViewProps = {
    title: string;
    columns: ReportColumn[];
    rows: ReportRow[];
    error?: string;
    filters: ReactNode;
    exportName?: string;
};

/** Shared report table: filters, summary rows, an empty period, and a CSV download. */
export function ReportView({ title, columns, rows, error, filters, exportName = "report.csv" }: ReportViewProps) {
    const hasActivity = rows.some((row) => row.row_type === "entry" || row.row_type === "account" || row.row_type === "party");
    const headerColumns = columns.map((column) => ({ ...column, id: column.field }));
    const tableRows: (ReportRow & { id: string })[] = rows.map((row, index) => ({
        ...row,
        id: `${row.row_type ?? "row"}-${index}`,
    }));

    return (
        <div className="flex flex-col gap-4">
            <header className="flex flex-wrap items-center gap-3">
                <h1 className="flex-1 text-lg font-semibold text-primary">{title}</h1>
                <Button
                    size="sm"
                    color="secondary"
                    isDisabled={Boolean(error) || columns.length === 0}
                    onPress={() => downloadCsv(exportName, columns, rows)}
                >
                    Export CSV
                </Button>
            </header>
            {filters}
            {error && <FormAlert>{error}</FormAlert>}
            {!error && !hasActivity && <FormAlert tone="info">No entries in this period.</FormAlert>}
            {!error && columns.length > 0 && (
                <div className="overflow-hidden rounded-xl ring-1 ring-secondary">
                    <Table aria-label={title} size="sm">
                        <Table.Header columns={headerColumns}>
                            {(column) => (
                                <Table.Head
                                    id={column.field}
                                    label={column.label}
                                    isRowHeader={
                                        column.field === "account" ||
                                        column.field === "party" ||
                                        column.field === "section" ||
                                        column.field === "entity"
                                    }
                                    className={cx(isAmountColumn(column) && "[&>div]:justify-end")}
                                />
                            )}
                        </Table.Header>
                        <Table.Body items={tableRows}>
                            {(row) => (
                                <Table.Row id={row.id} columns={headerColumns}>
                                    {(column) => (
                                        <Table.Cell
                                            className={cx(
                                                isAmountColumn(column) && "text-right tabular-nums",
                                                ((row.row_type !== "entry" && row.row_type !== "account" && row.row_type !== "party") ||
                                                    row.is_group === true) &&
                                                    "font-semibold text-primary",
                                                isAmountColumn(column) &&
                                                    row.warn_if_negative === true &&
                                                    Number(row[column.field]) < 0 &&
                                                    "text-error-primary",
                                            )}
                                        >
                                            {(column.field === "account" || column.field === "section" || column.field === "entity") &&
                                            typeof row.indent === "number" &&
                                            row.indent > 0 ? (
                                                <span style={{ paddingInlineStart: row.indent * 16 }}>
                                                    {formatCell(column, row[column.field])}
                                                </span>
                                            ) : (
                                                formatCell(column, row[column.field])
                                            )}
                                        </Table.Cell>
                                    )}
                                </Table.Row>
                            )}
                        </Table.Body>
                    </Table>
                </div>
            )}
        </div>
    );
}
