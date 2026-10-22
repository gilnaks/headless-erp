import { promptQuotationLost } from "@/components/erp/doc/quotation-lost-dialog";
import { requireUser } from "@/lib/auth/claims";
import { dbError } from "@/lib/errors";
import { redirect } from "@/lib/navigate";
import { refresh } from "@/lib/query-client";
import { createClient } from "@/lib/supabase/client";

/** Copies a submitted quotation into a draft named `<root>-R<n>` and opens it. */
export async function reviseQuotation(orgSlug: string, id: string): Promise<never> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("revise_quotation", { p_id: id });
    if (error) throw new Error(dbError(error).message);
    const created = data as { id?: string } | null;
    if (!created?.id) throw new Error("Quotation was not revised.");
    redirect(`/${orgSlug}/selling/quotation/${created.id}`);
}

/** Draft Sales Order for the quotation's remaining qty, then opens it. */
export async function makeSalesOrderFromQuotation(orgSlug: string, id: string): Promise<never> {
    await requireUser(`/${orgSlug}`);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("map_doc", {
        p_source_doctype: "Quotation",
        p_source_id: id,
        p_target_doctype: "Sales Order",
    });
    if (error) throw new Error(dbError(error).message);
    const created = data as { id?: string } | null;
    if (!created?.id) throw new Error("Sales Order was not created.");
    redirect(`/${orgSlug}/selling/sales-order/${created.id}`);
}

/** Asks for a lost reason, then marks this version and the other non-ordered versions Lost. */
export async function setQuotationLost(orgSlug: string, id: string): Promise<void> {
    await requireUser(`/${orgSlug}`);
    const choice = await promptQuotationLost();
    if (!choice) return;
    const supabase = createClient();
    const { error } = await supabase.rpc("set_quotation_lost", {
        p_id: id,
        p_reason_id: choice.reasonId,
        p_detail: choice.detail,
    });
    if (error) throw new Error(dbError(error).message);
    refresh();
}
