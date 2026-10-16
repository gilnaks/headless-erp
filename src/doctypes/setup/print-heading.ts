import { defineDoctype } from "../define";

/** Print Heading fixture (A15): Credit Note and Debit Note. The name copies the heading. */
export const printHeading = defineDoctype({
    doctype: "Print Heading",
    table: "print_heading",
    module: "setup",
    slug: "print-heading",
    titleField: "name",
    fields: {
        print_heading: { type: "Data", label: "Print Heading", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        description: { type: "Text", label: "Description" },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["print_heading", "name", "description"]] }] }],
    listView: {
        columns: ["name", "description"],
        searchFields: ["name", "print_heading"],
        defaultSort: { field: "name" },
    },
    errorFields: { duplicate: "print_heading" },
});
