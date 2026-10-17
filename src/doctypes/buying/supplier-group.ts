import { defineChildDoctype, defineDoctype } from "../define";

export const supplierGroupAccount = defineChildDoctype({
    doctype: "Supplier Group Account",
    table: "supplier_group_party_account",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        account_id: { type: "Link", label: "Account", target: "Account" },
    },
    columns: ["company_id", "account_id"],
});

/** ERPNext Supplier Group. A group selected on a supplier cannot become a group. */
export const supplierGroup = defineDoctype<"supplier_group", "accounts">({
    doctype: "Supplier Group",
    table: "supplier_group",
    module: "buying",
    slug: "supplier-group",
    titleField: "supplier_group_name",
    fields: {
        supplier_group_name: { type: "Data", label: "Supplier Group Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Supplier Group",
            target: "Supplier Group",
            description: "Leave empty to place the group under All Supplier Groups.",
        },
        is_group: { type: "Check", label: "Is Group" },
        payment_terms_id: { type: "Link", label: "Default Payment Terms Template", target: "Payment Terms Template" },
        accounts: { type: "Table", label: "Accounts", target: "Supplier Group Account" },
    },
    children: { accounts: supplierGroupAccount },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["supplier_group_name", "parent_id", "is_group", "payment_terms_id"]] }, { columns: [["accounts"]] }],
        },
    ],
    listView: {
        columns: ["supplier_group_name", "parent_id", "is_group"],
        searchFields: ["supplier_group_name"],
        defaultSort: { field: "supplier_group_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "supplier_group_name",
        supplier_group_root: "supplier_group_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
        supplier_group_in_use: "is_group",
        party_account_type: "accounts",
    },
});
