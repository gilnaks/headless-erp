import { defineDoctype } from "../define";

const DIGITS = ["", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] as const;

/**
 * System Settings (frappe/core/doctype/system_settings/system_settings.json), the subset that affects our behaviour.
 * A single doctype seeded with the organization from its country, currency and time zone; option lists mirror the
 * check constraints in supabase/migrations/0104_setup_system_settings.sql.
 */
export const systemSettings = defineDoctype({
    doctype: "System Settings",
    table: "system_settings",
    module: "setup",
    slug: "system-settings",
    single: true,
    fields: {
        app_name: { type: "Data", label: "App Name", required: true },
        language: { type: "Data", label: "Language", required: true },
        time_zone: { type: "Select", label: "Time Zone", required: true, options: "TimeZone" },
        date_format: {
            type: "Select",
            label: "Date Format",
            required: true,
            options: ["dd-mm-yyyy", "dd.mm.yyyy", "dd/mm/yyyy", "mm/dd/yyyy", "mm-dd-yyyy", "yyyy-mm-dd"],
            default: "dd-mm-yyyy",
        },
        time_format: { type: "Select", label: "Time Format", required: true, options: ["HH:mm:ss", "HH:mm"], default: "HH:mm:ss" },
        first_day_of_the_week: {
            type: "Select",
            label: "First Day of the Week",
            required: true,
            options: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            default: "Sunday",
        },
        number_format: {
            type: "Select",
            label: "Number Format",
            required: true,
            options: [
                "#,###.##",
                "#.###,##",
                "# ###.##",
                "# ###,##",
                "#'###.##",
                "#, ###.##",
                "#,##,###.##",
                "#,###.###",
                "#.###",
                "#,###",
            ],
            default: "#,###.##",
        },
        float_precision: { type: "Select", label: "Float Precision", required: true, options: DIGITS.slice(3), default: "3" },
        currency_precision: {
            type: "Select",
            label: "Currency Precision",
            options: DIGITS,
            description: "If not set, the currency precision will depend on number format",
        },
        email_footer_address: { type: "Text", label: "Email Footer Address" },
    },
    tabs: [
        {
            label: "General",
            sections: [
                { label: "System", columns: [["app_name", "language"], ["time_zone"]] },
                {
                    label: "Date and Number Format",
                    columns: [
                        ["date_format", "time_format", "first_day_of_the_week"],
                        ["number_format", "float_precision", "currency_precision"],
                    ],
                },
                { label: "Email", columns: [["email_footer_address"]] },
            ],
        },
    ],
    errorFields: { time_zone_unknown: "time_zone" },
});
