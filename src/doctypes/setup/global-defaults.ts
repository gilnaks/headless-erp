import { defineDoctype } from "../define";

/**
 * Global Defaults (erpnext/setup/doctype/global_defaults/global_defaults.json), a single doctype seeded with the
 * organization. `default_distance_unit` joins the form with the UOM doctype (P1). Validation and currency enabling
 * live in supabase/migrations/0103_setup_global_defaults.sql.
 */
export const globalDefaults = defineDoctype({
    doctype: "Global Defaults",
    table: "global_defaults",
    module: "setup",
    slug: "global-defaults",
    single: true,
    fields: {
        default_company_id: { type: "Link", label: "Default Company", target: "Company" },
        country: { type: "Select", label: "Country", options: "Country" },
        default_currency: { type: "Select", label: "Default Currency", required: true, options: "Currency" },
        hide_currency_symbol: {
            type: "Check",
            label: "Hide Currency Symbol",
            description: "Do not show any symbol like $ etc next to currencies.",
        },
        disable_rounded_total: {
            type: "Check",
            label: "Disable Rounded Total",
            description: "If disabled, 'Rounded Total' field will not be visible in any transaction",
        },
        disable_in_words: {
            type: "Check",
            label: "Disable In Words",
            description: "If disabled, 'In Words' field will not be visible in any transaction",
        },
        use_posting_datetime_for_naming_documents: {
            type: "Check",
            label: "Use Posting Datetime for Naming Documents",
            default: true,
            description: "Naming series with date parts use the posting date instead of the creation date.",
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["default_company_id", "country", "default_currency"],
                        ["hide_currency_symbol", "disable_rounded_total", "disable_in_words"],
                    ],
                },
                { label: "Document Naming", columns: [["use_posting_datetime_for_naming_documents"]] },
            ],
        },
    ],
    errorFields: {
        company_unknown: "default_company_id",
        country_unknown: "country",
        currency_unknown: "default_currency",
    },
});
