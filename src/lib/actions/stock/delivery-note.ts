import { requireUser } from "@/lib/auth/claims";
import { dbError } from "@/lib/errors";
import { refresh } from "@/lib/query-client";
import { createClient } from "@/lib/supabase/client";

/** Close or re-open a submitted delivery note. Draft recomputes the status. */
export async function updateDeliveryNoteStatus(orgSlug: string, id: string, status: "Closed" | "Draft"): Promise<void> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { error } = await supabase.rpc("update_delivery_note_status", { p_id: id, p_status: status });
    if (error) throw new Error(dbError(error).message);
    refresh();
}
