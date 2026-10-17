import { defineChildDoctype, defineDoctype } from "../define";

export const customerGroupAccount = defineChildDoctype({
    doctype: "Customer Group Account",
    table: "customer_group_party_account",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        account_id: { type: "Link", label: "Account", target: "Account" },
    },
    columns: ["company_id", "account_id"],
});

export const customerGroupCreditLimit = defineChildDoctype({
    doctype: "Customer Group Credit Limit",
    table: "customer_group_credit_limit",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        credit_limit: { type: "Currency", label: "Credit Limit", default: 0 },
        bypass_credit_limit_check: { type: "Check", label: "Bypass Credit Limit Check" },
    },
    columns: ["company_id", "credit_limit", "bypass_credit_limit_check"],
});

/** ERPNext Customer Group. A group selected on a customer cannot become a group. */
export const customerGroup = defineDoctype<"customer_group", "accounts" | "credit_limits">({
    doctype: "Customer Group",
    table: "customer_group",
    module: "selling",
    slug: "customer-group",
    titleField: "customer_group_name",
    fields: {
        customer_group_name: { type: "Data", label: "Customer Group Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Customer Group",
            target: "Customer Group",
            description: "Leave empty to place the group under All Customer Groups.",
        },
        is_group: { type: "Check", label: "Is Group" },
        default_price_list_id: { type: "Link", label: "Default Price List", target: "Price List" },
        payment_terms_id: { type: "Link", label: "Default Payment Terms Template", target: "Payment Terms Template" },
        accounts: { type: "Table", label: "Accounts", target: "Customer Group Account" },
        credit_limits: { type: "Table", label: "Credit Limits", target: "Customer Group Credit Limit" },
    },
    children: { accounts: customerGroupAccount, credit_limits: customerGroupCreditLimit },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["customer_group_name", "parent_id", "is_group"],
                        ["default_price_list_id", "payment_terms_id"],
                    ],
                },
                { columns: [["credit_limits"], ["accounts"]] },
            ],
        },
    ],
    listView: {
        columns: ["customer_group_name", "parent_id", "is_group"],
        searchFields: ["customer_group_name"],
        defaultSort: { field: "customer_group_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "customer_group_name",
        customer_group_root: "customer_group_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
        customer_group_in_use: "is_group",
        customer_price_list: "default_price_list_id",
        party_account_type: "accounts",
    },
});
