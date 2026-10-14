"use client";

import { type CellData, createColumnHelper, type Header, type Row, tableFeatures, useTable } from "@tanstack/react-table";
import { ChevronLeft, ChevronRight, Plus, SearchLg } from "@untitledui/icons";
import { useQueryStates } from "nuqs";
import { useEffect, useMemo, useState, useTransition } from "react";
import type { SortDescriptor } from "react-aria-components";
import { Table } from "@/components/application/table/table";
import { Button } from "@/components/base/buttons/button";
import { ButtonUtility } from "@/components/base/buttons/button-utility";
import { Input } from "@/components/base/input/input";
import { NativeSelect } from "@/components/base/select/select-native";
import { type Doctype, docPath, type FieldDef, type FieldValues } from "@/doctypes/define";
import { getDoctypeByName } from "@/doctypes/registry";
import { listParsers, PAGE_SIZES } from "@/lib/list-params";
import { cx } from "@/utils/cx";

export type DocListProps = {
    doctype: string;
    orgSlug: string;
    rows: FieldValues[];
    count: number;
    page: number;
    pageSize: number;
    sort: string;
    desc: boolean;
    canCreate: boolean;
};

const SEARCH_DEBOUNCE_MS = 300;
const features = tableFeatures({});
const columnHelper = createColumnHelper<typeof features, FieldValues>();

type RowItem = Row<typeof features, FieldValues>;
type CellItem = ReturnType<RowItem["getAllCells"]>[number];
type HeaderItem = Header<typeof features, FieldValues, unknown>;
const NUMERIC = new Set(["Int", "Float", "Currency", "Percent"]);

function formatCell(field: FieldDef | undefined, value: unknown): string {
    if (value === null || value === undefined || value === "") return "";
    if (field?.type === "Check") return value ? "Yes" : "No";
    if (field && NUMERIC.has(field.type)) {
        const n = Number(value);
        return Number.isFinite(n) ? n.toLocaleString(undefined, { maximumFractionDigits: field.type === "Int" ? 0 : 2 }) : String(value);
    }
    return String(value);
}

/**
 * Generic ERPNext list view: search, sortable columns, pagination and "+ New". Data is fetched on the server;
 * this component only edits the URL (`nuqs`, non-shallow) so the page re-renders with the new query.
 */
export function DocList({ doctype, orgSlug, rows, count, page, pageSize, sort, desc, canCreate }: DocListProps) {
    const d = getDoctypeByName(doctype) as Doctype;
    const [pending, startTransition] = useTransition();
    const [params, setParams] = useQueryStates(listParsers, { shallow: false, startTransition });
    const [search, setSearch] = useState(params.q);
    const baseHref = `/${orgSlug}/${docPath(d)}`;

    useEffect(() => {
        if (search === params.q) return;
        const timer = setTimeout(() => void setParams({ q: search || null, page: null }), SEARCH_DEBOUNCE_MS);
        return () => clearTimeout(timer);
    }, [search, params.q, setParams]);

    const columns = useMemo(
        () =>
            columnHelper.columns(
                d.listView.columns.map((name) =>
                    columnHelper.accessor((row) => row[name] as CellData, { id: name, header: d.fields[name]?.label ?? name }),
                ),
            ),
        [d],
    );

    // Sorting and paging happen in SQL (URL state), so the table only needs the core row model.
    const table = useTable({ features, columns, data: rows, getRowId: (row) => String(row.id) });
    const headers = table.getHeaderGroups()[0]?.headers ?? [];

    const sortDescriptor: SortDescriptor = { column: sort, direction: desc ? "descending" : "ascending" };
    const onSortChange = (next: SortDescriptor) =>
        void setParams({ sort: String(next.column), desc: next.direction === "descending", page: null });

    const pageCount = Math.max(1, Math.ceil(count / pageSize));
    const from = count === 0 ? 0 : (page - 1) * pageSize + 1;
    const to = Math.min(count, page * pageSize);

    return (
        <div className="flex flex-col gap-4">
            <header className="flex flex-wrap items-center gap-3">
                <h1 className="flex-1 text-lg font-semibold text-primary">{d.doctype}</h1>
                {canCreate && (
                    <Button size="sm" iconLeading={Plus} href={`${baseHref}/new`}>
                        New {d.doctype}
                    </Button>
                )}
            </header>

            <div className="flex flex-wrap items-center gap-3">
                <Input
                    aria-label={`Search ${d.doctype}`}
                    size="sm"
                    icon={SearchLg}
                    placeholder={`Search ${d.listView.searchFields.map((f) => d.fields[f]?.label ?? f).join(", ")}`}
                    value={search}
                    onChange={setSearch}
                    className="max-w-xs"
                />
            </div>

            <div className={cx("overflow-hidden rounded-xl ring-1 ring-secondary transition-opacity", pending && "opacity-60")}>
                <Table aria-label={d.doctype} size="sm" sortDescriptor={sortDescriptor} onSortChange={onSortChange}>
                    <Table.Header columns={headers}>
                        {(header: HeaderItem) => {
                            const field = d.fields[header.id];
                            return (
                                <Table.Head
                                    id={header.id}
                                    label={field?.label ?? header.id}
                                    allowsSorting
                                    isRowHeader={header.id === d.titleField}
                                    className={cx("px-4", field && NUMERIC.has(field.type) && "[&>div]:justify-end")}
                                />
                            );
                        }}
                    </Table.Header>
                    <Table.Body
                        items={table.getRowModel().rows as RowItem[]}
                        renderEmptyState={() => (
                            <div className="flex flex-col items-center gap-3 px-4 py-12 text-center">
                                <p className="text-sm font-semibold text-primary">
                                    {params.q ? `No ${d.doctype} matches "${params.q}"` : `No ${d.doctype} yet`}
                                </p>
                                {params.q ? (
                                    <Button size="sm" color="secondary" onPress={() => setSearch("")}>
                                        Clear search
                                    </Button>
                                ) : (
                                    canCreate && (
                                        <Button size="sm" iconLeading={Plus} href={`${baseHref}/new`}>
                                            New {d.doctype}
                                        </Button>
                                    )
                                )}
                            </div>
                        )}
                    >
                        {(row: RowItem) => (
                            <Table.Row
                                id={row.id}
                                columns={row.getAllCells()}
                                href={`${baseHref}/${row.id}`}
                                className="h-10 cursor-pointer"
                            >
                                {(cell: CellItem) => {
                                    const field = d.fields[cell.column.id];
                                    const numeric = field && NUMERIC.has(field.type);
                                    return (
                                        <Table.Cell
                                            id={cell.id}
                                            className={cx(
                                                "px-4 py-2",
                                                cell.column.id === d.titleField && "font-medium text-primary",
                                                numeric && "text-right tabular-nums",
                                            )}
                                        >
                                            {formatCell(field, cell.getValue())}
                                        </Table.Cell>
                                    );
                                }}
                            </Table.Row>
                        )}
                    </Table.Body>
                </Table>
            </div>

            <footer className="flex flex-wrap items-center justify-between gap-3 text-sm text-tertiary">
                <div className="flex items-center gap-2">
                    <NativeSelect
                        aria-label="Rows per page"
                        size="sm"
                        className="w-max"
                        value={String(pageSize)}
                        onChange={(e) => void setParams({ size: Number(e.target.value), page: null })}
                        options={PAGE_SIZES.map((n) => ({ value: String(n), label: `${n} per page` }))}
                    />
                </div>
                <div className="flex items-center gap-2">
                    <span className="tabular-nums">
                        {from}–{to} of {count}
                    </span>
                    <ButtonUtility
                        size="sm"
                        color="tertiary"
                        icon={ChevronLeft}
                        tooltip="Previous page"
                        isDisabled={page <= 1}
                        onPress={() => void setParams({ page: page - 1 > 1 ? page - 1 : null })}
                    />
                    <ButtonUtility
                        size="sm"
                        color="tertiary"
                        icon={ChevronRight}
                        tooltip="Next page"
                        isDisabled={page >= pageCount}
                        onPress={() => void setParams({ page: page + 1 })}
                    />
                </div>
            </footer>
        </div>
    );
}
