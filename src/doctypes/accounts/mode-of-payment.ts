import { defineChildDoctype, defineDoctype } from "../define";

export const modeOfPaymentAccount = defineChildDoctype({
    doctype: "Mode of Payment Account",
    table: "mode_of_payment_account",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        default_account_id: { type: "Link", label: "Default Account", target: "Account" },
    },
    columns: ["company_id", "default_account_id"],
});

/** ERPNext Mode of Payment. Cash is pointed at the company cash account (B10). */
export const modeOfPayment = defineDoctype<"mode_of_payment", "accounts">({
    doctype: "Mode of Payment",
    table: "mode_of_payment",
    module: "accounts",
    slug: "mode-of-payment",
    titleField: "name",
    fields: {
        mode_of_payment: { type: "Data", label: "Mode of Payment", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        enabled: { type: "Check", label: "Enabled", default: true },
        type: { type: "Select", label: "Type", options: ["", "Cash", "Bank", "General", "Phone"] },
        accounts: { type: "Table", label: "Accounts", target: "Mode of Payment Account" },
    },
    children: { accounts: modeOfPaymentAccount },
    tabs: [
        {
            label: "Details",
            sections: [{ columns: [["mode_of_payment", "type", "enabled"], ["name"]] }, { label: "Accounts", columns: [["accounts"]] }],
        },
    ],
    listView: {
        columns: ["name", "type", "enabled"],
        searchFields: ["name", "mode_of_payment"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "mode_of_payment",
        mode_of_payment_account: "accounts",
        mode_of_payment_company: "accounts",
    },
});
