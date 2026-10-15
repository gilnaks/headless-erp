import { defineChildDoctype, defineDoctype } from "../define";
import { LINK_DOCTYPES } from "./address";

/** Frappe Contact Email (frappe/contacts/doctype/contact_email). */
export const contactEmail = defineChildDoctype({
    doctype: "Contact Email",
    table: "contact_email",
    fields: {
        email_id: { type: "Data", label: "Email ID", required: true },
        is_primary: { type: "Check", label: "Is Primary" },
    },
    columns: ["email_id", "is_primary"],
});

/** Frappe Contact Phone (frappe/contacts/doctype/contact_phone). */
export const contactPhone = defineChildDoctype({
    doctype: "Contact Phone",
    table: "contact_phone",
    fields: {
        phone: { type: "Data", label: "Number", required: true },
        is_primary_phone: { type: "Check", label: "Is Primary Phone" },
        is_primary_mobile_no: { type: "Check", label: "Is Primary Mobile" },
    },
    columns: ["phone", "is_primary_phone", "is_primary_mobile_no"],
});

/** Frappe Dynamic Link row of a Contact (our `contact_link`; §2.20). */
export const contactLink = defineChildDoctype({
    doctype: "Contact Link",
    table: "contact_link",
    fields: {
        link_doctype: { type: "Select", label: "Link Document Type", required: true, options: LINK_DOCTYPES },
        link_id: { type: "DynamicLink", label: "Link Name", required: true, optionsField: "link_doctype" },
    },
    columns: ["link_doctype", "link_id"],
});

/**
 * Frappe Contact + ERPNext `is_billing_contact` (§2.20). Full name, naming, the primary email / phone / mobile and the
 * user match run in the database (`app.contact_refresh`, 0122).
 */
export const contact = defineDoctype<"contact", "email_ids" | "phone_nos" | "links">({
    doctype: "Contact",
    table: "contact",
    module: "setup",
    slug: "contact",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Contact Name", readOnly: true },
        first_name: { type: "Data", label: "First Name", required: true },
        middle_name: { type: "Data", label: "Middle Name" },
        last_name: { type: "Data", label: "Last Name" },
        full_name: { type: "Data", label: "Full Name", readOnly: true },
        email_id: { type: "Data", label: "Email Address", readOnly: true },
        user_id: {
            type: "Link",
            label: "User Id",
            target: "User",
            description: "Set automatically for a member with the primary email.",
        },
        address_id: { type: "Link", label: "Address", target: "Address" },
        status: { type: "Select", label: "Status", required: true, default: "Passive", options: ["Passive", "Open", "Replied"] },
        salutation: { type: "Data", label: "Salutation" },
        designation_id: { type: "Link", label: "Designation", target: "Designation" },
        gender: {
            type: "Select",
            label: "Gender",
            options: ["Male", "Female", "Other", "Transgender", "Genderqueer", "Non-Conforming", "Prefer not to say"],
        },
        phone: { type: "Data", label: "Phone", readOnly: true },
        mobile_no: { type: "Data", label: "Mobile No", readOnly: true },
        company_name: { type: "Data", label: "Company Name" },
        image: { type: "AttachImage", label: "Image", folder: "contact" },
        email_ids: { type: "Table", label: "Email IDs", target: "Contact Email" },
        phone_nos: { type: "Table", label: "Contact Numbers", target: "Contact Phone" },
        links: { type: "Table", label: "Links", target: "Contact Link" },
        is_primary_contact: { type: "Check", label: "Is Primary Contact" },
        is_billing_contact: { type: "Check", label: "Is Billing Contact" },
        department: { type: "Data", label: "Department" },
        unsubscribed: { type: "Check", label: "Unsubscribed" },
    },
    children: { email_ids: contactEmail, phone_nos: contactPhone, links: contactLink },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["first_name", "middle_name", "last_name", "full_name", "name", "email_id", "user_id", "address_id"],
                        ["status", "salutation", "designation_id", "gender", "phone", "mobile_no", "company_name", "image"],
                    ],
                },
                { label: "Contact Details", columns: [["email_ids"], ["phone_nos"]] },
                {
                    label: "Reference",
                    columns: [["links"], ["is_primary_contact", "is_billing_contact", "department", "unsubscribed"]],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "email_id", "mobile_no", "is_primary_contact"],
        searchFields: ["name", "full_name", "email_id", "mobile_no"],
        defaultSort: { field: "name" },
    },
    errorFields: {
        duplicate: "name",
        contact_primary_email: "email_ids",
        contact_primary_phone: "phone_nos",
        contact_primary_mobile: "phone_nos",
        invalid_email: "email_ids",
        link_invalid: "links",
    },
});
