import type { ReportColumn, ReportRow } from "@/components/erp/report/report-view";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type StockAgeingResult = {
    columns: ReportColumn[];
    rows: ReportRow[];
    error?: string;
};

function columnOf(value: unknown): ReportColumn | undefined {
    if (!value || typeof value !== "object") return undefined;
    const column = value as { field?: unknown; label?: unknown; amount?: unknown };
    if (typeof column.field !== "string" || typeof column.label !== "string") return undefined;
    return column.amount === true
        ? { field: column.field, label: column.label, amount: true }
        : { field: column.field, label: column.label };
}

function isRow(value: unknown): value is ReportRow {
    return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

/** Remaining qty by the age of each inward slot, as of one date. */
export async function loadStockAgeing(filters: {
    company: string;
    to: string;
    item: string;
    warehouse: string;
}): Promise<StockAgeingResult> {
    const payload: Json = {
        company: filters.company,
        to_date: filters.to,
        ...(filters.item ? { item: filters.item } : {}),
        ...(filters.warehouse ? { warehouse: filters.warehouse } : {}),
    };
    const supabase = createClient();
    const { data, error } = await supabase.rpc("report_stock_ageing", { p_filters: payload });
    if (error) return { columns: [], rows: [], error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    const columns = Array.isArray(body.columns)
        ? body.columns.flatMap((column) => {
              const parsed = columnOf(column);
              return parsed ? [parsed] : [];
          })
        : [];
    const rows: ReportRow[] = Array.isArray(body.rows) ? body.rows.flatMap((row) => (isRow(row) ? [row as ReportRow] : [])) : [];
    return { columns, rows };
}
