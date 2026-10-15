import { importUoms } from "@/lib/actions/stock/uom";
import { defineDoctype } from "../define";

/** ERPNext UOM (erpnext/setup/doctype/uom). Curated seed is A19; "Import all UOMs" copies the global template. */
export const uom = defineDoctype({
    doctype: "UOM",
    table: "uom",
    module: "stock",
    slug: "uom",
    titleField: "uom_name",
    fields: {
        uom_name: { type: "Data", label: "UOM Name", required: true },
        must_be_whole_number: { type: "Check", label: "Must be Whole Number" },
        enabled: { type: "Check", label: "Enabled", default: true },
        symbol: { type: "Data", label: "Symbol" },
        common_code: { type: "Data", label: "Common Code" },
        description: { type: "Text", label: "Description" },
        category_id: { type: "Link", label: "UOM Category", target: "UOM Category" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["uom_name", "category_id", "must_be_whole_number", "enabled"],
                        ["symbol", "common_code", "description"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["uom_name", "category_id", "must_be_whole_number", "enabled"],
        searchFields: ["uom_name"],
        defaultSort: { field: "uom_name" },
    },
    actions: [
        {
            id: "import-uoms",
            label: "Import all UOMs",
            run: async (_values, { orgSlug, notify }) => {
                const count = await importUoms(orgSlug);
                notify(`This organization now has ${count} units of measure.`);
                return {};
            },
        },
    ],
    errorFields: { duplicate: "uom_name" },
});
