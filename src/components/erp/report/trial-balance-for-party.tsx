"use client";

import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";
import { useEffect, useState } from "react";
import type { Key } from "react-aria-components";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { FormAlert } from "@/components/erp/form-alert";
import { type ReportColumn, type ReportRow, ReportView } from "@/components/erp/report/report-view";
import type { FiscalYearChoice } from "@/components/erp/report/trial-balance";
import { type LinkOption, searchLink } from "@/lib/actions/doc";
import { trialBalanceForPartyParsers } from "@/lib/report-params";

type TrialBalanceForPartyProps = {
    orgSlug: string;
    companyId: string;
    fiscalYearId: string;
    years: FiscalYearChoice[];
    from: string;
    to: string;
    partyType: string;
    partyId: string;
    showZero: boolean;
    excludeZero: boolean;
    columns: ReportColumn[];
    rows: ReportRow[];
    warnings: string[];
    error?: string;
};

const PARTY_TYPES = [
    { id: "Customer", label: "Customer" },
    { id: "Supplier", label: "Supplier" },
];

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

/** Default Trial Balance for Party. Changing the party type clears the selected party. */
export function TrialBalanceForParty({
    orgSlug,
    companyId,
    fiscalYearId,
    years,
    from,
    to,
    partyType,
    partyId,
    showZero,
    excludeZero,
    columns,
    rows,
    warnings,
    error,
}: TrialBalanceForPartyProps) {
    const [, setParams] = useQueryStates(trialBalanceForPartyParsers, { shallow: false });
    const partyDoctype = partyType === "Supplier" ? "Supplier" : "Customer";

    return (
        <ReportView
            title="Trial Balance for Party"
            columns={columns}
            rows={rows}
            error={error}
            exportName="trial-balance-for-party.csv"
            filters={
                <div className="flex flex-col gap-3">
                    <div className="flex flex-wrap items-end gap-3">
                        <ReportLink
                            label="Company"
                            orgSlug={orgSlug}
                            doctype="Company"
                            value={companyId}
                            onChange={(id) => void setParams({ company: id || null })}
                        />
                        <Select
                            label="Fiscal Year"
                            size="sm"
                            placeholder="Select Fiscal Year"
                            items={years}
                            selectedKey={fiscalYearId || null}
                            onSelectionChange={(key: Key | null) => {
                                const id = key == null ? "" : String(key);
                                const year = years.find((item) => item.id === id);
                                void setParams({
                                    fiscal_year: id || null,
                                    from: year?.start ?? null,
                                    to: year?.end ?? null,
                                });
                            }}
                            className="min-w-40"
                        >
                            {(item) => <Select.Item id={item.id} label={item.label} />}
                        </Select>
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
                        <Select
                            label="Party Type"
                            size="sm"
                            items={PARTY_TYPES}
                            selectedKey={partyDoctype}
                            onSelectionChange={(key: Key | null) => {
                                const next = key == null ? "Customer" : String(key);
                                void setParams({ party_type: next, party: null });
                            }}
                            className="min-w-40"
                        >
                            {(item) => <Select.Item id={item.id} label={item.label} />}
                        </Select>
                        <ReportLink
                            key={partyDoctype}
                            label="Party"
                            orgSlug={orgSlug}
                            doctype={partyDoctype}
                            value={partyId}
                            onChange={(id) => void setParams({ party: id || null })}
                        />
                        <Checkbox
                            label="Show Zero Values"
                            isSelected={showZero}
                            onChange={(selected) => void setParams({ zero: selected })}
                        />
                        <Checkbox
                            label="Exclude Zero Balance Parties"
                            isSelected={excludeZero}
                            onChange={(selected) => void setParams({ exclude: selected })}
                        />
                    </div>
                    {warnings.map((warning) => (
                        <FormAlert key={warning} tone="info">
                            {warning}
                        </FormAlert>
                    ))}
                </div>
            }
        />
    );
}
