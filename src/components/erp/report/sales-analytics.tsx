"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { type ReportColumn, type ReportRow, ReportView } from "@/components/erp/report/report-view";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import { salesAnalyticsParsers } from "@/lib/report-params";

const TREES = [
    { id: "Customer Group", label: "Customer Group" },
    { id: "Customer", label: "Customer" },
    { id: "Item Group", label: "Item Group" },
    { id: "Item", label: "Item" },
    { id: "Territory", label: "Territory" },
    { id: "Order Type", label: "Order Type" },
];

const DOCS = [
    { id: "All", label: "All" },
    { id: "Quotation", label: "Quotation" },
    { id: "Sales Order", label: "Sales Order" },
    { id: "Delivery Note", label: "Delivery Note" },
    { id: "Payment Entry", label: "Payment Entry" },
];

const VALUES = [
    { id: "Value", label: "Value" },
    { id: "Quantity", label: "Quantity" },
];

const RANGES = [
    { id: "Weekly", label: "Weekly" },
    { id: "Monthly", label: "Monthly" },
    { id: "Quarterly", label: "Quarterly" },
    { id: "Yearly", label: "Yearly" },
];

type SalesAnalyticsProps = {
    orgSlug: string;
    companyId: string;
    from: string;
    to: string;
    tree: string;
    doc: string;
    value: string;
    range: string;
    columns: ReportColumn[];
    rows: ReportRow[];
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

/** Sales Analytics filters. Changing one rewrites the URL and the page reloads the report. */
export function SalesAnalytics({ orgSlug, companyId, from, to, tree, doc, value, range, columns, rows, error }: SalesAnalyticsProps) {
    const [, setParams] = useQueryStates(salesAnalyticsParsers, { shallow: false });

    return (
        <ReportView
            title="Sales Analytics"
            columns={columns}
            rows={rows}
            error={error}
            exportName="sales-analytics.csv"
            filters={
                <div className="flex flex-wrap items-end gap-3">
                    <CompanyField orgSlug={orgSlug} value={companyId} onChange={(id) => void setParams({ company: id || null })} />
                    <Input
                        label="From Date"
                        size="sm"
                        type="date"
                        value={from}
                        onChange={(next) => void setParams({ from: next || null })}
                    />
                    <Input label="To Date" size="sm" type="date" value={to} onChange={(next) => void setParams({ to: next || null })} />
                    <Select
                        label="Tree Type"
                        size="sm"
                        items={TREES}
                        selectedKey={TREES.some((item) => item.id === tree) ? tree : "Customer"}
                        onSelectionChange={(key: Key | null) => void setParams({ tree: key == null ? "Customer" : String(key) })}
                        className="min-w-44"
                    >
                        {(item) => <Select.Item id={item.id} label={item.label} />}
                    </Select>
                    <Select
                        label="Based On"
                        size="sm"
                        items={DOCS}
                        selectedKey={DOCS.some((item) => item.id === doc) ? doc : "Sales Order"}
                        onSelectionChange={(key: Key | null) => void setParams({ doc: key == null ? "Sales Order" : String(key) })}
                        className="min-w-44"
                    >
                        {(item) => <Select.Item id={item.id} label={item.label} />}
                    </Select>
                    <Select
                        label="Value or Qty"
                        size="sm"
                        items={VALUES}
                        selectedKey={VALUES.some((item) => item.id === value) ? value : "Value"}
                        onSelectionChange={(key: Key | null) => void setParams({ value: key == null ? "Value" : String(key) })}
                        className="min-w-40"
                    >
                        {(item) => <Select.Item id={item.id} label={item.label} />}
                    </Select>
                    <Select
                        label="Range"
                        size="sm"
                        items={RANGES}
                        selectedKey={RANGES.some((item) => item.id === range) ? range : "Monthly"}
                        onSelectionChange={(key: Key | null) => void setParams({ range: key == null ? "Monthly" : String(key) })}
                        className="min-w-40"
                    >
                        {(item) => <Select.Item id={item.id} label={item.label} />}
                    </Select>
                </div>
            }
        />
    );
}
