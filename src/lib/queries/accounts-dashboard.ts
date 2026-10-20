import { dbError } from "@/lib/errors";
import type { ProfitAndLossChart } from "@/lib/queries/profit-and-loss";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type DashboardCard = {
    available: boolean;
    value?: number;
    current?: number;
    previous?: number;
    percent?: number;
    error?: string;
};

export type DashboardSeries = {
    available: boolean;
    chart: ProfitAndLossChart;
    error?: string;
};

const EMPTY_CHART: ProfitAndLossChart = { type: "bar", labels: [], datasets: [] };

function amount(value: unknown): number | undefined {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) return Number(value);
    return undefined;
}

function chartOf(value: unknown, fallback: "bar" | "line"): ProfitAndLossChart {
    if (!value || typeof value !== "object" || Array.isArray(value)) return { ...EMPTY_CHART, type: fallback };
    const chart = value as { type?: unknown; labels?: unknown; datasets?: unknown };
    const type = chart.type === "line" ? "line" : "bar";
    const labels = Array.isArray(chart.labels) ? chart.labels.filter((label): label is string => typeof label === "string") : [];
    const datasets = Array.isArray(chart.datasets)
        ? chart.datasets.flatMap((dataset) => {
              if (!dataset || typeof dataset !== "object") return [];
              const row = dataset as { name?: unknown; values?: unknown };
              if (typeof row.name !== "string" || !Array.isArray(row.values)) return [];
              const values = row.values.flatMap((entry) => {
                  const parsed = amount(entry);
                  return parsed === undefined ? [] : [parsed];
              });
              return [{ name: row.name, values }];
          })
        : [];
    return { type, labels, datasets };
}

function cardOf(data: Json | null, error: { message: string } | null): DashboardCard {
    if (error) return { available: false, error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    if (body.available !== true) return { available: false };
    const percent = amount(body.percent);
    return {
        available: true,
        value: amount(body.value) ?? 0,
        current: amount(body.current),
        previous: amount(body.previous),
        ...(percent === undefined ? {} : { percent }),
    };
}

function seriesOf(data: Json | null, error: { message: string } | null, fallback: "bar" | "line"): DashboardSeries {
    if (error) return { available: false, chart: { ...EMPTY_CHART, type: fallback }, error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    if (body.available !== true) return { available: false, chart: { ...EMPTY_CHART, type: fallback } };
    return { available: true, chart: chartOf(body.chart, fallback) };
}

/** Submitted payment totals, or not available for doctypes that are not built yet. */
export async function loadCardSum(doctype: string, field: string, filters: Json): Promise<DashboardCard> {
    const supabase = createClient();
    const { data, error } = await supabase.rpc("card_sum", { p_doctype: doctype, p_field: field, p_filters: filters });
    return cardOf(data, error);
}

/** Monthly bill series. Invoice doctypes return not available until those tables exist. */
export async function loadChartTimeseries(doctype: string, field: string, filters: Json): Promise<DashboardSeries> {
    const supabase = createClient();
    const { data, error } = await supabase.rpc("chart_timeseries", {
        p_doctype: doctype,
        p_field: field,
        p_date_field: "posting_date",
        p_interval: "monthly",
        p_points: 12,
        p_filters: filters,
    });
    return seriesOf(data, error, "bar");
}

/** Twelve month-end balances for the company bank account, or not available when it is unset. */
export async function loadBankBalance(filters: Json): Promise<DashboardSeries> {
    const supabase = createClient();
    const { data, error } = await supabase.rpc("chart_account_balance_timeline", { p_filters: filters });
    return seriesOf(data, error, "line");
}
