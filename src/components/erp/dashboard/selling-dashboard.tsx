"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { type ReactNode, useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Select } from "@/components/base/select/select";
import { DashboardChart } from "@/components/erp/dashboard/chart";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import type { DashboardCard, DashboardSeries } from "@/lib/queries/accounts-dashboard";
import type { SellingDashboardData } from "@/lib/queries/selling-dashboard";
import { dashboardParsers } from "@/lib/report-params";

type SellingDashboardProps = SellingDashboardData & {
    orgSlug: string;
    companyId: string;
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

function formatValue(value: number, money: boolean): string {
    return value.toLocaleString(undefined, money ? { minimumFractionDigits: 2, maximumFractionDigits: 2 } : { maximumFractionDigits: 0 });
}

function NumberCard({ title, card, money }: { title: string; card: DashboardCard; money?: boolean }) {
    return (
        <section aria-label={title} className="flex flex-col gap-2 rounded-xl bg-primary p-5 ring-1 ring-secondary">
            <h2 className="text-sm font-medium text-tertiary">{title}</h2>
            {card.available && card.value !== undefined ? (
                <p className="text-display-xs font-semibold text-primary tabular-nums">{formatValue(card.value, Boolean(money))}</p>
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

function SeriesChart({ series, empty }: { series: DashboardSeries; empty: string }) {
    if (series.error) return <Unavailable message={series.error} />;
    if (!series.available || series.chart.labels.length === 0) return <Unavailable message={empty} />;
    return <DashboardChart chart={series.chart} />;
}

/** Selling dashboard: four cards, then trends, customers, analysis, and item sales. */
export function SellingDashboard({
    orgSlug,
    companyId,
    annualSales,
    toDeliver,
    toBill,
    customers,
    trends,
    topCustomers,
    analysis,
    itemSales,
    error,
}: SellingDashboardProps) {
    const [, setParams] = useQueryStates(dashboardParsers, { shallow: false });

    return (
        <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-4 border-b border-secondary pb-5">
                <h1 className="text-display-xs font-semibold text-primary">Dashboard</h1>
                <CompanyField orgSlug={orgSlug} value={companyId} onChange={(id) => void setParams({ company: id || null })} />
                {error && <p className="text-sm text-error-primary">{error}</p>}
            </div>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
                <NumberCard title="Annual Sales" card={annualSales} money />
                <NumberCard title="Sales Orders to Deliver" card={toDeliver} />
                <NumberCard title="Sales Orders to Bill" card={toBill} />
                <NumberCard title="Active Customers" card={customers} />
            </div>
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
                <ChartCard title="Sales Order Trends" wide>
                    <SeriesChart series={trends} empty="Sales Analytics is not built yet" />
                </ChartCard>
                <ChartCard title="Top Customers">
                    <SeriesChart series={topCustomers} empty="Sales Analytics is not built yet" />
                </ChartCard>
                <ChartCard title="Sales Order Analysis">
                    <SeriesChart series={analysis} empty="No open sales orders" />
                </ChartCard>
                <ChartCard title="Item-wise Annual Sales" wide>
                    <SeriesChart series={itemSales} empty="Sales Invoice is not built yet" />
                </ChartCard>
            </div>
        </div>
    );
}
