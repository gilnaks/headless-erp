import { requireUser } from "@/lib/auth/claims";
import { dbError } from "@/lib/errors";
import { redirect } from "@/lib/navigate";
import { refresh } from "@/lib/query-client";
import { createClient } from "@/lib/supabase/client";

/** Close, hold, re-open, or resume a submitted sales order. Draft recomputes the status. */
export async function updateSalesOrderStatus(orgSlug: string, id: string, status: "Closed" | "On Hold" | "Draft"): Promise<void> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { error } = await supabase.rpc("update_sales_order_status", { p_id: id, p_status: status });
    if (error) throw new Error(dbError(error).message);
    refresh();
}

/** Draft Delivery Note for the order's remaining qty, then opens it. */
export async function makeDeliveryNoteFromSalesOrder(orgSlug: string, id: string): Promise<never> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("map_doc", {
        p_source_doctype: "Sales Order",
        p_source_id: id,
        p_target_doctype: "Delivery Note",
    });
    if (error) throw new Error(dbError(error).message);
    const created = data as { id?: string } | null;
    if (!created?.id) throw new Error("Delivery Note was not created.");
    redirect(`/${orgSlug}/stock/delivery-note/${created.id}`);
}
