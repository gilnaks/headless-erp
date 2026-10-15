import { defineDoctype } from "../define";

/** Org-level conversion copied from ERPNext's uom_conversion_data. An item row wins when both exist. */
export const uomConversionFactor = defineDoctype({
    doctype: "UOM Conversion Factor",
    table: "uom_conversion_factor",
    module: "stock",
    slug: "uom-conversion-factor",
    titleField: "from_uom",
    fields: {
        category: { type: "Data", label: "Category" },
        from_uom: { type: "Data", label: "From", required: true },
        to_uom: { type: "Data", label: "To", required: true },
        value: { type: "Float", label: "Value", required: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["from_uom", "to_uom", "value", "category"]] }] }],
    listView: {
        columns: ["from_uom", "to_uom", "value", "category"],
        searchFields: ["from_uom", "to_uom"],
        defaultSort: { field: "from_uom" },
    },
    errorFields: { duplicate: "from_uom" },
});
