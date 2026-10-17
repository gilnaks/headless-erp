import { defineChildDoctype, defineDoctype } from "../define";

export const brandDefault = defineChildDoctype({
    doctype: "Brand Default",
    table: "brand_default",
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

/** ERPNext Brand. Company defaults use the same columns as an item default. */
export const brand = defineDoctype<"brand", "brand_defaults">({
    doctype: "Brand",
    table: "brand",
    module: "stock",
    slug: "brand",
    titleField: "brand",
    fields: {
        brand: { type: "Data", label: "Brand", required: true },
        description: { type: "Text", label: "Description" },
        brand_defaults: { type: "Table", label: "Defaults", target: "Brand Default" },
    },
    children: { brand_defaults: brandDefault },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["brand", "description"]] }, { columns: [["brand_defaults"]] }],
        },
    ],
    listView: {
        columns: ["brand", "description"],
        searchFields: ["brand"],
        defaultSort: { field: "brand" },
    },
    errorFields: { duplicate: "brand", item_default_company: "brand_defaults" },
});
