import { defineChildDoctype, defineDoctype } from "../define";

export const customerPartyAccount = defineChildDoctype({
    doctype: "Party Account",
    table: "customer_party_account",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        account_id: { type: "Link", label: "Account", target: "Account" },
    },
    columns: ["company_id", "account_id"],
});

export const customerCreditLimit = defineChildDoctype({
    doctype: "Customer Credit Limit",
    table: "customer_credit_limit",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        credit_limit: { type: "Currency", label: "Credit Limit", default: 0 },
        bypass_credit_limit_check: { type: "Check", label: "Bypass Credit Limit Check" },
    },
    columns: ["company_id", "credit_limit", "bypass_credit_limit_check"],
});

export const customerSalesTeam = defineChildDoctype({
    doctype: "Sales Team",
    table: "customer_sales_team",
    fields: {
        sales_person_id: { type: "Link", label: "Sales Person", target: "Sales Person", required: true },
        allocated_percentage: { type: "Percent", label: "Allocated Percentage", default: 0 },
        commission_rate: { type: "Percent", label: "Commission Rate" },
    },
    columns: ["sales_person_id", "allocated_percentage", "commission_rate"],
});

/** ERPNext Customer. Naming is the customer name, with " - n" when that name is taken. */
export const customer = defineDoctype<"customer", "accounts" | "credit_limits" | "sales_team">({
    doctype: "Customer",
    table: "customer",
    module: "selling",
    slug: "customer",
    titleField: "name",
    addressContact: true,
    fields: {
        customer_name: { type: "Data", label: "Customer Name", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        customer_type: {
            type: "Select",
            label: "Customer Type",
            options: ["Company", "Individual", "Partnership"],
            default: "Company",
            required: true,
        },
        customer_group_id: { type: "Link", label: "Customer Group", target: "Customer Group" },
        territory_id: { type: "Link", label: "Territory", target: "Territory" },
        tax_id: { type: "Data", label: "Tax ID" },
        tax_category_id: { type: "Link", label: "Tax Category", target: "Tax Category" },
        default_currency: { type: "Select", label: "Billing Currency", options: "Currency" },
        default_price_list_id: { type: "Link", label: "Default Price List", target: "Price List" },
        payment_terms_id: { type: "Link", label: "Default Payment Terms Template", target: "Payment Terms Template" },
        industry_id: { type: "Link", label: "Industry", target: "Industry Type" },
        language: { type: "Data", label: "Print Language" },
        website: { type: "Data", label: "Website" },
        customer_details: { type: "Text", label: "Customer Details" },
        disabled: { type: "Check", label: "Disabled" },
        is_frozen: { type: "Check", label: "Is Frozen" },
        on_hold: { type: "Check", label: "Hold" },
        release_date: { type: "Date", label: "Release Date" },
        so_required: { type: "Check", label: "Allow Sales Invoice Creation Without Sales Order" },
        dn_required: { type: "Check", label: "Allow Sales Invoice Creation Without Delivery Note" },
        alias: { type: "Data", label: "Alias" },
        accounts: { type: "Table", label: "Accounts", target: "Party Account" },
        credit_limits: { type: "Table", label: "Credit Limits", target: "Customer Credit Limit" },
        sales_team: { type: "Table", label: "Sales Team", target: "Sales Team" },
    },
    children: { accounts: customerPartyAccount, credit_limits: customerCreditLimit, sales_team: customerSalesTeam },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["customer_name", "customer_type", "customer_group_id", "territory_id", "tax_id", "tax_category_id"],
                        ["name", "default_currency", "default_price_list_id", "payment_terms_id", "industry_id", "website"],
                    ],
                },
                { columns: [["customer_details", "language", "alias", "disabled", "is_frozen"]] },
            ],
        },
        {
            label: "Sales",
            sections: [
                { columns: [["so_required", "dn_required", "on_hold", "release_date"]] },
                { label: "Sales Team", columns: [["sales_team"]] },
            ],
        },
        {
            label: "Credit Limit and Accounts",
            sections: [{ columns: [["credit_limits"], ["accounts"]] }],
        },
    ],
    listView: {
        columns: ["name", "customer_group_id", "territory_id", "disabled"],
        searchFields: ["name", "customer_name", "tax_id"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "customer_name",
        customer_group_leaf: "customer_group_id",
        customer_price_list: "default_price_list_id",
        party_account_type: "accounts",
        party_account_missing: "accounts",
        sales_team_total: "sales_team",
        sales_person_disabled: "sales_team",
    },
});
