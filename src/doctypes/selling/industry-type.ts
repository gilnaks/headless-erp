import { defineDoctype } from "../define";

/** ERPNext Industry Type. Not seeded; add rows before they can be picked on a customer. */
export const industryType = defineDoctype({
    doctype: "Industry Type",
    table: "industry_type",
    module: "selling",
    slug: "industry-type",
    titleField: "industry",
    fields: {
        industry: { type: "Data", label: "Industry", required: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["industry"]] }] }],
    listView: {
        columns: ["industry"],
        searchFields: ["industry"],
        defaultSort: { field: "industry" },
    },
    errorFields: { duplicate: "industry" },
});
