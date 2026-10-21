import { requireUser } from "@/lib/auth/claims";
import { dbError } from "@/lib/errors";
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
