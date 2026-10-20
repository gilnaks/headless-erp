import { requireUser } from "@/lib/auth/claims";
import { dbError } from "@/lib/errors";
import { redirect } from "@/lib/navigate";
import { refresh } from "@/lib/query-client";
import { createClient } from "@/lib/supabase/client";

/** Stop a submitted request, or reopen it (`Submitted` clears Stopped and recomputes the status). */
export async function setMaterialRequestStatus(orgSlug: string, id: string, status: "Stopped" | "Submitted"): Promise<void> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { error } = await supabase.rpc("material_request_set_status", { p_id: id, p_status: status });
    if (error) throw new Error(dbError(error).message);
    refresh();
}

/** Draft Stock Entry for the remaining Issue, Transfer, or Customer Provided qty. */
export async function makeStockEntryFromMaterialRequest(orgSlug: string, id: string): Promise<never> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("make_stock_entry_from_material_request", { p_id: id });
    if (error) throw new Error(dbError(error).message);
    const created = data as { id: string } | null;
    if (!created?.id) throw new Error("Stock Entry was not created.");
    redirect(`/${orgSlug}/stock/stock-entry/${created.id}`);
}
