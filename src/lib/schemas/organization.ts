import { z } from "zod";

/** Mirrors the `organizations.slug` check constraint. */
export const SLUG_PATTERN = /^[a-z0-9-]{3,40}$/;

/** Top-level routes an org slug would shadow; mirrors `app.reserved_slugs()`. */
export const RESERVED_SLUGS = [
    "admin",
    "api",
    "app",
    "auth",
    "forgot-password",
    "health",
    "help",
    "invite",
    "login",
    "logout",
    "print",
    "settings",
    "setup",
    "signup",
    "static",
    "support",
    "update-password",
    "www",
] as const;

export function slugify(value: string): string {
    return value
        .normalize("NFKD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 40)
        .replace(/-+$/g, "");
}

/** setup_wizard.js `company_name` input: first letter of each word, upper-cased, at most 10 (`app.company_abbr`). */
export function companyAbbr(companyName: string): string {
    return companyName
        .split(" ")
        .map((part) => part.slice(0, 1))
        .join("")
        .slice(0, 10)
        .toUpperCase();
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Wizard step 1. */
export const organizationStepSchema = z.object({
    name: z.string().trim().min(1, "Enter the organization name").max(140),
    slug: z
        .string()
        .trim()
        .toLowerCase()
        .regex(SLUG_PATTERN, "Use 3–40 lowercase letters, digits or dashes")
        .refine((s) => !(RESERVED_SLUGS as readonly string[]).includes(s), "This URL is reserved; choose another"),
    country: z.string().trim().min(1, "Select a country"),
    default_currency: z
        .string()
        .trim()
        .toUpperCase()
        .regex(/^[A-Z]{3}$/, "Select a currency"),
    time_zone: z.string().trim().min(1, "Select a time zone"),
});

/** Wizard step 2 (setup_wizard.js organization slide `validate`). */
export const companyStepSchema = z
    .object({
        company_name: z
            .string()
            .trim()
            .min(1, "Enter the company name")
            .max(140)
            .refine((v) => v.toLowerCase() !== "company", "Please pick a company name other than Company."),
        abbr: z.string().trim().min(1, "Enter an abbreviation").max(10, "Company Abbreviation cannot have more than 10 characters"),
        fy_start_date: z.string().regex(ISO_DATE, "Please enter a valid date for when your financial year begins."),
        fy_end_date: z.string().regex(ISO_DATE, "Please enter a valid date for when your financial year begins."),
        chart_of_accounts: z.string().trim().min(1, "Select a chart of accounts"),
    })
    .refine((v) => v.fy_end_date > v.fy_start_date, {
        message: "Please enter a valid date for when your financial year begins.",
        path: ["fy_start_date"],
    });

const inviteSchema = z.object({
    email: z.string().trim().toLowerCase().pipe(z.email("Enter a valid email address")),
    role_profile: z.string().trim().min(1, "Choose a role profile"),
});

/** Wizard step 3 (optional): teammates invited with a role profile. */
export const inviteStepSchema = z
    .array(inviteSchema)
    .refine((rows) => new Set(rows.map((r) => r.email)).size === rows.length, "Each email can be invited once");

/** Payload of `app.provision_organization` (00-setup §3.1). */
export const provisionOrganizationSchema = z.object({
    org: organizationStepSchema,
    company: companyStepSchema,
    invites: inviteStepSchema,
});

export type ProvisionOrganizationInput = z.input<typeof provisionOrganizationSchema>;
