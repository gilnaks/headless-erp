import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { type ReportColumn, type ReportRow, ReportView } from "@/components/erp/report/report-view";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import { salesRegisterParsers } from "@/lib/report-params";

type SalesRegisterProps = {
    orgSlug: string;
    companyId: string;
    from: string;
    to: string;
    customerId: string;
    customerGroupId: string;
    territoryId: string;
    itemId: string;
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

/** Sales Register filters. Changing one rewrites the URL and the page reloads the report. */
export function SalesRegister({
    orgSlug,
    companyId,
    from,
    to,
    customerId,
    customerGroupId,
    territoryId,
    itemId,
    columns,
    rows,
    error,
}: SalesRegisterProps) {
    const [, setParams] = useQueryStates(salesRegisterParsers, { shallow: false });

    return (
        <ReportView
            title="Sales Register"
            columns={columns}
            rows={rows}
            error={error}
            exportName="sales-register.csv"
            filters={
                <div className="flex flex-wrap items-end gap-3">
                    <ReportLink
                        label="Company"
                        orgSlug={orgSlug}
                        doctype="Company"
                        value={companyId}
                        onChange={(id) => void setParams({ company: id || null })}
                    />
                    <Input
                        label="From Date"
                        size="sm"
                        type="date"
                        value={from}
                        onChange={(next) => void setParams({ from: next || null })}
                    />
                    <Input label="To Date" size="sm" type="date" value={to} onChange={(next) => void setParams({ to: next || null })} />
                    <ReportLink
                        label="Customer"
                        orgSlug={orgSlug}
                        doctype="Customer"
                        value={customerId}
                        onChange={(id) => void setParams({ customer: id || null })}
                    />
                    <ReportLink
                        label="Customer Group"
                        orgSlug={orgSlug}
                        doctype="Customer Group"
                        value={customerGroupId}
                        onChange={(id) => void setParams({ customer_group: id || null })}
                    />
                    <ReportLink
                        label="Territory"
                        orgSlug={orgSlug}
                        doctype="Territory"
                        value={territoryId}
                        onChange={(id) => void setParams({ territory: id || null })}
                    />
                    <ReportLink
                        label="Item"
                        orgSlug={orgSlug}
                        doctype="Item"
                        value={itemId}
                        onChange={(id) => void setParams({ item: id || null })}
                    />
                </div>
            }
        />
    );
}
