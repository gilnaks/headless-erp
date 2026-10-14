import "server-only";
import { cache } from "react";
import type { OptionSource } from "@/doctypes/define";
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

const LOADERS: Record<OptionSource, () => ReturnType<typeof getCurrencies>> = {
    Currency: getCurrencies,
    Country: getCountries,
};

/** Loads only the reference lists a form uses (global tables, readable by any signed-in user). */
export async function getReferenceOptions(sources: OptionSource[]): Promise<ReferenceOptions> {
    const lists = await Promise.all(sources.map((s) => LOADERS[s]()));
    return Object.fromEntries(sources.map((s, i) => [s, lists[i]]));
}
