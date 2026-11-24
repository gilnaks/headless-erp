import { dbError } from "@/lib/errors";
import type { DashboardCard, DashboardSeries } from "@/lib/queries/accounts-dashboard";
import type { ProfitAndLossChart } from "@/lib/queries/profit-and-loss";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

const EMPTY_CHART: ProfitAndLossChart = { type: "bar", labels: [], datasets: [] };

export type SellingDashboardData = {
    annualSales: DashboardCard;
    toDeliver: DashboardCard;
    toBill: DashboardCard;
    customers: DashboardCard;
    trends: DashboardSeries;
    topCustomers: DashboardSeries;
    analysis: DashboardSeries;
    itemSales: DashboardSeries;
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
    return { type: chart.type === "line" ? "line" : "bar", labels, datasets };
}

function seriesOf(data: Json | null, error: { message: string } | null): DashboardSeries {
    if (error) return { available: false, chart: { ...EMPTY_CHART }, error: dbError(error).message };
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    if (body.available !== true) return { available: false, chart: { ...EMPTY_CHART } };
    return { available: true, chart: chartOf(body.chart) };
}

function cardsOf(
    data: Json | null,
    error: { message: string } | null,
): Pick<SellingDashboardData, "annualSales" | "toDeliver" | "toBill" | "customers"> {
    if (error) {
        const card = { available: false, error: dbError(error).message };
        return { annualSales: card, toDeliver: card, toBill: card, customers: card };
    }
    const body = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    if (body.available !== true) {
        const card = { available: false };
        return { annualSales: card, toDeliver: card, toBill: card, customers: card };
    }
    return {
        annualSales: { available: true, value: amount(body.annual_sales) ?? 0 },
        toDeliver: { available: true, value: amount(body.to_deliver) ?? 0 },
        toBill: { available: true, value: amount(body.to_bill) ?? 0 },
        customers: { available: true, value: amount(body.active_customers) ?? 0 },
    };
}

/** Selling cards and the four §7.1 charts. Three report charts stay unavailable. */
export async function loadSellingDashboard(filters: Json): Promise<SellingDashboardData> {
    const supabase = createClient();
    const [cards, trends, topCustomers, analysis, itemSales] = await Promise.all([
        supabase.rpc("card_selling", { p_filters: filters }),
        supabase.rpc("chart_selling", { p_chart: "sales_order_trends", p_filters: filters }),
        supabase.rpc("chart_selling", { p_chart: "top_customers", p_filters: filters }),
        supabase.rpc("chart_selling", { p_chart: "sales_order_analysis", p_filters: filters }),
        supabase.rpc("chart_selling", { p_chart: "item_wise_annual_sales", p_filters: filters }),
    ]);
    return {
        ...cardsOf(cards.data, cards.error),
        trends: seriesOf(trends.data, trends.error),
        topCustomers: seriesOf(topCustomers.data, topCustomers.error),
        analysis: seriesOf(analysis.data, analysis.error),
        itemSales: seriesOf(itemSales.data, itemSales.error),
    };
}
