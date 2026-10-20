import type { ReportColumn, ReportRow } from "@/components/erp/report/report-view";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type CashFlowSummary = { label: string; value: number };
export type CashFlowChart = {
    type: "bar";
    labels: string[];
    datasets: { name: string; values: number[] }[];
};

export type CashFlowResult = {
    columns: ReportColumn[];
    rows: ReportRow[];
    summary: CashFlowSummary[];
    chart: CashFlowChart;
    error?: string;
};

const EMPTY_CHART: CashFlowChart = { type: "bar", labels: [], datasets: [] };

function isColumn(value: unknown): value is ReportColumn {
    if (!value || typeof value !== "object") return false;
    const column = value as { field?: unknown; label?: unknown; amount?: unknown };
    return (
        typeof column.field === "string" &&
        typeof column.label === "string" &&
        (column.amount === undefined || typeof column.amount === "boolean")
    );
}

function isRow(value: unknown): value is ReportRow {
    return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isSummary(value: unknown): value is CashFlowSummary {
    if (!value || typeof value !== "object") return false;
    const item = value as { label?: unknown; value?: unknown };
    return typeof item.label === "string" && typeof item.value === "number";
}

function chartOf(value: unknown): CashFlowChart {
    if (!value || typeof value !== "object" || Array.isArray(value)) return EMPTY_CHART;
    const chart = value as { labels?: unknown; datasets?: unknown };
    const labels = Array.isArray(chart.labels) ? chart.labels.filter((label): label is string => typeof label === "string") : [];
    const datasets = Array.isArray(chart.datasets)
        ? chart.datasets.flatMap((dataset) => {
              if (!dataset || typeof dataset !== "object") return [];
              const row = dataset as { name?: unknown; values?: unknown };
              if (typeof row.name !== "string" || !Array.isArray(row.values)) return [];
              return [{ name: row.name, values: row.values.flatMap((amount) => (typeof amount === "number" ? [amount] : [])) }];
          })
        : [];
    return { type: "bar", labels, datasets };
}

/** Default indirect Cash Flow statement for one company and period list. */
export async function loadCashFlow(filters: {
    company: string;
    basis: string;
    fromFiscalYear: string;
    toFiscalYear: string;
    from: string;
    to: string;
    periodicity: string;
    accumulated: boolean;
    opening: boolean;
}): Promise<CashFlowResult> {
    const payload: Json = {
        company: filters.company,
        filter_based_on: filters.basis,
        periodicity: filters.periodicity,
        accumulated_values: filters.accumulated,
        show_opening_and_closing_balance: filters.opening,
        ...(filters.basis === "Date Range"
            ? { period_start_date: filters.from, period_end_date: filters.to }
            : { from_fiscal_year: filters.fromFiscalYear, to_fiscal_year: filters.toFiscalYear }),
    };
    const supabase = createClient();
    const { data, error } = await supabase.rpc("report_cash_flow", { p_filters: payload });
    if (error) return { columns: [], rows: [], summary: [], chart: EMPTY_CHART, error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    const columns = Array.isArray(body.columns) ? body.columns.filter(isColumn) : [];
    const rows: ReportRow[] = Array.isArray(body.rows) ? body.rows.flatMap((row) => (isRow(row) ? [row as ReportRow] : [])) : [];
    const summary = Array.isArray(body.summary) ? body.summary.filter(isSummary) : [];
    return { columns, rows, summary, chart: chartOf(body.chart) };
}
