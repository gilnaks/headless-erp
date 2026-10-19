import type { ReportColumn, ReportRow } from "@/components/erp/report/report-view";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type TrialBalanceForPartyResult = {
    columns: ReportColumn[];
    rows: ReportRow[];
    warnings: string[];
    error?: string;
};

function isColumn(value: unknown): value is ReportColumn {
    if (!value || typeof value !== "object") return false;
    const column = value as { field?: unknown; label?: unknown };
    return typeof column.field === "string" && typeof column.label === "string";
}

function isRow(value: unknown): value is ReportRow {
    return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

/** Default Trial Balance for Party: one row per Customer or Supplier. */
export async function loadTrialBalanceForParty(filters: {
    company: string;
    fiscalYear: string;
    from: string;
    to: string;
    partyType: string;
    party: string;
    showZero: boolean;
    excludeZero: boolean;
}): Promise<TrialBalanceForPartyResult> {
    const payload: Json = {
        company: filters.company,
        fiscal_year: filters.fiscalYear,
        from_date: filters.from,
        to_date: filters.to,
        party_type: filters.partyType,
        ...(filters.party ? { party: [filters.party] } : {}),
        show_zero_values: filters.showZero,
        exclude_zero_balance_parties: filters.excludeZero,
    };
    const supabase = createClient();
    const { data, error } = await supabase.rpc("report_trial_balance_for_party", { p_filters: payload });
    if (error) return { columns: [], rows: [], warnings: [], error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    const columns = Array.isArray(body.columns) ? body.columns.filter(isColumn) : [];
    const rows: ReportRow[] = Array.isArray(body.rows) ? body.rows.flatMap((row) => (isRow(row) ? [row as ReportRow] : [])) : [];
    const warnings = Array.isArray(body.warnings) ? body.warnings.filter((warning): warning is string => typeof warning === "string") : [];
    return { columns, rows, warnings };
}
