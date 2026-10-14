import { z } from "zod";

/** Mirrors the `organizations.slug` check constraint. */
export const SLUG_PATTERN = /^[a-z0-9-]{3,40}$/;

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

export const createOrganizationSchema = z.object({
    name: z.string().trim().min(1, "Enter the organization name").max(140),
    slug: z.string().trim().toLowerCase().regex(SLUG_PATTERN, "Use 3–40 lowercase letters, digits or dashes"),
    country: z.string().trim().min(1, "Select a country"),
    default_currency: z
        .string()
        .trim()
        .toUpperCase()
        .regex(/^[A-Z]{3}$/, "Select a currency"),
    time_zone: z.string().trim().min(1, "Select a time zone"),
});

export type CreateOrganizationInput = z.input<typeof createOrganizationSchema>;
