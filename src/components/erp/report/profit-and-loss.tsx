"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Bar, BarChart, CartesianGrid, Line, LineChart, Tooltip, XAxis, YAxis } from "recharts";
import { ChartTooltipContent } from "@/components/application/charts/charts-base";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { type ReportColumn, type ReportRow, ReportView } from "@/components/erp/report/report-view";
import type { FiscalYearChoice } from "@/components/erp/report/trial-balance";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import type { ProfitAndLossChart, ProfitAndLossSummary } from "@/lib/queries/profit-and-loss";
import { profitAndLossParsers } from "@/lib/report-params";

type ProfitAndLossProps = {
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
    showZero: boolean;
    columns: ReportColumn[];
    rows: ReportRow[];
    summary: ProfitAndLossSummary[];
    chart: ProfitAndLossChart;
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

const SERIES = {
    Income: "var(--color-utility-brand-600)",
    Expense: "var(--color-fg-error-secondary)",
    "Net Profit/Loss": "var(--color-utility-green-600)",
} as const;

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

function StatementChart({ chart }: { chart: ProfitAndLossChart }) {
    const data = chart.labels.map((label, index) => {
        const point: Record<string, string | number> = { label };
        for (const dataset of chart.datasets) point[dataset.name] = dataset.values[index] ?? 0;
        return point;
    });
    const axes = (
        <>
            <CartesianGrid vertical={false} stroke="var(--color-border-secondary)" />
            <XAxis dataKey="label" tick={{ fill: "var(--color-text-tertiary)", fontSize: 12 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: "var(--color-text-tertiary)", fontSize: 12 }} axisLine={false} tickLine={false} width={56} />
            <Tooltip content={<ChartTooltipContent />} />
        </>
    );
    const series =
        chart.type === "line"
            ? chart.datasets.map((dataset) => (
                  <Line
                      key={dataset.name}
                      type="monotone"
                      dataKey={dataset.name}
                      stroke={SERIES[dataset.name as keyof typeof SERIES]}
                      strokeWidth={2}
                      dot={false}
                  />
              ))
            : chart.datasets.map((dataset) => (
                  <Bar key={dataset.name} dataKey={dataset.name} fill={SERIES[dataset.name as keyof typeof SERIES]} radius={4} />
              ));

    return (
        <div className="flex flex-col gap-3">
            <ul className="flex flex-wrap gap-3">
                {chart.datasets.map((dataset) => (
                    <li key={dataset.name} className="flex items-center gap-2 text-sm text-tertiary">
                        <span className="size-2 rounded-full" style={{ background: SERIES[dataset.name as keyof typeof SERIES] }} />
                        {dataset.name}
                    </li>
                ))}
            </ul>
            <div className="h-60 w-full">
                {chart.type === "line" ? (
                    <LineChart responsive data={data}>
                        {axes}
                        {series}
                    </LineChart>
                ) : (
                    <BarChart responsive data={data}>
                        {axes}
                        {series}
                    </BarChart>
                )}
            </div>
        </div>
    );
}

/** Default Profit and Loss. Fiscal year mode and date range mode use different bounds. */
export function ProfitAndLoss({
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
    showZero,
    columns,
    rows,
    summary,
    chart,
    error,
}: ProfitAndLossProps) {
    const [, setParams] = useQueryStates(profitAndLossParsers, { shallow: false });
    const byYear = basis !== "Date Range";

    return (
        <ReportView
            title="Profit and Loss Statement"
            columns={columns}
            rows={rows}
            error={error}
            exportName="profit-and-loss.csv"
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
                            label="Show Zero Values"
                            isSelected={showZero}
                            onChange={(selected) => void setParams({ zero: selected })}
                        />
                    </div>
                    {!error && summary.length > 0 && (
                        <div className="grid gap-3 sm:grid-cols-3">
                            {summary.map((item) => (
                                <div key={item.label} className="rounded-xl bg-secondary px-4 py-3">
                                    <p className="text-sm text-tertiary">{item.label}</p>
                                    <p
                                        className={
                                            item.value < 0 && item.label.toLowerCase().includes("profit")
                                                ? "text-lg font-semibold text-error-primary tabular-nums"
                                                : "text-lg font-semibold text-primary tabular-nums"
                                        }
                                    >
                                        {money(item.value)}
                                    </p>
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
