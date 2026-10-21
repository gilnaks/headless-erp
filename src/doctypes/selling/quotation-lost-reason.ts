import { defineDoctype } from "../define";

/** ERPNext Quotation Lost Reason. Not seeded; Sales Manager adds a row before Set as Lost. */
export const quotationLostReason = defineDoctype({
    doctype: "Quotation Lost Reason",
    table: "quotation_lost_reason",
    module: "selling",
    slug: "quotation-lost-reason",
    titleField: "order_lost_reason",
    fields: {
        order_lost_reason: { type: "Data", label: "Quotation Lost Reason", required: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["order_lost_reason"]] }] }],
    listView: {
        columns: ["order_lost_reason"],
        searchFields: ["order_lost_reason"],
        defaultSort: { field: "order_lost_reason" },
    },
    errorFields: { duplicate: "order_lost_reason" },
});
