import type { ReportColumn, ReportRow } from "@/components/erp/report/report-view";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type SalesRegisterResult = {
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

/** Submitted sales invoices and their item rows for a date range. */
export async function loadSalesRegister(filters: {
    company: string;
    from: string;
    to: string;
    customer: string;
    customerGroup: string;
    territory: string;
    item: string;
}): Promise<SalesRegisterResult> {
    const payload: { [key: string]: Json | undefined } = {
        company: filters.company,
        from_date: filters.from,
        to_date: filters.to,
    };
    if (filters.customer) payload.customer = filters.customer;
    if (filters.customerGroup) payload.customer_group = filters.customerGroup;
    if (filters.territory) payload.territory = filters.territory;
    if (filters.item) payload.item = filters.item;
    const supabase = createClient();
    const { data, error } = await supabase.rpc("report_sales_register", { p_filters: payload });
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
