"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { type ReactNode, useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { DashboardChart } from "@/components/erp/dashboard/chart";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import type { DashboardCard, DashboardSeries } from "@/lib/queries/accounts-dashboard";
import type { ProfitAndLossChart } from "@/lib/queries/profit-and-loss";
import { dashboardParsers } from "@/lib/report-params";

type AccountsDashboardProps = {
    orgSlug: string;
    companyId: string;
    from: string;
    to: string;
    outgoingBills: DashboardCard;
    incomingBills: DashboardCard;
    incomingPayment: DashboardCard;
    outgoingPayment: DashboardCard;
    profit: ProfitAndLossChart;
    profitError?: string;
    outgoingBillChart: DashboardSeries;
    incomingBillChart: DashboardSeries;
    bank: DashboardSeries;
    error?: string;
};

function useDebounced(value: string): string {
    const [debounced, setDebounced] = useState(value);
    useEffect(() => {
        const timer = setTimeout(() => setDebounced(value), 250);
        return () => clearTimeout(timer);
    }, [value]);
    return debounced;
}

function CompanyField({ orgSlug, value, onChange }: { orgSlug: string; value: string; onChange: (id: string) => void }) {
    const [query, setQuery] = useState("");
    const [opened, setOpened] = useState(false);
    const debounced = useDebounced(query);
    const result = useQuery({
        queryKey: ["link", orgSlug, "Company", debounced, value],
        queryFn: ({ signal }) => searchLink({ orgSlug, doctype: "Company", q: debounced, ids: value ? [value] : [], signal }),
        enabled: opened || Boolean(value),
        staleTime: 30_000,
    });
    const items: LinkOption[] = result.data ?? [];

    return (
        <Select.ComboBox
            label="Company"
            items={items}
            size="sm"
            shortcut={false}
            allowsEmptyCollection
            placeholder="Select Company"
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

function NumberCard({ title, card }: { title: string; card: DashboardCard }) {
    return (
        <section aria-label={title} className="flex flex-col gap-2 rounded-xl bg-primary p-5 ring-1 ring-secondary">
            <h2 className="text-sm font-medium text-tertiary">{title}</h2>
            {card.available && card.value !== undefined ? (
                <>
                    <p className="text-display-xs font-semibold text-primary tabular-nums">{money(card.value)}</p>
                    {card.percent !== undefined && (
                        <p
                            className={
                                card.percent < 0 ? "text-sm text-error-primary tabular-nums" : "text-sm text-success-primary tabular-nums"
                            }
                        >
                            {money(card.percent)}% from last month
                        </p>
                    )}
                </>
            ) : (
                <p className="text-sm text-tertiary">{card.error ?? "Not available yet"}</p>
            )}
        </section>
    );
}

function ChartCard({ title, wide, children }: { title: string; wide?: boolean; children: ReactNode }) {
    return (
        <section
            aria-label={title}
            className={`flex flex-col gap-4 rounded-xl bg-primary p-5 ring-1 ring-secondary ${wide ? "lg:col-span-2" : ""}`}
        >
            <h2 className="text-md font-semibold text-primary">{title}</h2>
            {children}
        </section>
    );
}

function Unavailable({ message }: { message?: string }) {
    return <p className="py-8 text-center text-sm text-tertiary">{message ?? "Not available yet"}</p>;
}

function SeriesChart({ series, empty }: { series: DashboardSeries; empty?: string }) {
    if (series.error) return <Unavailable message={series.error} />;
    if (!series.available || series.chart.labels.length === 0) return <Unavailable message={empty} />;
    return <DashboardChart chart={series.chart} />;
}

/** Accounts dashboard: four cards, then the Profit and Loss, bills, ageing, budget, and bank charts. */
export function AccountsDashboard({
    orgSlug,
    companyId,
    from,
    to,
    outgoingBills,
    incomingBills,
    incomingPayment,
    outgoingPayment,
    profit,
    profitError,
    outgoingBillChart,
    incomingBillChart,
    bank,
    error,
}: AccountsDashboardProps) {
    const [, setParams] = useQueryStates(dashboardParsers, { shallow: false });

    return (
        <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-4 border-b border-secondary pb-5">
                <h1 className="text-display-xs font-semibold text-primary">Dashboard</h1>
                <div className="flex flex-wrap items-end gap-3">
                    <CompanyField orgSlug={orgSlug} value={companyId} onChange={(id) => void setParams({ company: id || null })} />
                    <Input
                        label="From Date"
                        size="sm"
                        type="date"
                        value={from}
                        onChange={(value) => void setParams({ from: value || null })}
                    />
                    <Input label="To Date" size="sm" type="date" value={to} onChange={(value) => void setParams({ to: value || null })} />
                </div>
                {error && <p className="text-sm text-error-primary">{error}</p>}
            </div>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
                <NumberCard title="Total Outgoing Bills" card={outgoingBills} />
                <NumberCard title="Total Incoming Bills" card={incomingBills} />
                <NumberCard title="Total Incoming Payment" card={incomingPayment} />
                <NumberCard title="Total Outgoing Payment" card={outgoingPayment} />
            </div>
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
                <ChartCard title="Profit and Loss" wide>
                    {profitError || profit.labels.length === 0 ? <Unavailable message={profitError} /> : <DashboardChart chart={profit} />}
                </ChartCard>
                <ChartCard title="Outgoing Bills">
                    <SeriesChart series={outgoingBillChart} />
                </ChartCard>
                <ChartCard title="Incoming Bills">
                    <SeriesChart series={incomingBillChart} />
                </ChartCard>
                <ChartCard title="Accounts Receivable Ageing">
                    <Unavailable />
                </ChartCard>
                <ChartCard title="Accounts Payable Ageing">
                    <Unavailable />
                </ChartCard>
                <ChartCard title="Budget Variance" wide>
                    <Unavailable />
                </ChartCard>
                <ChartCard title="Bank Balance" wide>
                    <SeriesChart series={bank} />
                </ChartCard>
            </div>
        </div>
    );
}
