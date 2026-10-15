/**
 * Email Template placeholders: a small handlebars subset instead of Frappe's Jinja (00-setup §2.15).
 *
 *   {{doc.customer_name}}  {{doc.items[0].item_code}}  {{company.company_name}}  {{user.full_name}}
 *   {{money doc.grand_total}}  {{date doc.posting_date}}  {{qty doc.items[0].qty}}
 *
 * Roots are `doc`, `company` and `user`. Missing values render as "". In HTML output every value is escaped, so
 * a template can never inject markup through a field. Pure and dependency-free: used by the form preview (client)
 * and by sending (server).
 */

export type TemplateContext = {
    doc?: Record<string, unknown>;
    company?: Record<string, unknown>;
    user?: Record<string, unknown>;
};

const ROOTS = new Set(["doc", "company", "user"]);
const HELPERS = ["money", "date", "qty"] as const;
type Helper = (typeof HELPERS)[number];

type Segment = string | number;
type Part = { text: string } | { helper: Helper | null; path: Segment[]; source: string };

export type CompileResult = { ok: true; parts: Part[] } | { ok: false; error: string };

const PATH = /^[a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*|\[\d+\])*$/i;

function parsePath(expr: string): Segment[] | null {
    if (!PATH.test(expr)) return null;
    const segments: Segment[] = [];
    for (const match of expr.matchAll(/([a-z_][a-z0-9_]*)|\[(\d+)\]/gi)) {
        segments.push(match[1] ?? Number(match[2]));
    }
    return segments;
}

function compileExpression(source: string): Part | string {
    const tokens = source.trim().split(/\s+/).filter(Boolean);
    if (tokens.length === 0) return "Empty placeholder {{ }}";
    if (tokens.length > 2) return `Unsupported placeholder {{${source}}}`;
    const [first, second] = tokens;
    if (tokens.length === 2 && !HELPERS.includes(first as Helper)) {
        return `Unknown helper "${first}" in {{${source.trim()}}} (use ${HELPERS.join(", ")})`;
    }
    const pathSource = tokens.length === 2 ? second : first;
    const path = parsePath(pathSource);
    if (!path) return `Invalid placeholder {{${source.trim()}}}`;
    if (!ROOTS.has(String(path[0]))) return `Unknown value "${path[0]}" in {{${source.trim()}}} (use doc, company or user)`;
    return { helper: tokens.length === 2 ? (first as Helper) : null, path, source: source.trim() };
}

/** Parses a template; errors name the offending placeholder (shown on the field when saving). */
export function compileTemplate(source: string): CompileResult {
    const parts: Part[] = [];
    let rest = source;
    while (rest.length) {
        const open = rest.indexOf("{{");
        const close = rest.indexOf("}}");
        if (close !== -1 && (open === -1 || close < open)) return { ok: false, error: 'Unmatched "}}"' };
        if (open === -1) {
            parts.push({ text: rest });
            break;
        }
        if (open > 0) parts.push({ text: rest.slice(0, open) });
        const end = rest.indexOf("}}", open + 2);
        if (end === -1) return { ok: false, error: 'Unclosed "{{"' };
        const inner = rest.slice(open + 2, end);
        if (inner.includes("{{")) return { ok: false, error: 'Unclosed "{{"' };
        const part = compileExpression(inner);
        if (typeof part === "string") return { ok: false, error: part };
        parts.push(part);
        rest = rest.slice(end + 2);
    }
    return { ok: true, parts };
}

function lookup(context: TemplateContext, path: Segment[]): unknown {
    let value: unknown = context;
    for (const segment of path) {
        if (value === null || typeof value !== "object") return undefined;
        value = (value as Record<string | number, unknown>)[segment];
    }
    return value;
}

function toNumber(value: unknown): number | null {
    if (typeof value === "number") return Number.isFinite(value) ? value : null;
    if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) return Number(value);
    return null;
}

export type RenderOptions = {
    /** HTML output escapes every value (bodies); plain text does not (subjects, text bodies). */
    html?: boolean;
    /** Currency for `money` when the document has none (else `doc.currency`, then `company.default_currency`). */
    currency?: string;
    locale?: string;
};

function formatMoney(value: unknown, currency: string | undefined, locale: string): string {
    const n = toNumber(value);
    if (n === null) return "";
    const options: Intl.NumberFormatOptions = { minimumFractionDigits: 2, maximumFractionDigits: 2 };
    try {
        return new Intl.NumberFormat(locale, currency ? { ...options, style: "currency", currency } : options).format(n);
    } catch {
        return new Intl.NumberFormat(locale, options).format(n);
    }
}

function formatDate(value: unknown, locale: string): string {
    if (typeof value !== "string" || !value) return "";
    const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
    if (!match) return value;
    const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
    return new Intl.DateTimeFormat(locale, { year: "numeric", month: "short", day: "numeric", timeZone: "UTC" }).format(date);
}

function formatQty(value: unknown, locale: string): string {
    const n = toNumber(value);
    return n === null ? "" : new Intl.NumberFormat(locale, { maximumFractionDigits: 6 }).format(n);
}

function plain(value: unknown): string {
    if (value === null || value === undefined || typeof value === "object") return "";
    if (typeof value === "boolean") return value ? "Yes" : "No";
    return String(value);
}

export function escapeHtml(value: string): string {
    return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

/** Renders a template; throws when it does not compile (templates are validated when saved). */
export function renderTemplate(source: string, context: TemplateContext, options: RenderOptions = {}): string {
    const compiled = compileTemplate(source);
    if (!compiled.ok) throw new Error(compiled.error);
    const locale = options.locale ?? "en-US";
    const currency =
        (typeof context.doc?.currency === "string" && context.doc.currency) ||
        options.currency ||
        (typeof context.company?.default_currency === "string" ? context.company.default_currency : undefined) ||
        undefined;
    return compiled.parts
        .map((part) => {
            if ("text" in part) return part.text;
            const value = lookup(context, part.path);
            const text =
                part.helper === "money"
                    ? formatMoney(value, currency, locale)
                    : part.helper === "date"
                      ? formatDate(value, locale)
                      : part.helper === "qty"
                        ? formatQty(value, locale)
                        : plain(value);
            return options.html ? escapeHtml(text) : text;
        })
        .join("");
}

/** Field-level check for forms: the compile error, or null. */
export function templateError(source: unknown): string | null {
    if (typeof source !== "string" || !source) return null;
    const compiled = compileTemplate(source);
    return compiled.ok ? null : compiled.error;
}
