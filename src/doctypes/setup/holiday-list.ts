import { addLocalHolidays, addWeeklyHolidays, clearHolidays, WEEKDAYS } from "@/lib/holidays";
import { defineChildDoctype, defineDoctype } from "../define";

/** ERPNext Holiday (erpnext/setup/doctype/holiday): one row of a Holiday List. */
export const holiday = defineChildDoctype({
    doctype: "Holiday",
    table: "holiday",
    fields: {
        holiday_date: { type: "Date", label: "Date", required: true },
        description: { type: "Data", label: "Description", required: true },
        weekly_off: { type: "Check", label: "Weekly Off" },
        is_half_day: { type: "Check", label: "Half Day" },
    },
    columns: ["holiday_date", "description", "weekly_off", "is_half_day"],
});

/**
 * ERPNext Holiday List (erpnext/setup/doctype/holiday_list). Validation, ordering and `total_holidays` are
 * recomputed in the database (`app.holiday_list_refresh`, 0113); the actions below edit the unsaved form (§2.5).
 */
export const holidayList = defineDoctype<"holiday_list", "holidays">({
    doctype: "Holiday List",
    table: "holiday_list",
    module: "setup",
    slug: "holiday-list",
    titleField: "holiday_list_name",
    fields: {
        holiday_list_name: { type: "Data", label: "Holiday List Name", required: true },
        from_date: { type: "Date", label: "From Date", required: true },
        to_date: { type: "Date", label: "To Date", required: true },
        total_holidays: { type: "Float", label: "Total Holidays", readOnly: true },
        color: { type: "Color", label: "Color" },
        weekly_off: { type: "Select", label: "Weekly Off", options: ["", ...WEEKDAYS] },
        is_half_day: { type: "Check", label: "Is Half Day", description: "Applied to the weekly off days added." },
        country: { type: "Select", label: "Country", options: "Country" },
        subdivision: { type: "Data", label: "Subdivision", description: "State or region code, e.g. CA." },
        holidays: { type: "Table", label: "Holidays", target: "Holiday" },
    },
    children: { holidays: holiday },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["holiday_list_name", "from_date", "to_date"],
                        ["total_holidays", "color"],
                    ],
                },
                { label: "Add Weekly Holidays", columns: [["weekly_off"], ["is_half_day"]] },
                { label: "Add Local Holidays", columns: [["country"], ["subdivision"]] },
                { label: "Holidays", columns: [["holidays"]] },
            ],
        },
    ],
    listView: {
        columns: ["holiday_list_name", "from_date", "to_date", "total_holidays"],
        searchFields: ["holiday_list_name"],
        defaultSort: { field: "from_date", desc: true },
    },
    actions: [
        { id: "add-weekly-holidays", label: "Add Weekly Holidays", run: (values) => addWeeklyHolidays(values) },
        {
            id: "add-local-holidays",
            label: "Add Local Holidays",
            run: async (values, { orgSlug }) => {
                // Server Action, imported lazily so descriptors stay importable outside Next (registry tests).
                const { getLocalHolidays } = await import("@/lib/actions/holidays");
                const result = await getLocalHolidays({
                    orgSlug,
                    country: String(values.country ?? ""),
                    subdivision: String(values.subdivision ?? ""),
                    from: String(values.from_date ?? ""),
                    to: String(values.to_date ?? ""),
                });
                if (!result.ok) throw new Error(result.error);
                return addLocalHolidays(values, result.data ?? []);
            },
        },
        { id: "clear-table", label: "Clear Table", run: () => clearHolidays() },
    ],
    errorFields: {
        duplicate: "holiday_list_name",
        holiday_dates: "to_date",
        holiday_out_of_range: "holidays",
        holiday_duplicate: "holidays",
    },
});
