import { defineDoctype } from "../define";

/** ERPNext Item Price. The name is a random id. A party-specific row beats the list price. */
export const itemPrice = defineDoctype({
    doctype: "Item Price",
    table: "item_price",
    module: "stock",
    slug: "item-price",
    titleField: "item_name",
    fields: {
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        uom_id: { type: "Link", label: "UOM", target: "UOM" },
        packing_unit: { type: "Int", label: "Packing Unit", default: 0 },
        item_name: { type: "Data", label: "Item Name", readOnly: true },
        name: { type: "Data", label: "Name", readOnly: true },
        price_list_id: { type: "Link", label: "Price List", target: "Price List", required: true },
        customer_id: { type: "Link", label: "Customer", target: "Customer" },
        supplier_id: { type: "Link", label: "Supplier", target: "Supplier" },
        buying: { type: "Check", label: "Buying", readOnly: true },
        selling: { type: "Check", label: "Selling", readOnly: true },
        currency: { type: "Select", label: "Currency", options: "Currency", readOnly: true },
        price_list_rate: { type: "Currency", label: "Rate", required: true },
        valid_from: { type: "Date", label: "Valid From" },
        valid_upto: { type: "Date", label: "Valid Upto" },
        lead_time_days: { type: "Int", label: "Lead Time in days" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["item_id", "uom_id", "packing_unit", "item_name", "name"],
                        [
                            "price_list_id",
                            "customer_id",
                            "supplier_id",
                            "buying",
                            "selling",
                            "currency",
                            "price_list_rate",
                            "valid_from",
                            "valid_upto",
                            "lead_time_days",
                        ],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["item_name", "price_list_id", "price_list_rate", "uom_id", "valid_from"],
        searchFields: ["item_name", "name"],
        defaultSort: { field: "item_name" },
    },
    errorFields: {
        duplicate: "item_id",
        item_price_list: "price_list_id",
        item_price_uom: "uom_id",
        item_price_dates: "valid_upto",
        item_price_duplicate: "item_id",
    },
});
