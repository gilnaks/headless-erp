import { z } from "zod";
import type { ChildDoctype, Doctype, FieldDef, FieldValues } from "./define";

/**
 * Form values are input-shaped: text-like and numeric fields are strings ("" = empty), Check is boolean, MultiSelect
 * is an array of strings, Table is an array of row objects. `schemaFor` validates that shape (client resolver and Server Action share it) and
 * `formToPayload` converts it to the jsonb sent to `app.save_doc`.
 */

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const NUMBER = /^-?\d+(\.\d+)?$/;
const INT = /^-?\d+$/;
const COLOR = /^#[0-9a-f]{6}$/i;

const NUMERIC_TYPES = new Set(["Int", "Float", "Currency", "Percent"]);
const ARRAY_TYPES = new Set(["Table", "MultiSelect"]);

function stringItems(value: unknown): string[] {
    return Array.isArray(value) ? value.filter((v): v is string => typeof v === "string" && v.trim() !== "").map((v) => v.trim()) : [];
}

function isEmpty(value: unknown): boolean {
    return value === undefined || value === null || value === "";
}

function valueSchema(field: FieldDef): z.ZodType {
    switch (field.type) {
        case "Check":
            return z.boolean();
        case "Table":
            return z.array(z.record(z.string(), z.unknown()));
        case "MultiSelect": {
            const items = z.array(z.string());
            if (!Array.isArray(field.options)) return items;
            const options = field.options as readonly string[];
            return items.refine((vs) => vs.every((v) => options.includes(v)), `${field.label} must be among: ${options.join(", ")}`);
        }
        case "Int":
            return z.string().regex(INT, `${field.label} must be a whole number`).or(z.literal(""));
        case "Float":
        case "Currency":
        case "Percent":
            return z.string().regex(NUMBER, `${field.label} must be a number`).or(z.literal(""));
        case "Link":
            if (field.target === "Role") return z.string();
            return z
                .string()
                .regex(UUID, `Select a valid ${field.target ?? field.label}`)
                .or(z.literal(""));
        case "DynamicLink":
            return z
                .string()
                .regex(UUID, `Select a valid ${field.target ?? field.label}`)
                .or(z.literal(""));
        case "Date":
            return z.string().regex(DATE, `${field.label} must be a date (YYYY-MM-DD)`).or(z.literal(""));
        case "Color":
            return z.string().regex(COLOR, `${field.label} must be a colour like #3366ff`).or(z.literal(""));
        case "Select":
            if (Array.isArray(field.options)) {
                const options = field.options as readonly string[];
                return z
                    .string()
                    .refine((v) => v === "" || options.includes(v), `${field.label} must be one of: ${options.filter(Boolean).join(", ")}`);
            }
            return z.string();
        default:
            return z.string();
    }
}

function objectSchema(fields: Record<string, FieldDef>, extra: Record<string, z.ZodType> = {}) {
    const shape: Record<string, z.ZodType> = { ...extra };
    for (const [name, field] of Object.entries(fields)) {
        shape[name] = field.readOnly ? z.unknown().optional() : valueSchema(field);
    }
    return z.object(shape).superRefine((values, ctx) => {
        for (const [name, field] of Object.entries(fields)) {
            if (!field.required || field.readOnly) continue;
            if (field.dependsOn && !field.dependsOn(values)) continue;
            const value = values[name];
            const missing = ARRAY_TYPES.has(field.type) ? !Array.isArray(value) || value.length === 0 : isEmpty(value);
            if (missing) ctx.addIssue({ code: "custom", path: [name], message: `${field.label} is required` });
        }
    });
}

export function childSchemaFor(child: ChildDoctype) {
    return objectSchema(child.fields, { id: z.string().optional() });
}

export function schemaFor(d: Doctype) {
    const childSchemas = Object.fromEntries(Object.entries(d.children).map(([name, child]) => [name, z.array(childSchemaFor(child))]));
    const base = objectSchema(d.fields);
    const schema = Object.keys(childSchemas).length ? base.and(z.object(childSchemas)) : base;
    const { validate } = d;
    if (!validate) return schema;
    return schema.superRefine((values, ctx) => {
        for (const [path, message] of Object.entries(validate(values as FieldValues)))
            ctx.addIssue({ code: "custom", path: [path], message });
    });
}

function toInput(field: FieldDef, value: unknown): unknown {
    if (field.type === "Check") return isEmpty(value) ? Boolean(field.default) : Boolean(value);
    if (field.type === "Table") return Array.isArray(value) ? value : [];
    if (field.type === "MultiSelect") return stringItems(value);
    if (field.type === "Password") return "";
    if (isEmpty(value)) return field.default === undefined ? "" : String(field.default);
    return String(value);
}

function rowToInput(fields: Record<string, FieldDef>, row: FieldValues | undefined): FieldValues {
    const out: FieldValues = {};
    for (const [name, field] of Object.entries(fields)) out[name] = toInput(field, row?.[name]);
    return out;
}

/** Form default values from a stored row (or ERPNext defaults for a new document). */
export function formValuesFor(d: Doctype, row?: FieldValues): FieldValues {
    const values = rowToInput(d.fields, row);
    for (const [name, child] of Object.entries(d.children)) {
        const rows = Array.isArray(row?.[name]) ? (row?.[name] as FieldValues[]) : [];
        values[name] = rows.map((r) => ({ ...(r.id ? { id: String(r.id) } : {}), ...rowToInput(child.fields, r) }));
    }
    return values;
}

function queryValue(field: FieldDef, raw: string | string[] | undefined): unknown {
    const value = Array.isArray(raw) ? raw[0] : raw;
    if (value === undefined || field.readOnly || field.type === "Password" || ARRAY_TYPES.has(field.type)) return undefined;
    return field.type === "Check" ? value === "1" || value === "true" : value;
}

/**
 * Values for a new document from the URL query (Frappe `frappe.route_options`, e.g. `?user_id=<id>`): editable,
 * non-table fields, plus one row per Table from `<table>.<field>` keys (`?links.link_doctype=Company&links.link_id=<id>`);
 * null when nothing applies.
 */
export function prefillValues(
    d: Pick<Doctype, "fields"> & Partial<Pick<Doctype, "children">>,
    query: Record<string, string | string[] | undefined>,
): FieldValues | null {
    const row: FieldValues = {};
    for (const [name, field] of Object.entries(d.fields)) {
        const value = queryValue(field, query[name]);
        if (value !== undefined) row[name] = value;
    }
    for (const [name, child] of Object.entries(d.children ?? {})) {
        const seeded: FieldValues = {};
        for (const [column, field] of Object.entries(child.fields)) {
            const value = queryValue(field, query[`${name}.${column}`]);
            if (value !== undefined) seeded[column] = value;
        }
        if (Object.keys(seeded).length) row[name] = [{ ...newChildRow(child), ...seeded }];
    }
    return Object.keys(row).length ? row : null;
}

/** A blank child row with ERPNext defaults. */
export function newChildRow(child: ChildDoctype): FieldValues {
    return rowToInput(child.fields, undefined);
}

function toPayload(field: FieldDef, value: unknown): unknown {
    if (field.type === "Check") return Boolean(value);
    if (field.type === "MultiSelect") return [...new Set(stringItems(value))];
    if (isEmpty(value)) return null;
    if (NUMERIC_TYPES.has(field.type)) return Number(value);
    return typeof value === "string" ? value.trim() : value;
}

function rowToPayload(fields: Record<string, FieldDef>, values: FieldValues, isNew: boolean): FieldValues {
    const out: FieldValues = {};
    for (const [name, field] of Object.entries(fields)) {
        if (field.readOnly || field.type === "Table" || field.type === "Password" || !(name in values)) continue;
        if (field.setOnlyOnce && !isNew) continue;
        out[name] = toPayload(field, values[name]);
    }
    return out;
}

/** Validated form values -> `app.save_doc` payload (read-only and Password fields dropped, "" -> null, numbers parsed). */
export function formToPayload(d: Doctype, values: FieldValues, options: { isNew: boolean }): FieldValues {
    const payload = rowToPayload(d.fields, values, options.isNew);
    for (const [name, child] of Object.entries(d.children)) {
        const rows = Array.isArray(values[name]) ? (values[name] as FieldValues[]) : [];
        payload[name] = rows.map((r) => ({
            ...(typeof r.id === "string" && UUID.test(r.id) ? { id: r.id } : {}),
            ...rowToPayload(child.fields, r, true),
        }));
    }
    return payload;
}
