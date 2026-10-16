import { defineChildDoctype, defineDoctype } from "../define";

/** Parties an Address or Contact can link to (`address_link_doctype_check` / `contact_link_doctype_check`). */
export const LINK_DOCTYPES = ["Company"] as const;

/** Frappe Dynamic Link row of an Address (our `address_link`; §2.19 deviation: one link table per parent). */
export const addressLink = defineChildDoctype({
    doctype: "Address Link",
    table: "address_link",
    fields: {
        link_doctype: { type: "Select", label: "Link Document Type", required: true, options: LINK_DOCTYPES },
        link_id: { type: "DynamicLink", label: "Link Name", required: true, optionsField: "link_doctype" },
    },
    columns: ["link_doctype", "link_id"],
});

/**
 * Frappe Address + ERPNext `accounts/custom/address.py` (§2.19). Naming (`<title>-<type>`), the company-address
 * flag and the primary / shipping "unset the others" rule run in the database (`app.address_refresh`, 0121).
 */
export const address = defineDoctype<"address", "links">({
    doctype: "Address",
    table: "address",
    module: "setup",
    slug: "address",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Address Name", readOnly: true },
        address_title: {
            type: "Data",
            label: "Address Title",
            description: "Defaults to the first linked record.",
        },
        address_type: {
            type: "Select",
            label: "Address Type",
            required: true,
            default: "Billing",
            options: [
                "Billing",
                "Shipping",
                "Office",
                "Personal",
                "Plant",
                "Postal",
                "Shop",
                "Subsidiary",
                "Warehouse",
                "Current",
                "Permanent",
                "Other",
            ],
        },
        address_line1: { type: "Data", label: "Address Line 1", required: true },
        address_line2: { type: "Data", label: "Address Line 2" },
        city: { type: "Data", label: "City/Town", required: true },
        county: { type: "Data", label: "County" },
        state: { type: "Data", label: "State/Province" },
        country: {
            type: "Select",
            label: "Country",
            options: "Country",
            description: "Defaults to the organization's country.",
        },
        pincode: { type: "Data", label: "Postal Code" },
        tax_category_id: { type: "Link", label: "Tax Category", target: "Tax Category" },
        email_id: { type: "Data", label: "Email Address" },
        phone: { type: "Data", label: "Phone" },
        fax: { type: "Data", label: "Fax" },
        is_primary_address: { type: "Check", label: "Preferred Billing Address" },
        is_shipping_address: { type: "Check", label: "Preferred Shipping Address" },
        disabled: { type: "Check", label: "Disabled" },
        is_your_company_address: {
            type: "Check",
            label: "Is Your Company Address",
            description: "Set automatically when the address is linked to a Company.",
        },
        links: { type: "Table", label: "Links", target: "Address Link" },
    },
    children: { links: addressLink },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        [
                            "address_title",
                            "address_type",
                            "address_line1",
                            "address_line2",
                            "city",
                            "county",
                            "state",
                            "country",
                            "pincode",
                            "tax_category_id",
                        ],
                        ["name", "email_id", "phone", "fax", "is_primary_address", "is_shipping_address", "disabled"],
                    ],
                },
                { label: "Reference", columns: [["links"], ["is_your_company_address"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "address_type", "city", "country"],
        searchFields: ["name", "address_title", "city"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "name",
        address_title_required: "address_title",
        address_company_link: "links",
        link_invalid: "links",
    },
});
