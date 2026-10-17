import { defineChildDoctype, defineDoctype } from "../define";

export const productBundleItem = defineChildDoctype({
    doctype: "Product Bundle Item",
    table: "product_bundle_item",
    fields: {
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        qty: { type: "Float", label: "Qty", required: true },
        uom_id: { type: "Link", label: "UOM", target: "UOM" },
        description: { type: "Data", label: "Description" },
    },
    columns: ["item_id", "qty", "uom_id", "description"],
});

/** ERPNext Product Bundle. Submit makes this the active bundle for the parent item. */
export const productBundle = defineDoctype<"product_bundle", "items">({
    doctype: "Product Bundle",
    table: "product_bundle",
    module: "selling",
    slug: "product-bundle",
    titleField: "name",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        new_item_id: { type: "Link", label: "Parent Item", target: "Item", required: true },
        description: { type: "Text", label: "Description" },
        is_active: { type: "Check", label: "Active", default: true },
        disabled: { type: "Check", label: "Disabled" },
        items: { type: "Table", label: "Items", target: "Product Bundle Item" },
    },
    children: { items: productBundleItem },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["new_item_id", "description"],
                        ["name", "is_active", "disabled"],
                    ],
                },
                { label: "Items", columns: [["items"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "new_item_id", "is_active", "disabled"],
        searchFields: ["name"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "new_item_id",
        product_bundle_stock: "new_item_id",
        product_bundle_asset: "new_item_id",
        product_bundle_qty: "items",
        product_bundle_child: "items",
        product_bundle_uom: "items",
    },
});
