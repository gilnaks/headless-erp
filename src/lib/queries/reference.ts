import "server-only";
import { cache } from "react";
import type { SelectItemType } from "@/components/base/select/select";
import type { OptionSource } from "@/doctypes/define";
import { timeZoneOptions } from "@/lib/intl";
import { countryItems, currencyItems, type ReferenceOptions } from "@/lib/reference-options";
import { createClient } from "@/lib/supabase/server";

export const getCurrencies = cache(async () => {
    const supabase = await createClient();
    const { data } = await supabase.from("currency").select("code, currency_name").order("code");
    return currencyItems(data ?? []);
});

export const getCountries = cache(async () => {
    const supabase = await createClient();
    const { data } = await supabase.from("country").select("country_name").order("country_name");
    return countryItems(data ?? []);
});

/** Enabled roles of one organization (RLS: members read their org's roles). */
export const getRoleOptions = cache(async (orgId: string): Promise<SelectItemType[]> => {
    const supabase = await createClient();
    const { data } = await supabase.from("roles").select("name").eq("org_id", orgId).eq("disabled", false).order("name");
    return (data ?? []).map((r) => ({ id: r.name, label: r.name }));
});

const LOADERS: Record<OptionSource, (orgId: string) => Promise<SelectItemType[]>> = {
    Currency: () => getCurrencies(),
    Country: () => getCountries(),
    TimeZone: async () => timeZoneOptions(),
    Role: getRoleOptions,
};

/** Loads only the option lists a form uses. */
export async function getReferenceOptions(sources: OptionSource[], orgId: string): Promise<ReferenceOptions> {
    const lists = await Promise.all(sources.map((s) => LOADERS[s](orgId)));
    return Object.fromEntries(sources.map((s, i) => [s, lists[i]]));
}
