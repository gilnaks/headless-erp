import { defineDoctype } from "../define";

/** Party Type fixture (A13): Customer is Receivable, Supplier is Payable. Read-only. */
export const partyType = defineDoctype({
    doctype: "Party Type",
    table: "party_type",
    module: "accounts",
    slug: "party-type",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Party Type", required: true },
        account_type: { type: "Select", label: "Account Type", options: ["Receivable", "Payable"], required: true },
    },
    tabs: [{ label: "Details", sections: [{ columns: [["name", "account_type"]] }] }],
    listView: {
        columns: ["name", "account_type"],
        searchFields: ["name"],
        defaultSort: { field: "name" },
    },
    errorFields: { duplicate: "name" },
});
