"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { type ReportColumn, type ReportRow, ReportView } from "@/components/erp/report/report-view";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import { stockAnalyticsParsers } from "@/lib/report-params";

const TREES = [
    { id: "Warehouse", label: "Warehouse" },
    { id: "Item", label: "Item" },
    { id: "Item Group", label: "Item Group" },
    { id: "Brand", label: "Brand" },
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

type StockAnalyticsProps = {
    orgSlug: string;
    companyId: string;
    from: string;
    to: string;
    tree: string;
    value: string;
    range: string;
    itemId: string;
    itemGroupId: string;
    warehouseId: string;
    brandId: string;
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

/** Stock Analytics filters. Changing one rewrites the URL and the page reloads the report. */
export function StockAnalytics({
    orgSlug,
    companyId,
    from,
    to,
    tree,
    value,
    range,
    itemId,
    itemGroupId,
    warehouseId,
    brandId,
    columns,
    rows,
    error,
}: StockAnalyticsProps) {
    const [, setParams] = useQueryStates(stockAnalyticsParsers, { shallow: false });

    return (
        <ReportView
            title="Stock Analytics"
            columns={columns}
            rows={rows}
            error={error}
            exportName="stock-analytics.csv"
            filters={
                <div className="flex flex-wrap items-end gap-3">
                    <ReportLink
                        label="Company"
                        orgSlug={orgSlug}
                        doctype="Company"
                        value={companyId}
                        onChange={(id) => void setParams({ company: id || null, warehouse: null })}
                    />
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
                        selectedKey={TREES.some((item) => item.id === tree) ? tree : "Item"}
                        onSelectionChange={(key: Key | null) => void setParams({ tree: key == null ? "Item" : String(key) })}
                        className="min-w-40"
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
                    <ReportLink
                        label="Item"
                        orgSlug={orgSlug}
                        doctype="Item"
                        value={itemId}
                        onChange={(id) => void setParams({ item: id || null })}
                    />
                    <ReportLink
                        label="Item Group"
                        orgSlug={orgSlug}
                        doctype="Item Group"
                        value={itemGroupId}
                        onChange={(id) => void setParams({ item_group: id || null })}
                    />
                    <ReportLink
                        label="Warehouse"
                        orgSlug={orgSlug}
                        doctype="Warehouse"
                        value={warehouseId}
                        onChange={(id) => void setParams({ warehouse: id || null })}
                    />
                    <ReportLink
                        label="Brand"
                        orgSlug={orgSlug}
                        doctype="Brand"
                        value={brandId}
                        onChange={(id) => void setParams({ brand: id || null })}
                    />
                </div>
            }
        />
    );
}
