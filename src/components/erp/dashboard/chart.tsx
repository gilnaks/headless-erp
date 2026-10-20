"use client";

import { Bar, BarChart, CartesianGrid, Line, LineChart, Tooltip, XAxis, YAxis } from "recharts";
import { ChartTooltipContent } from "@/components/application/charts/charts-base";
import type { ProfitAndLossChart } from "@/lib/queries/profit-and-loss";

const SERIES: Record<string, string> = {
    Income: "var(--color-utility-brand-600)",
    Expense: "var(--color-fg-error-secondary)",
    "Net Profit/Loss": "var(--color-utility-green-600)",
    "Bank Balance": "var(--color-utility-brand-600)",
};

const FALLBACK = "var(--color-utility-brand-600)";

function colorOf(name: string): string {
    return SERIES[name] ?? FALLBACK;
}

/** Bar or line chart used by the Accounts dashboard and the Home Profit and Loss block. */
export function DashboardChart({ chart }: { chart: ProfitAndLossChart }) {
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

    return (
        <div className="flex flex-col gap-3">
            <ul className="flex flex-wrap gap-3">
                {chart.datasets.map((dataset) => (
                    <li key={dataset.name} className="flex items-center gap-2 text-sm text-tertiary">
                        <span className="size-2 rounded-full" style={{ background: colorOf(dataset.name) }} />
                        {dataset.name}
                    </li>
                ))}
            </ul>
            <div className="h-60 w-full">
                {chart.type === "line" ? (
                    <LineChart responsive className="h-full w-full" style={{ width: "100%", height: "100%" }} data={data}>
                        {axes}
                        {chart.datasets.map((dataset) => (
                            <Line
                                key={dataset.name}
                                type="monotone"
                                dataKey={dataset.name}
                                stroke={colorOf(dataset.name)}
                                strokeWidth={2}
                                dot={false}
                            />
                        ))}
                    </LineChart>
                ) : (
                    <BarChart responsive className="h-full w-full" style={{ width: "100%", height: "100%" }} data={data}>
                        {axes}
                        {chart.datasets.map((dataset) => (
                            <Bar key={dataset.name} dataKey={dataset.name} fill={colorOf(dataset.name)} radius={4} />
                        ))}
                    </BarChart>
                )}
            </div>
        </div>
    );
}
