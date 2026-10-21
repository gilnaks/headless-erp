import type { ReportColumn, ReportRow } from "@/components/erp/report/report-view";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type StockAnalyticsResult = {
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

/** Stock movement for each period, rolled up by warehouse, item, item group, or brand. */
export async function loadStockAnalytics(filters: {
    company: string;
    from: string;
    to: string;
    tree: string;
    value: string;
    range: string;
    item: string;
    itemGroup: string;
    warehouse: string;
    brand: string;
}): Promise<StockAnalyticsResult> {
    const payload: Json = {
        company: filters.company,
        from_date: filters.from,
        to_date: filters.to,
        tree_type: filters.tree,
        value_quantity: filters.value,
        range: filters.range,
        ...(filters.item ? { item: filters.item } : {}),
        ...(filters.itemGroup ? { item_group: filters.itemGroup } : {}),
        ...(filters.warehouse ? { warehouse: filters.warehouse } : {}),
        ...(filters.brand ? { brand: filters.brand } : {}),
    };
    const supabase = createClient();
    const { data, error } = await supabase.rpc("report_stock_analytics", { p_filters: payload });
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
