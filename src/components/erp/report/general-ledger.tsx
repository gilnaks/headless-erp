"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { type ReportColumn, type ReportRow, ReportView } from "@/components/erp/report/report-view";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import { generalLedgerParsers } from "@/lib/report-params";

type GeneralLedgerProps = {
    orgSlug: string;
    companyId: string;
    from: string;
    to: string;
    accountId: string;
    showOpening: boolean;
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

/** Default General Ledger filters. Changing one rewrites the URL and the page reloads the report. */
export function GeneralLedger({ orgSlug, companyId, from, to, accountId, showOpening, columns, rows, error }: GeneralLedgerProps) {
    const [, setParams] = useQueryStates(generalLedgerParsers, { shallow: false });

    return (
        <ReportView
            title="General Ledger"
            columns={columns}
            rows={rows}
            error={error}
            exportName="general-ledger.csv"
            filters={
                <div className="flex flex-wrap items-end gap-3">
                    <ReportLink
                        label="Company"
                        orgSlug={orgSlug}
                        doctype="Company"
                        value={companyId}
                        onChange={(id) => void setParams({ company: id || null, account: null })}
                    />
                    <Input
                        label="From Date"
                        size="sm"
                        type="date"
                        value={from}
                        onChange={(value) => void setParams({ from: value || null })}
                    />
                    <Input label="To Date" size="sm" type="date" value={to} onChange={(value) => void setParams({ to: value || null })} />
                    <ReportLink
                        label="Account"
                        orgSlug={orgSlug}
                        doctype="Account"
                        value={accountId}
                        onChange={(id) => void setParams({ account: id || null })}
                    />
                    <Checkbox
                        label="Show Opening Entries"
                        isSelected={showOpening}
                        onChange={(selected) => void setParams({ opening: selected })}
                    />
                </div>
            }
        />
    );
}
