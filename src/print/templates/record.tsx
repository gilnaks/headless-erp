import type { ChildDoctype, Doctype, FieldDef, FieldValues } from "@/doctypes/define";
import { type LinkTitles, linkTitle } from "@/lib/link-titles";

export type PrintTemplateProps = {
    doctype: Doctype;
    doc: FieldValues;
    titles: LinkTitles;
    /** The company's preferred billing address lines (`app.company_address`), printed under the header. */
    companyAddress?: string[] | null;
};

const DECIMAL = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 6 });
const INTEGER = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });
const NUMERIC = new Set(["Int", "Float", "Currency", "Percent"]);

function isEmpty(value: unknown): boolean {
    return value === null || value === undefined || value === "" || (Array.isArray(value) && value.length === 0);
}

/** Display text for a stored value (Check → Yes/No, Link → the target's title, numbers grouped). */
export function formatPrintValue(field: FieldDef, value: unknown, row: FieldValues, titles: LinkTitles): string {
    if (field.type === "Check") return value ? "Yes" : "No";
    if (isEmpty(value)) return "";
    if (field.type === "Link" || field.type === "DynamicLink") return linkTitle(field, row, value, titles) ?? String(value);
    if (field.type === "MultiSelect" && Array.isArray(value)) return value.join(", ");
    if (NUMERIC.has(field.type)) {
        const n = Number(value);
        if (!Number.isFinite(n)) return String(value);
        if (field.type === "Int") return INTEGER.format(n);
        return field.type === "Percent" ? `${DECIMAL.format(n)}%` : DECIMAL.format(n);
    }
    return String(value);
}

/** Fields that print: visible (`dependsOn`), with a value, and not images (letter heads print those themselves). */
function printable(d: Doctype, name: string, doc: FieldValues): boolean {
    const field = d.fields[name];
    if (!field || field.type === "AttachImage") return false;
    if (field.dependsOn && !field.dependsOn(doc)) return false;
    if (field.type === "Table") return Array.isArray(doc[name]) && (doc[name] as unknown[]).length > 0;
    if (field.type === "Check") return true;
    return !isEmpty(doc[name]);
}

function ChildRows({ child, rows, titles }: { child: ChildDoctype; rows: FieldValues[]; titles: LinkTitles }) {
    return (
        <table className="w-full border-collapse text-left [&_td]:border-b [&_td]:border-secondary [&_td]:px-1.5 [&_td]:py-1 [&_th]:border-b [&_th]:border-primary [&_th]:px-1.5 [&_th]:py-1 [&_th]:font-medium">
            <thead>
                <tr>
                    <th className="w-8 text-right">#</th>
                    {child.columns.map((c) => (
                        <th key={c} className={NUMERIC.has(child.fields[c]?.type ?? "") ? "text-right" : undefined}>
                            {child.fields[c]?.label ?? c}
                        </th>
                    ))}
                </tr>
            </thead>
            <tbody>
                {rows.map((row, i) => (
                    <tr key={String(row.id ?? i)}>
                        <td className="text-right tabular-nums">{i + 1}</td>
                        {child.columns.map((c) => {
                            const field = child.fields[c];
                            return (
                                <td key={c} className={NUMERIC.has(field?.type ?? "") ? "text-right tabular-nums" : undefined}>
                                    {field ? formatPrintValue(field, row[c], row, titles) : String(row[c] ?? "")}
                                </td>
                            );
                        })}
                    </tr>
                ))}
            </tbody>
        </table>
    );
}

/**
 * Generic "<Doctype> Standard" template: the descriptor's tabs → sections → columns, printing only fields with a
 * value; child tables print as tables.
 */
export function RecordTemplate({ doctype: d, doc, titles, companyAddress }: PrintTemplateProps) {
    const tabs = d.tabs
        .map((tab) => ({
            label: tab.label,
            sections: tab.sections
                .map((s) => ({
                    label: s.label,
                    columns: s.columns.map((c) => c.filter((n) => printable(d, n, doc))).filter((c) => c.length),
                }))
                .filter((s) => s.columns.length),
        }))
        .filter((t) => t.sections.length);

    return (
        <div className="flex flex-col gap-5">
            {companyAddress && companyAddress.length > 0 && (
                <address data-testid="company-address" className="text-tertiary not-italic">
                    {companyAddress.map((line, i) => (
                        // biome-ignore lint/suspicious/noArrayIndexKey: address lines can repeat and never reorder
                        <span key={i} className="block">
                            {line}
                        </span>
                    ))}
                </address>
            )}
            {tabs.map((tab, ti) => (
                <section key={tab.label} className="flex flex-col gap-4">
                    {tabs.length > 1 && ti > 0 && (
                        <h2 className="border-b border-secondary pb-1 text-[1.15em] font-semibold">{tab.label}</h2>
                    )}
                    {tab.sections.map((section, si) => (
                        <div key={section.label ?? si} className="flex flex-col gap-2">
                            {section.label && <h3 className="text-[1.05em] font-semibold">{section.label}</h3>}
                            <div className={section.columns.length > 1 ? "grid grid-cols-2 gap-x-8" : "grid"}>
                                {section.columns.map((column) => (
                                    <dl key={column.join()} className="flex flex-col gap-1.5">
                                        {column.map((name) => {
                                            const field = d.fields[name];
                                            const child = field.type === "Table" ? d.children[name] : undefined;
                                            if (child) {
                                                return (
                                                    <div key={name} className="flex flex-col gap-1">
                                                        <dt className="font-medium">{field.label}</dt>
                                                        <dd>
                                                            <ChildRows child={child} rows={doc[name] as FieldValues[]} titles={titles} />
                                                        </dd>
                                                    </div>
                                                );
                                            }
                                            return (
                                                <div key={name} className="grid grid-cols-[40%_1fr] gap-2">
                                                    <dt className="text-tertiary">{field.label}</dt>
                                                    <dd
                                                        className={
                                                            NUMERIC.has(field.type) ? "tabular-nums" : "break-words whitespace-pre-wrap"
                                                        }
                                                    >
                                                        {formatPrintValue(field, doc[name], doc, titles)}
                                                    </dd>
                                                </div>
                                            );
                                        })}
                                    </dl>
                                ))}
                            </div>
                        </div>
                    ))}
                </section>
            ))}
        </div>
    );
}
