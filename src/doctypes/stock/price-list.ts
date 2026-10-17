import { defineDoctype } from "../define";

/** ERPNext Price List. Standard Selling and Standard Buying are seeded (C1). */
export const priceList = defineDoctype({
    doctype: "Price List",
    table: "price_list",
    module: "stock",
    slug: "price-list",
    titleField: "name",
    fields: {
        price_list_name: { type: "Data", label: "Price List Name", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        currency: { type: "Select", label: "Currency", options: "Currency", required: true },
        enabled: { type: "Check", label: "Enabled", default: true },
        buying: { type: "Check", label: "Buying" },
        selling: { type: "Check", label: "Selling" },
        price_not_uom_dependent: { type: "Check", label: "Price not UOM Dependent" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["price_list_name", "currency", "enabled"],
                        ["name", "buying", "selling", "price_not_uom_dependent"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "currency", "buying", "selling", "enabled"],
        searchFields: ["name", "price_list_name"],
        defaultSort: { field: "name" },
    },
    errorFields: { duplicate: "price_list_name", price_list_side: "buying" },
});
