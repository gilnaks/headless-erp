import { defineDoctype } from "../define";

/**
 * Company (erpnext/setup/doctype/company/company.json). Tabs follow ERPNext's Tab Breaks; Link fields to Account,
 * Cost Center, Warehouse, Terms and Payment Terms join the form when those tables exist
 * (P1-P4). Validations live in `app.companies_validate` (supabase/migrations/0100_setup_company.sql); new companies go
 * through `app.create_company` (0116), which grows the Company.on_update side effects.
 */
export const company = defineDoctype({
    doctype: "Company",
    table: "companies",
    module: "setup",
    slug: "company",
    titleField: "company_name",
    create: "create_company",
    fields: {
        company_name: { type: "Data", label: "Company", required: true },
        abbr: { type: "Data", label: "Abbr", required: true, description: "Used as a suffix in account and cost center names." },
        default_currency: { type: "Select", label: "Default Currency", required: true, options: "Currency" },
        country: { type: "Select", label: "Country", required: true, options: "Country" },
        is_group: { type: "Check", label: "Is Group" },
        parent_id: { type: "Link", label: "Parent Company", target: "Company" },
        default_holiday_list_id: { type: "Link", label: "Default Holiday List", target: "Holiday List" },
        default_letter_head_id: { type: "Link", label: "Default Letter Head", target: "Letter Head" },
        tax_id: { type: "Data", label: "Tax ID" },
        domain: { type: "Data", label: "Domain" },
        date_of_establishment: { type: "Date", label: "Date of Establishment" },
        reporting_currency: { type: "Data", label: "Reporting Currency", readOnly: true },
        create_chart_of_accounts_based_on: {
            type: "Select",
            label: "Create Chart Of Accounts Based On",
            options: ["Standard Template", "Existing Company"],
            default: "Standard Template",
            setOnlyOnce: true,
        },
        chart_of_accounts: {
            type: "Select",
            label: "Chart Of Accounts Template",
            options: "ChartOfAccounts",
            // get_charts_for_country(country, with_standard): the country's charts plus the untagged standard ones.
            filterOptions: (item, v) => !item.tags || item.tags.includes(String(v.country ?? "")),
            default: "Standard",
            setOnlyOnce: true,
            dependsOn: (v) => v.create_chart_of_accounts_based_on === "Standard Template",
        },
        existing_company_id: {
            type: "Link",
            label: "Existing Company",
            target: "Company",
            setOnlyOnce: true,
            dependsOn: (v) => v.create_chart_of_accounts_based_on === "Existing Company",
        },
        company_description: { type: "Text", label: "Company Description" },
        date_of_incorporation: { type: "Date", label: "Date of Incorporation" },
        date_of_commencement: { type: "Date", label: "Date of Commencement" },
        registration_details: {
            type: "Text",
            label: "Registration Details",
            description: "Company registration numbers for your reference.",
        },
        phone_no: { type: "Data", label: "Phone No" },
        fax: { type: "Data", label: "Fax" },
        email: { type: "Data", label: "Email" },
        website: { type: "Data", label: "Website" },
        default_sales_contact_id: { type: "Link", label: "Default Sales Contact", target: "Contact" },
        credit_limit: { type: "Currency", label: "Credit Limit", default: 0 },
        reconciliation_takes_effect_on: {
            type: "Select",
            label: "Reconciliation Takes Effect On",
            options: ["Advance Payment Date", "Oldest Of Invoice Or Advance", "Reconciliation Date"],
            default: "Oldest Of Invoice Or Advance",
        },
        auto_exchange_rate_revaluation: { type: "Check", label: "Auto Create Exchange Rate Revaluation" },
        auto_err_frequency: {
            type: "Select",
            label: "Frequency",
            options: ["", "Daily", "Weekly", "Monthly"],
            dependsOn: (v) => v.auto_exchange_rate_revaluation === true,
        },
        submit_err_jv: {
            type: "Check",
            label: "Submit ERR Journals?",
            dependsOn: (v) => v.auto_exchange_rate_revaluation === true,
        },
        enable_perpetual_inventory: { type: "Check", label: "Enable Perpetual Inventory", default: true },
        valuation_method: {
            type: "Select",
            label: "Default Stock Valuation Method",
            options: ["FIFO", "Moving Average", "LIFO"],
            default: "FIFO",
        },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["company_name", "abbr", "default_currency", "country", "is_group"],
                        [
                            "tax_id",
                            "domain",
                            "date_of_establishment",
                            "parent_id",
                            "reporting_currency",
                            "default_holiday_list_id",
                            "default_letter_head_id",
                        ],
                    ],
                },
                {
                    label: "Chart of Accounts",
                    columns: [["create_chart_of_accounts_based_on", "chart_of_accounts", "existing_company_id"]],
                },
                { label: "Company Description", columns: [["company_description"]] },
            ],
        },
        {
            label: "Address & Contact",
            sections: [
                {
                    label: "Company Info",
                    columns: [
                        ["date_of_incorporation", "date_of_commencement", "registration_details"],
                        ["phone_no", "fax", "email", "website"],
                    ],
                },
            ],
        },
        {
            label: "Accounts",
            sections: [
                { label: "Credit Limit", columns: [["credit_limit"], ["reconciliation_takes_effect_on"]] },
                {
                    label: "Exchange Rate Revaluation Settings",
                    columns: [["auto_exchange_rate_revaluation", "auto_err_frequency", "submit_err_jv"]],
                },
            ],
        },
        {
            label: "Buying and Selling",
            sections: [{ columns: [["default_sales_contact_id"]] }],
        },
        {
            label: "Stock",
            sections: [{ columns: [["enable_perpetual_inventory"], ["valuation_method"]] }],
        },
    ],
    listView: {
        columns: ["company_name", "abbr", "default_currency", "country"],
        searchFields: ["company_name", "abbr"],
        defaultSort: { field: "company_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        abbr_required: "abbr",
        abbr_taken: "abbr",
        coa_input: "existing_company_id",
        coa_unknown: "chart_of_accounts",
        invalid_parent: "parent_id",
        has_children: "is_group",
        duplicate: "company_name",
        country_unknown: "country",
        currency_unknown: "default_currency",
    },
});
