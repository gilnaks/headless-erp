import "server-only";
import { cache } from "react";
import type { SelectItemType } from "@/components/base/select/select";
import type { OptionSource } from "@/doctypes/define";
import { timeZoneOptions } from "@/lib/intl";
import { chartOfAccountsItems, countryItems, currencyItems, type ReferenceItem, type ReferenceOptions } from "@/lib/reference-options";
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

/** The standard role profiles every new organization gets (for invites made before the organization exists). */
export const getRoleProfileTemplates = cache(async (): Promise<SelectItemType[]> => {
    const supabase = await createClient();
    const { data } = await supabase.from("role_profile_template").select("name, roles").order("name");
    return (data ?? []).map((r) => ({ id: r.name, label: r.name, supportingText: r.roles.join(", ") }));
});

/** Enabled roles of one organization (RLS: members read their org's roles). */
export const getRoleOptions = cache(async (orgId: string): Promise<SelectItemType[]> => {
    const supabase = await createClient();
    const { data } = await supabase.from("roles").select("name").eq("org_id", orgId).eq("disabled", false).order("name");
    return (data ?? []).map((r) => ({ id: r.name, label: r.name }));
});

/** Document types (child tables excluded); `targetsOnly` keeps those a User Permission can restrict. */
const getDoctypeOptions = cache(async (targetsOnly: boolean): Promise<SelectItemType[]> => {
    const supabase = await createClient();
    let query = supabase.from("doctype_meta").select("doctype").eq("is_child", false).order("doctype");
    if (targetsOnly) query = query.eq("user_permission_target", true);
    const { data } = await query;
    return (data ?? []).map((r) => ({ id: r.doctype, label: r.doctype }));
});

/** Chart of accounts templates (global), tagged with their countries (`coa_template_country`). */
export const getChartOfAccountsOptions = cache(async (): Promise<ReferenceItem[]> => {
    const supabase = await createClient();
    const [templates, countries] = await Promise.all([
        supabase.from("coa_template").select("name").eq("disabled", false).order("name"),
        supabase.from("coa_template_country").select("template, country_name"),
    ]);
    return chartOfAccountsItems(templates.data ?? [], countries.data ?? []);
});

const LOADERS: Record<OptionSource, (orgId: string) => Promise<ReferenceItem[]>> = {
    Currency: () => getCurrencies(),
    Country: () => getCountries(),
    TimeZone: async () => timeZoneOptions(),
    Role: getRoleOptions,
    DocType: () => getDoctypeOptions(false),
    UserPermissionTarget: () => getDoctypeOptions(true),
    ChartOfAccounts: () => getChartOfAccountsOptions(),
};

/** Loads only the option lists a form uses. */
export async function getReferenceOptions(sources: OptionSource[], orgId: string): Promise<ReferenceOptions> {
    const lists = await Promise.all(sources.map((s) => LOADERS[s](orgId)));
    return Object.fromEntries(sources.map((s, i) => [s, lists[i]]));
}
