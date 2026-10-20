import { dbError } from "@/lib/errors";
import type { DashboardCard, DashboardSeries } from "@/lib/queries/accounts-dashboard";
import type { ProfitAndLossChart } from "@/lib/queries/profit-and-loss";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

const EMPTY_CHART: ProfitAndLossChart = { type: "bar", labels: [], datasets: [] };

export type StockDashboardData = {
    items: DashboardCard;
    warehouses: DashboardCard;
    stockValue: DashboardCard;
    warehouseChart: DashboardSeries;
    receipts: DashboardSeries;
    deliveries: DashboardSeries;
    oldest: DashboardSeries;
    shortage: DashboardSeries;
};

function amount(value: unknown): number | undefined {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) return Number(value);
    return undefined;
}

function chartOf(value: unknown): ProfitAndLossChart {
    if (!value || typeof value !== "object" || Array.isArray(value)) return { ...EMPTY_CHART };
    const chart = value as { type?: unknown; labels?: unknown; datasets?: unknown };
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
    return { type: "bar", labels, datasets };
}

function seriesOf(data: Json | null, error: { message: string } | null): DashboardSeries {
    if (error) return { available: false, chart: { ...EMPTY_CHART }, error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    if (body.available !== true) return { available: false, chart: { ...EMPTY_CHART } };
    return { available: true, chart: chartOf(body.chart) };
}

function cardsOf(data: Json | null, error: { message: string } | null): Pick<StockDashboardData, "items" | "warehouses" | "stockValue"> {
    if (error) {
        const card = { available: false, error: dbError(error).message };
        return { items: card, warehouses: card, stockValue: card };
    }
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    if (body.available !== true) {
        const card = { available: false };
        return { items: card, warehouses: card, stockValue: card };
    }
    return {
        items: { available: true, value: amount(body.active_items) ?? 0 },
        warehouses: { available: true, value: amount(body.warehouses) ?? 0 },
        stockValue: { available: true, value: amount(body.stock_value) ?? 0 },
    };
}

/** Stock cards and the five §7.1 charts. Receipt and delivery charts stay unavailable. */
export async function loadStockDashboard(filters: Json): Promise<StockDashboardData> {
    const supabase = createClient();
    const [cards, warehouseChart, receipts, deliveries, oldest, shortage] = await Promise.all([
        supabase.rpc("card_stock", { p_filters: filters }),
        supabase.rpc("chart_stock", { p_chart: "warehouse_value", p_filters: filters }),
        supabase.rpc("chart_stock", { p_chart: "purchase_receipt_trends", p_filters: filters }),
        supabase.rpc("chart_stock", { p_chart: "delivery_trends", p_filters: filters }),
        supabase.rpc("chart_stock", { p_chart: "oldest_items", p_filters: filters }),
        supabase.rpc("chart_stock", { p_chart: "shortage", p_filters: filters }),
    ]);
    return {
        ...cardsOf(cards.data, cards.error),
        warehouseChart: seriesOf(warehouseChart.data, warehouseChart.error),
        receipts: seriesOf(receipts.data, receipts.error),
        deliveries: seriesOf(deliveries.data, deliveries.error),
        oldest: seriesOf(oldest.data, oldest.error),
        shortage: seriesOf(shortage.data, shortage.error),
    };
}
