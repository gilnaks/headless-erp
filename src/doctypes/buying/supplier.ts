import { defineChildDoctype, defineDoctype } from "../define";

export const supplierPartyAccount = defineChildDoctype({
    doctype: "Supplier Party Account",
    table: "supplier_party_account",
    fields: {
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        account_id: { type: "Link", label: "Account", target: "Account" },
    },
    columns: ["company_id", "account_id"],
});

/** ERPNext Supplier. The name is the supplier name; a duplicate name is rejected. */
export const supplier = defineDoctype<"supplier", "accounts">({
    doctype: "Supplier",
    table: "supplier",
    module: "buying",
    slug: "supplier",
    titleField: "name",
    addressContact: true,
    fields: {
        supplier_name: { type: "Data", label: "Supplier Name", required: true },
        name: { type: "Data", label: "Name", readOnly: true },
        supplier_group_id: { type: "Link", label: "Supplier Group", target: "Supplier Group" },
        supplier_type: {
            type: "Select",
            label: "Supplier Type",
            options: ["Company", "Individual", "Partnership"],
            default: "Company",
            required: true,
        },
        country: { type: "Select", label: "Country", options: "Country" },
        tax_id: { type: "Data", label: "Tax ID" },
        tax_category_id: { type: "Link", label: "Tax Category", target: "Tax Category" },
        default_currency: { type: "Select", label: "Billing Currency", options: "Currency" },
        default_price_list_id: { type: "Link", label: "Default Price List", target: "Price List" },
        payment_terms_id: { type: "Link", label: "Default Payment Terms Template", target: "Payment Terms Template" },
        supplier_primary_contact: { type: "Link", label: "Primary Contact", target: "Contact" },
        supplier_primary_address: { type: "Link", label: "Primary Address", target: "Address" },
        language: { type: "Data", label: "Print Language" },
        website: { type: "Data", label: "Website" },
        supplier_details: { type: "Text", label: "Supplier Details" },
        is_transporter: { type: "Check", label: "Is Transporter" },
        disabled: { type: "Check", label: "Disabled" },
        is_frozen: { type: "Check", label: "Is Frozen" },
        on_hold: { type: "Check", label: "Hold" },
        hold_type: { type: "Select", label: "Hold Type", options: ["", "All", "Invoices", "Payments"] },
        release_date: { type: "Date", label: "Release Date" },
        allow_purchase_invoice_creation_without_purchase_order: {
            type: "Check",
            label: "Allow Purchase Invoice Creation Without Purchase Order",
        },
        allow_purchase_invoice_creation_without_purchase_receipt: {
            type: "Check",
            label: "Allow Purchase Invoice Creation Without Purchase Receipt",
        },
        alias: { type: "Data", label: "Alias" },
        warn_rfqs: { type: "Check", label: "Warn RFQs", readOnly: true },
        prevent_rfqs: { type: "Check", label: "Prevent RFQs", readOnly: true },
        warn_pos: { type: "Check", label: "Warn POs", readOnly: true },
        prevent_pos: { type: "Check", label: "Prevent POs", readOnly: true },
        accounts: { type: "Table", label: "Accounts", target: "Supplier Party Account" },
    },
    children: { accounts: supplierPartyAccount },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["supplier_name", "supplier_group_id", "supplier_type", "country", "tax_id", "tax_category_id"],
                        [
                            "name",
                            "default_currency",
                            "default_price_list_id",
                            "payment_terms_id",
                            "supplier_primary_contact",
                            "supplier_primary_address",
                            "website",
                            "is_transporter",
                        ],
                    ],
                },
                { columns: [["supplier_details", "language", "alias", "disabled", "is_frozen"]] },
            ],
        },
        {
            label: "Settings",
            sections: [
                {
                    columns: [
                        ["on_hold", "hold_type", "release_date"],
                        [
                            "allow_purchase_invoice_creation_without_purchase_order",
                            "allow_purchase_invoice_creation_without_purchase_receipt",
                        ],
                    ],
                },
                { columns: [["warn_rfqs", "prevent_rfqs", "warn_pos", "prevent_pos"]] },
                { label: "Accounts", columns: [["accounts"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "supplier_group_id", "country", "disabled"],
        searchFields: ["name", "supplier_name", "tax_id"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "supplier_name",
        supplier_group_leaf: "supplier_group_id",
        supplier_price_list: "default_price_list_id",
        supplier_primary_link: "supplier_primary_contact",
        party_account_type: "accounts",
        party_account_missing: "accounts",
    },
});
