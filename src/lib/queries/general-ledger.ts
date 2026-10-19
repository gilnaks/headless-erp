import type { ReportColumn, ReportRow } from "@/components/erp/report/report-view";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type GeneralLedgerResult = {
    columns: ReportColumn[];
    rows: ReportRow[];
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

/** Consolidated General Ledger for one company and date range. */
export async function loadGeneralLedger(filters: {
    company: string;
    from: string;
    to: string;
    account: string;
    showOpening: boolean;
}): Promise<GeneralLedgerResult> {
    const payload: Json = {
        company: filters.company,
        from_date: filters.from,
        to_date: filters.to,
        show_opening_entries: filters.showOpening,
        ...(filters.account ? { account: [filters.account] } : {}),
    };
    const supabase = createClient();
    const { data, error } = await supabase.rpc("report_general_ledger", { p_filters: payload });
    if (error) return { columns: [], rows: [], error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    const columns = Array.isArray(body.columns) ? body.columns.filter(isColumn) : [];
    const rows: ReportRow[] = Array.isArray(body.rows) ? body.rows.flatMap((row) => (isRow(row) ? [row as ReportRow] : [])) : [];
    return { columns, rows };
}
