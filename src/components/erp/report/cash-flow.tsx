"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Bar, BarChart, CartesianGrid, Tooltip, XAxis, YAxis } from "recharts";
import { ChartTooltipContent } from "@/components/application/charts/charts-base";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { type ReportColumn, type ReportRow, ReportView } from "@/components/erp/report/report-view";
import type { FiscalYearChoice } from "@/components/erp/report/trial-balance";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import type { CashFlowChart, CashFlowSummary } from "@/lib/queries/cash-flow";
import { cashFlowParsers } from "@/lib/report-params";

type CashFlowProps = {
    orgSlug: string;
    companyId: string;
    basis: string;
    fromFiscalYearId: string;
    toFiscalYearId: string;
    years: FiscalYearChoice[];
    from: string;
    to: string;
    periodicity: string;
    accumulated: boolean;
    opening: boolean;
    columns: ReportColumn[];
    rows: ReportRow[];
    summary: CashFlowSummary[];
    chart: CashFlowChart;
    error?: string;
};

const BASES = [
    { id: "Fiscal Year", label: "Fiscal Year" },
    { id: "Date Range", label: "Date Range" },
];

const PERIODS = [
    { id: "Monthly", label: "Monthly" },
    { id: "Quarterly", label: "Quarterly" },
    { id: "Half-Yearly", label: "Half-Yearly" },
    { id: "Yearly", label: "Yearly" },
];

const SERIES: Record<string, string> = {
    "Net Cash from Operations": "var(--color-utility-brand-600)",
    "Net Cash from Investing": "var(--color-fg-error-secondary)",
    "Net Cash from Financing": "var(--color-utility-green-600)",
};

function useDebounced(value: string): string {
    const [debounced, setDebounced] = useState(value);
    useEffect(() => {
        const timer = setTimeout(() => setDebounced(value), 250);
        return () => clearTimeout(timer);
    }, [value]);
    return debounced;
}

function ReportLink({
    label,
    orgSlug,
    doctype,
    value,
    onChange,
}: {
    label: string;
    orgSlug: string;
    doctype: string;
    value: string;
    onChange: (id: string) => void;
}) {
    const [query, setQuery] = useState("");
    const [opened, setOpened] = useState(false);
    const debounced = useDebounced(query);
    const result = useQuery({
        queryKey: ["link", orgSlug, doctype, debounced, value],
        queryFn: ({ signal }) => searchLink({ orgSlug, doctype, q: debounced, ids: value ? [value] : [], signal }),
        enabled: opened || Boolean(value),
        staleTime: 30_000,
    });
    const items: LinkOption[] = result.data ?? [];

    return (
        <Select.ComboBox
            label={label}
            items={items}
            size="sm"
            shortcut={false}
            allowsEmptyCollection
            placeholder={`Select ${doctype}`}
            selectedKey={value || null}
            onSelectionChange={(key: Key | null) => onChange(key == null ? "" : String(key))}
            onInputChange={setQuery}
            onFocus={() => setOpened(true)}
            className="min-w-56"
        >
            {(item) => <Select.Item id={item.id} label={item.label} />}
        </Select.ComboBox>
    );
}

function money(value: number): string {
    return value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function StatementChart({ chart }: { chart: CashFlowChart }) {
    const data = chart.labels.map((label, index) => {
        const point: Record<string, string | number> = { label };
        for (const dataset of chart.datasets) point[dataset.name] = dataset.values[index] ?? 0;
        return point;
    });

    return (
        <div className="flex flex-col gap-3">
            <ul className="flex flex-wrap gap-3">
                {chart.datasets.map((dataset) => (
                    <li key={dataset.name} className="flex items-center gap-2 text-sm text-tertiary">
                        <span
                            className="size-2 rounded-full"
                            style={{ background: SERIES[dataset.name] ?? "var(--color-utility-brand-600)" }}
                        />
                        {dataset.name}
                    </li>
                ))}
            </ul>
            <div className="h-60 w-full">
                <BarChart responsive data={data}>
                    <CartesianGrid vertical={false} stroke="var(--color-border-secondary)" />
                    <XAxis dataKey="label" tick={{ fill: "var(--color-text-tertiary)", fontSize: 12 }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fill: "var(--color-text-tertiary)", fontSize: 12 }} axisLine={false} tickLine={false} width={56} />
                    <Tooltip content={<ChartTooltipContent />} />
                    {chart.datasets.map((dataset) => (
                        <Bar
                            key={dataset.name}
                            dataKey={dataset.name}
                            fill={SERIES[dataset.name] ?? "var(--color-utility-brand-600)"}
                            radius={4}
                        />
                    ))}
                </BarChart>
            </div>
        </div>
    );
}

/** Default indirect Cash Flow statement. Accumulated values stay on unless the URL turns them off. */
export function CashFlow({
    orgSlug,
    companyId,
    basis,
    fromFiscalYearId,
    toFiscalYearId,
    years,
    from,
    to,
    periodicity,
    accumulated,
    opening,
    columns,
    rows,
    summary,
    chart,
    error,
}: CashFlowProps) {
    const [, setParams] = useQueryStates(cashFlowParsers, { shallow: false });
    const byYear = basis !== "Date Range";

    return (
        <ReportView
            title="Cash Flow"
            columns={columns}
            rows={rows}
            error={error}
            exportName="cash-flow.csv"
            filters={
                <div className="flex flex-col gap-4">
                    <div className="flex flex-wrap items-end gap-3">
                        <ReportLink
                            label="Company"
                            orgSlug={orgSlug}
                            doctype="Company"
                            value={companyId}
                            onChange={(id) => void setParams({ company: id || null })}
                        />
                        <Select
                            label="Filter Based On"
                            size="sm"
                            items={BASES}
                            selectedKey={byYear ? "Fiscal Year" : "Date Range"}
                            onSelectionChange={(key: Key | null) => void setParams({ basis: key == null ? "Fiscal Year" : String(key) })}
                            className="min-w-40"
                        >
                            {(item) => <Select.Item id={item.id} label={item.label} />}
                        </Select>
                        {byYear ? (
                            <>
                                <Select
                                    label="From Fiscal Year"
                                    size="sm"
                                    items={years}
                                    selectedKey={fromFiscalYearId || null}
                                    onSelectionChange={(key: Key | null) => void setParams({ from_fy: key == null ? null : String(key) })}
                                    className="min-w-40"
                                >
                                    {(item) => <Select.Item id={item.id} label={item.label} />}
                                </Select>
                                <Select
                                    label="To Fiscal Year"
                                    size="sm"
                                    items={years}
                                    selectedKey={toFiscalYearId || null}
                                    onSelectionChange={(key: Key | null) => void setParams({ to_fy: key == null ? null : String(key) })}
                                    className="min-w-40"
                                >
                                    {(item) => <Select.Item id={item.id} label={item.label} />}
                                </Select>
                            </>
                        ) : (
                            <>
                                <Input
                                    label="From Date"
                                    size="sm"
                                    type="date"
                                    value={from}
                                    onChange={(value) => void setParams({ from: value || null })}
                                />
                                <Input
                                    label="To Date"
                                    size="sm"
                                    type="date"
                                    value={to}
                                    onChange={(value) => void setParams({ to: value || null })}
                                />
                            </>
                        )}
                        <Select
                            label="Periodicity"
                            size="sm"
                            items={PERIODS}
                            selectedKey={PERIODS.some((item) => item.id === periodicity) ? periodicity : "Yearly"}
                            onSelectionChange={(key: Key | null) => void setParams({ periodicity: key == null ? "Yearly" : String(key) })}
                            className="min-w-40"
                        >
                            {(item) => <Select.Item id={item.id} label={item.label} />}
                        </Select>
                        <Checkbox
                            label="Accumulated Values"
                            isSelected={accumulated}
                            onChange={(selected) => void setParams({ accumulated: selected })}
                        />
                        <Checkbox
                            label="Show Opening and Closing Balance"
                            isSelected={opening}
                            onChange={(selected) => void setParams({ opening: selected })}
                        />
                    </div>
                    {!error && summary.length > 0 && (
                        <div className="grid gap-3 sm:grid-cols-4">
                            {summary.map((item) => (
                                <div key={item.label} className="rounded-xl bg-secondary px-4 py-3">
                                    <p className="text-sm text-tertiary">{item.label}</p>
                                    <p className="text-lg font-semibold text-primary tabular-nums">{money(item.value)}</p>
                                </div>
                            ))}
                        </div>
                    )}
                    {!error && chart.labels.length > 0 && chart.datasets.length > 0 && <StatementChart chart={chart} />}
                </div>
            }
        />
    );
}
