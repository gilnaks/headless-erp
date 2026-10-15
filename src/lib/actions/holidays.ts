import Holidays from "date-holidays";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, fail } from "@/lib/errors";
import type { LocalHoliday } from "@/lib/holidays";
import { getOrgBySlug } from "@/lib/queries/doc";
import { createClient } from "@/lib/supabase/client";

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_YEARS = 10;

/**
 * Public holidays of `country` (a `country.country_name`) and optional `subdivision` (state / region code) between
 * two dates: the lookup half of ERPNext `HolidayList.get_local_holidays` (python `holidays`), using `date-holidays`
 * on the server so its data stays out of the client bundle. Names are in English.
 */
export async function getLocalHolidays(input: {
    orgSlug: string;
    country: string;
    subdivision?: string;
    from: string;
    to: string;
}): Promise<ActionResult<LocalHoliday[]>> {
    await requireUser(`/${input.orgSlug}`);
    if (!(await getOrgBySlug(input.orgSlug))) return fail("Organization not found.");
    if (!input.country) return fail("Please select a country.");
    if (!DATE.test(input.from) || !DATE.test(input.to) || input.from > input.to) return fail("Please set From Date and To Date first.");

    const supabase = await createClient();
    const { data } = await supabase.from("country").select("code").eq("country_name", input.country).maybeSingle();
    const code = data?.code?.toUpperCase();
    if (!code || !(code in new Holidays().getCountries())) return fail(`Local holidays are not available for ${input.country}.`);

    const subdivision = input.subdivision?.trim().toUpperCase() || undefined;
    if (subdivision && !(subdivision in (new Holidays().getStates(code) ?? {}))) {
        return fail(`${input.subdivision} is not a subdivision of ${input.country}.`);
    }

    const options = { languages: ["en"], types: ["public" as const] };
    const holidays = subdivision ? new Holidays(code, subdivision, options) : new Holidays(code, options);
    const first = Number(input.from.slice(0, 4));
    const last = Math.min(Number(input.to.slice(0, 4)), first + MAX_YEARS - 1);
    const byDate = new Map<string, string>();
    for (let year = first; year <= last; year++) {
        for (const h of holidays.getHolidays(year) ?? []) {
            const date = h.date.slice(0, 10);
            if (date >= input.from && date <= input.to && !byDate.has(date)) byDate.set(date, h.name);
        }
    }
    return { ok: true, data: [...byDate].map(([date, name]) => ({ date, name })).sort((a, b) => a.date.localeCompare(b.date)) };
}
