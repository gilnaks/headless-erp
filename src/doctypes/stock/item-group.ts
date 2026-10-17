import { defineChildDoctype, defineDoctype } from "../define";

export const itemGroupDefault = defineChildDoctype({
    doctype: "Item Group Default",
    table: "item_group_default",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        default_warehouse_id: { type: "Link", label: "Default Warehouse", target: "Warehouse" },
        default_price_list_id: { type: "Link", label: "Default Price List", target: "Price List" },
        income_account_id: { type: "Link", label: "Income Account", target: "Account" },
        expense_account_id: { type: "Link", label: "Expense Account", target: "Account" },
        buying_cost_center_id: { type: "Link", label: "Buying Cost Center", target: "Cost Center" },
        selling_cost_center_id: { type: "Link", label: "Selling Cost Center", target: "Cost Center" },
        default_supplier_id: { type: "Link", label: "Default Supplier", target: "Supplier" },
    },
    columns: [
        "company_id",
        "default_warehouse_id",
        "default_price_list_id",
        "income_account_id",
        "expense_account_id",
        "buying_cost_center_id",
        "selling_cost_center_id",
        "default_supplier_id",
    ],
});

export const itemGroupTax = defineChildDoctype({
    doctype: "Item Group Tax",
    table: "item_group_tax",
    fields: {
        item_tax_template_id: { type: "Link", label: "Item Tax Template", target: "Item Tax Template" },
        tax_category_id: { type: "Link", label: "Tax Category", target: "Tax Category" },
        valid_from: { type: "Date", label: "Valid From" },
        minimum_net_rate: { type: "Currency", label: "Minimum Net Rate" },
        maximum_net_rate: { type: "Currency", label: "Maximum Net Rate" },
    },
    columns: ["item_tax_template_id", "tax_category_id", "valid_from", "minimum_net_rate", "maximum_net_rate"],
});

/** ERPNext Item Group. A leaf selected on an item cannot become a group. */
export const itemGroup = defineDoctype<"item_group", "item_group_defaults" | "taxes">({
    doctype: "Item Group",
    table: "item_group",
    module: "stock",
    slug: "item-group",
    titleField: "item_group_name",
    fields: {
        item_group_name: { type: "Data", label: "Item Group Name", required: true },
        parent_id: {
            type: "Link",
            label: "Parent Item Group",
            target: "Item Group",
            description: "Leave empty to place the group under All Item Groups.",
        },
        is_group: { type: "Check", label: "Is Group" },
        item_group_defaults: { type: "Table", label: "Defaults", target: "Item Group Default" },
        taxes: { type: "Table", label: "Taxes", target: "Item Group Tax" },
    },
    children: { item_group_defaults: itemGroupDefault, taxes: itemGroupTax },
    tabs: [
        {
            label: "Details",
            sections: [
                { columns: [["item_group_name", "parent_id", "is_group"]] },
                { columns: [["item_group_defaults"]] },
                { columns: [["taxes"]] },
            ],
        },
    ],
    listView: {
        columns: ["item_group_name", "parent_id", "is_group"],
        searchFields: ["item_group_name"],
        defaultSort: { field: "item_group_name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group" },
    errorFields: {
        duplicate: "item_group_name",
        item_group_root: "item_group_name",
        invalid_parent: "parent_id",
        has_children: "is_group",
        item_group_in_use: "is_group",
        item_default_company: "item_group_defaults",
        item_tax_duplicate: "taxes",
        item_tax_range: "taxes",
    },
});
