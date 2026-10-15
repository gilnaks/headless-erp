import { createClient } from "@/lib/supabase/client";

/** Copies the rest of the global UOM template into this organization (00-setup A19). */
export async function importUoms(orgSlug: string): Promise<number> {
    const supabase = createClient();
    const { data: org, error } = await supabase.from("organizations").select("id").eq("slug", orgSlug).maybeSingle();
    if (error) throw new Error(error.message);
    if (!org) throw new Error("Organization not found");
    const { data, error: rpcError } = await supabase.rpc("import_uoms", { p_org: org.id });
    if (rpcError) throw new Error(rpcError.message);
    return data ?? 0;
}
