import { requireUser } from "@/lib/auth/claims";
import { dbError } from "@/lib/errors";
import { redirect } from "@/lib/navigate";
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

/** Draft return for the quantity not yet returned, then opens it. */
export async function makeDeliveryNoteReturn(orgSlug: string, id: string): Promise<never> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("make_return_doc", { p_doctype: "Delivery Note", p_id: id });
    if (error) throw new Error(dbError(error).message);
    const created = data as { id?: string } | null;
    if (!created?.id) throw new Error("Return was not created.");
    redirect(`/${orgSlug}/stock/delivery-note/${created.id}`);
}
