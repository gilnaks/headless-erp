import { defineDoctype } from "../define";

/** ERPNext Branch (erpnext/setup/doctype/branch): a single unique name (docs/modules/00-setup.md §2.2). */
export const branch = defineDoctype({
    doctype: "Branch",
    table: "branch",
    module: "setup",
    slug: "branch",
    titleField: "branch",
    fields: {
        branch: { type: "Data", label: "Branch", required: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["branch"]] }] }],
    listView: { columns: ["branch"], searchFields: ["branch"], defaultSort: { field: "branch" } },
    errorFields: { duplicate: "branch" },
});
