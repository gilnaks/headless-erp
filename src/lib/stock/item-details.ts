import type { FieldValues } from "react-hook-form";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/types/database";

export type ItemDetails = {
    item_id: string;
    item_name: string | null;
    description: string | null;
    stock_uom_id: string;
    uom_id: string;
    conversion_factor: number;
    stock_qty: number;
    price_list_rate: number | null;
    rate: number | null;
    income_account_id: string | null;
    expense_account_id: string | null;
    cost_center_id: string | null;
    warehouse_id: string | null;
    actual_qty: number;
    projected_qty: number;
    has_serial_no: boolean;
    has_batch_no: boolean;
    item_tax_template_id: string | null;
    weight_per_unit: number | null;
    item_tax_rate: Record<string, number | string>;
};

type ItemDetailsArgs = {
    itemId: string;
    companyId: string;
    doctype: string;
    transactionType?: "selling" | "buying";
    qty?: number;
    uomId?: string;
    warehouseId?: string;
    customerId?: string;
    transactionDate?: string;
};

const TARGET_PURPOSES = new Set(["Material Receipt"]);
const SOURCE_PURPOSES = new Set(["Material Issue", "Material Consumption for Manufacture", "Send to Subcontractor"]);
const EITHER_PURPOSES = new Set(["Material Transfer", "Material Transfer for Manufacture", "Manufacture", "Repack"]);

function text(value: unknown): string {
    return typeof value === "string" ? value : "";
}

function blank(value: unknown): boolean {
    return value == null || value === "";
}

function blankRate(value: unknown): boolean {
    if (blank(value)) return true;
    return Number(value) === 0;
}

function qtyOf(value: unknown): number {
    if (blank(value)) return 0;
    const qty = Number(value);
    return Number.isFinite(qty) ? qty : 0;
}

function changedItem(path: string | undefined): { index: number; field: string } | null {
    const match = path?.match(/^items\.(\d+)\.(item_id|qty|uom_id)$/);
    if (!match?.[1] || !match[2]) return null;
    return { index: Number(match[1]), field: match[2] };
}

function rowAt(values: FieldValues, index: number): Record<string, unknown> | null {
    const items = values.items;
    if (!Array.isArray(items)) return null;
    const row = items[index];
    return row && typeof row === "object" ? (row as Record<string, unknown>) : null;
}

/** The row lookup Selling and Buying call. RLS decides what the caller can see. */
export async function getItemDetails(args: ItemDetailsArgs): Promise<ItemDetails> {
    const payload: { [key: string]: Json | undefined } = {
        item_id: args.itemId,
        company_id: args.companyId,
        doctype: args.doctype,
        qty: args.qty ?? 0,
    };
    if (args.transactionType) payload.transaction_type = args.transactionType;
    if (args.uomId) payload.uom_id = args.uomId;
    if (args.warehouseId) payload.warehouse_id = args.warehouseId;
    if (args.customerId) payload.customer_id = args.customerId;
    if (args.transactionDate) payload.transaction_date = args.transactionDate;

    const { data, error } = await createClient().rpc("get_item_details", { p: payload });
    if (error) throw new Error(error.message);
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("Item details were not returned.");
    return data as ItemDetails;
}

function sharedPatch(prefix: string, row: Record<string, unknown>, details: ItemDetails, field: string): FieldValues {
    const patch: FieldValues = {};
    if (blank(row.uom_id) && details.uom_id) patch[`${prefix}.uom_id`] = details.uom_id;
    if (field !== "qty") patch[`${prefix}.conversion_factor`] = String(details.conversion_factor);
    if (blank(row.cost_center_id) && details.cost_center_id) patch[`${prefix}.cost_center_id`] = details.cost_center_id;
    return patch;
}

async function stockEntryPurpose(typeId: string): Promise<string> {
    const { data } = await createClient().from("stock_entry_type").select("purpose").eq("id", typeId).maybeSingle();
    return data?.purpose ?? "";
}

function assignStockEntryWarehouse(row: Record<string, unknown>, purpose: string, warehouseId: string | null, prefix: string): FieldValues {
    if (!warehouseId) return {};
    const source = `${prefix}.s_warehouse_id`;
    const target = `${prefix}.t_warehouse_id`;
    if (TARGET_PURPOSES.has(purpose)) {
        return blank(row.t_warehouse_id) ? { [target]: warehouseId } : {};
    }
    if (SOURCE_PURPOSES.has(purpose)) {
        return blank(row.s_warehouse_id) ? { [source]: warehouseId } : {};
    }
    if (!EITHER_PURPOSES.has(purpose)) return {};
    const sourceBlank = blank(row.s_warehouse_id);
    const targetBlank = blank(row.t_warehouse_id);
    if (sourceBlank && targetBlank) return { [target]: warehouseId };
    if (sourceBlank) return { [source]: warehouseId };
    if (targetBlank) return { [target]: warehouseId };
    return {};
}

/** Fills a blank Stock Entry row from get_item_details. A warehouse or rate already typed stays. */
export async function fillStockEntryItem(values: FieldValues, path?: string): Promise<FieldValues> {
    const changed = changedItem(path);
    if (!changed) return {};
    const companyId = text(values.company_id);
    const row = rowAt(values, changed.index);
    const itemId = row ? text(row.item_id) : "";
    if (!row || !companyId || !itemId) return {};

    const details = await getItemDetails({
        itemId,
        companyId,
        doctype: "Stock Entry",
        qty: qtyOf(row.qty),
        uomId: text(row.uom_id) || undefined,
        transactionDate: text(values.posting_date) || undefined,
    });
    const prefix = `items.${changed.index}`;
    const factor =
        changed.field === "qty" ? qtyOf(row.conversion_factor || details.conversion_factor || 1) : Number(details.conversion_factor);
    const purpose = await stockEntryPurpose(text(values.stock_entry_type_id));
    return {
        ...sharedPatch(prefix, row, details, changed.field),
        ...assignStockEntryWarehouse(row, purpose, details.warehouse_id, prefix),
        [`${prefix}.transfer_qty`]: String(qtyOf(row.qty) * (Number.isFinite(factor) ? factor : 1)),
        ...(blank(row.expense_account_id) && details.expense_account_id
            ? { [`${prefix}.expense_account_id`]: details.expense_account_id }
            : {}),
        ...(blankRate(row.basic_rate) && details.rate != null ? { [`${prefix}.basic_rate`]: String(details.rate) } : {}),
    };
}

/** Fills a blank Material Request row from get_item_details. A warehouse or rate already typed stays. */
export async function fillMaterialRequestItem(values: FieldValues, path?: string): Promise<FieldValues> {
    const changed = changedItem(path);
    if (!changed) return {};
    const companyId = text(values.company_id);
    const row = rowAt(values, changed.index);
    const itemId = row ? text(row.item_id) : "";
    if (!row || !companyId || !itemId) return {};

    const buying = values.material_request_type === "Purchase";
    const details = await getItemDetails({
        itemId,
        companyId,
        doctype: "Material Request",
        transactionType: buying ? "buying" : "selling",
        qty: qtyOf(row.qty),
        uomId: text(row.uom_id) || undefined,
        customerId: text(values.customer_id) || undefined,
        transactionDate: text(values.transaction_date) || undefined,
    });
    const prefix = `items.${changed.index}`;
    const factor =
        changed.field === "qty" ? qtyOf(row.conversion_factor || details.conversion_factor || 1) : Number(details.conversion_factor);
    return {
        ...sharedPatch(prefix, row, details, changed.field),
        [`${prefix}.stock_qty`]: String(qtyOf(row.qty) * (Number.isFinite(factor) ? factor : 1)),
        ...(blank(row.stock_uom_id) && details.stock_uom_id ? { [`${prefix}.stock_uom_id`]: details.stock_uom_id } : {}),
        ...(blank(row.warehouse_id) && details.warehouse_id ? { [`${prefix}.warehouse_id`]: details.warehouse_id } : {}),
        ...(blankRate(row.rate) && details.rate != null ? { [`${prefix}.rate`]: String(details.rate) } : {}),
    };
}

/** Fills a blank Quotation row from get_item_details. A rate the user already typed stays. */
export async function fillQuotationItem(values: FieldValues, path?: string): Promise<FieldValues> {
    const changed = changedItem(path);
    if (!changed) return {};
    const companyId = text(values.company_id);
    const row = rowAt(values, changed.index);
    const itemId = row ? text(row.item_id) : "";
    if (!row || !companyId || !itemId) return {};

    const details = await getItemDetails({
        itemId,
        companyId,
        doctype: "Quotation",
        transactionType: "selling",
        qty: qtyOf(row.qty),
        uomId: text(row.uom_id) || undefined,
        customerId: text(values.customer_id) || undefined,
        transactionDate: text(values.transaction_date) || undefined,
    });
    const prefix = `items.${changed.index}`;
    const factor =
        changed.field === "qty" ? qtyOf(row.conversion_factor || details.conversion_factor || 1) : Number(details.conversion_factor);
    return {
        ...sharedPatch(prefix, row, details, changed.field),
        [`${prefix}.stock_qty`]: String(qtyOf(row.qty) * (Number.isFinite(factor) ? factor : 1)),
        ...(blank(row.item_name) && details.item_name ? { [`${prefix}.item_name`]: details.item_name } : {}),
        ...(blank(row.stock_uom_id) && details.stock_uom_id ? { [`${prefix}.stock_uom_id`]: details.stock_uom_id } : {}),
        ...(blank(row.warehouse_id) && details.warehouse_id ? { [`${prefix}.warehouse_id`]: details.warehouse_id } : {}),
        ...(blank(row.price_list_rate) && details.price_list_rate != null
            ? { [`${prefix}.price_list_rate`]: String(details.price_list_rate) }
            : {}),
        ...(blankRate(row.rate) && details.rate != null ? { [`${prefix}.rate`]: String(details.rate) } : {}),
    };
}
