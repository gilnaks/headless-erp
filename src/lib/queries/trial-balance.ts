import type { ReportColumn, ReportRow } from "@/components/erp/report/report-view";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type TrialBalanceResult = {
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

/** Default Trial Balance for one company and fiscal year. */
export async function loadTrialBalance(filters: {
    company: string;
    fiscalYear: string;
    from: string;
    to: string;
    showZero: boolean;
    showGroups: boolean;
    showNet: boolean;
}): Promise<TrialBalanceResult> {
    const payload: Json = {
        company: filters.company,
        fiscal_year: filters.fiscalYear,
        from_date: filters.from,
        to_date: filters.to,
        show_zero_values: filters.showZero,
        show_group_accounts: filters.showGroups,
        show_net_values: filters.showNet,
    };
    const supabase = createClient();
    const { data, error } = await supabase.rpc("report_trial_balance", { p_filters: payload });
    if (error) return { columns: [], rows: [], warnings: [], error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    const columns = Array.isArray(body.columns) ? body.columns.filter(isColumn) : [];
    const rows: ReportRow[] = Array.isArray(body.rows) ? body.rows.flatMap((row) => (isRow(row) ? [row as ReportRow] : [])) : [];
    const warnings = Array.isArray(body.warnings) ? body.warnings.filter((warning): warning is string => typeof warning === "string") : [];
    return { columns, rows, warnings };
}
