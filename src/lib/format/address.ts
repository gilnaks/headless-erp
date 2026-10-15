/** The Address fields the display templates read. */
export type AddressParts = {
    address_line1?: string | null;
    address_line2?: string | null;
    city?: string | null;
    county?: string | null;
    state?: string | null;
    pincode?: string | null;
    country?: string | null;
    phone?: string | null;
    fax?: string | null;
    email_id?: string | null;
};

type Template = (a: Required<{ [K in keyof AddressParts]: string }>) => string[];

/** `{{ pincode }} {{ city | upper }}` / `{{ country | upper }}`: shared by most European templates. */
const postcodeFirst: Template = (a) => [
    a.address_line1,
    a.address_line2,
    `${a.pincode} ${a.city.toUpperCase()}`.trim(),
    a.country.toUpperCase(),
];

/**
 * ERPNext regional Address Templates (erpnext/regional/address_template/templates/<country>.html), keyed by the
 * lower-cased country name.
 */
const TEMPLATES: Record<string, Template> = {
    "bosnia and herzegovina": postcodeFirst,
    croatia: postcodeFirst,
    denmark: postcodeFirst,
    germany: postcodeFirst,
    sweden: postcodeFirst,
    switzerland: postcodeFirst,
    luxembourg: (a) => [
        a.address_line1,
        a.address_line2,
        `${a.pincode ? `L-${a.pincode}` : ""}${a.city ? ` ${a.city}` : ""}`.trim(),
        a.country.toUpperCase(),
    ],
    taiwan: (a) => [
        a.country,
        a.pincode,
        `${a.county}${a.city}${a.address_line1}${a.address_line2}`,
        a.phone && `Phone: ${a.phone}`,
        a.fax && `Fax: ${a.fax}`,
        a.email_id && `Email: ${a.email_id}`,
    ],
    "united states": (a) => [
        a.address_line1,
        a.address_line2,
        [a.city, [a.state, a.pincode].filter(Boolean).join(" ")].filter(Boolean).join(", "),
        a.country === "United States" ? "" : a.country,
    ],
};

/** Frappe's default Address Template (frappe/contacts/doctype/address_template/address_template.py). */
const DEFAULT_TEMPLATE: Template = (a) => [
    a.address_line1,
    a.address_line2,
    a.city,
    a.state,
    a.pincode,
    a.country,
    a.phone && `Phone: ${a.phone}`,
    a.fax && `Fax: ${a.fax}`,
    a.email_id && `Email: ${a.email_id}`,
];

/**
 * Frappe `get_address_display`: the address as display lines, using the template of its country (the default
 * template otherwise). Empty lines are dropped; join with `<br>` / newlines to render.
 */
export function formatAddress(address: AddressParts): string[] {
    const a = {
        address_line1: "",
        address_line2: "",
        city: "",
        county: "",
        state: "",
        pincode: "",
        country: "",
        phone: "",
        fax: "",
        email_id: "",
    };
    for (const key of Object.keys(a) as (keyof typeof a)[]) a[key] = (address[key] ?? "").trim();
    const template = TEMPLATES[a.country.toLowerCase()] ?? DEFAULT_TEMPLATE;
    return template(a).filter((line) => line.length > 0);
}
