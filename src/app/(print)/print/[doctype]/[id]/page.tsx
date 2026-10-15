import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { FormAlert } from "@/components/erp/form-alert";
import { docPath } from "@/doctypes/define";
import { requireUser } from "@/lib/auth/claims";
import { fontFamilyCss, pageSizeCss } from "@/lib/print/resolve";
import { getPrintContext, type LetterHeadBlock } from "@/lib/queries/print";
import { printTemplate } from "@/print/registry";
import { PrintToolbar } from "./print-toolbar";

export const metadata: Metadata = { title: "Print" };

type PrintPageProps = {
    params: Promise<{ doctype: string; id: string }>;
    searchParams: Promise<Record<string, string | string[] | undefined>>;
};

const PAGE_WIDTH: Record<string, string> = { A4: "210mm", Letter: "215.9mm", Legal: "215.9mm" };
const ALIGN: Record<string, string> = { Left: "text-left", Center: "text-center", Right: "text-right" };

function LetterHead({ block, label }: { block: LetterHeadBlock; label: string }) {
    if (!block) return null;
    if (block.kind === "image") {
        return (
            <div className={ALIGN[block.align] ?? "text-left"}>
                {/* biome-ignore lint/performance/noImgElement: signed Storage URLs are short-lived; next/image would cache them */}
                <img
                    src={block.url}
                    alt={`Letter head ${label}`}
                    className="inline-block max-w-full"
                    style={{
                        height: block.height ? `${block.height}px` : undefined,
                        width: block.width ? `${block.width}px` : undefined,
                    }}
                />
            </div>
        );
    }
    // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized server-side with the allow-list in src/lib/html/sanitize.ts
    return <div data-testid={`letter-head-${label}`} dangerouslySetInnerHTML={{ __html: block.html }} />;
}

async function PrintView({ params, searchParams }: PrintPageProps) {
    const [{ doctype, id }, query] = await Promise.all([params, searchParams]);
    await requireUser(`/print/${doctype}/${id}`);
    const formatParam = Array.isArray(query.format) ? query.format[0] : query.format;
    const ctx = await getPrintContext(doctype, id, formatParam);
    if (!ctx) notFound();

    const { d, doc, settings, format, letterHead } = ctx;
    const title = String(doc[d.titleField] ?? d.doctype);
    const Template = printTemplate(format?.template_key ?? "record");
    const width =
        settings.pdf_page_size === "Custom" && settings.pdf_page_width
            ? `${settings.pdf_page_width}mm`
            : (PAGE_WIDTH[settings.pdf_page_size] ?? "210mm");

    return (
        <>
            <PrintToolbar
                title={title}
                backHref={`/${ctx.org.slug}/${docPath(d)}/${id}`}
                formats={ctx.formats.map((f) => ({ id: f.id, label: f.name }))}
                formatId={format?.id ?? null}
                canPrint={!ctx.blocked}
            />
            <style>{`@page { size: ${pageSizeCss(settings)}; margin: 12mm; }`}</style>
            {ctx.blocked ? (
                <div className="mx-auto max-w-xl p-6">
                    <FormAlert>{ctx.blocked}</FormAlert>
                </div>
            ) : (
                <article
                    aria-label={`${d.doctype} ${title}`}
                    className="mx-auto my-6 flex max-w-full flex-col gap-6 bg-white p-[12mm] text-black shadow-md print:m-0 print:p-0 print:shadow-none"
                    style={{ width, fontSize: `${settings.font_size}pt`, fontFamily: fontFamilyCss(settings.font) }}
                >
                    {letterHead && <LetterHead block={letterHead.header} label="header" />}
                    <header className="flex items-start justify-between gap-4">
                        <div className="flex flex-col">
                            <h1 className="text-[1.6em] leading-tight font-semibold">{d.doctype}</h1>
                            <p className="text-[1.1em] text-tertiary">{title}</p>
                        </div>
                        {ctx.draftHeading && <p className="text-[1.6em] font-semibold text-error-primary uppercase">Draft</p>}
                    </header>
                    <Template doctype={d} doc={doc} titles={ctx.titles} />
                    {letterHead && <LetterHead block={letterHead.footer} label="footer" />}
                </article>
            )}
        </>
    );
}

/**
 * Print view (Frappe `/printview`), outside the app shell: the record (RLS-authorized), the resolved Letter Head and
 * Print Settings, rendered by the chosen Print Format's template.
 */
export default function PrintPage(props: PrintPageProps) {
    return (
        <main className="min-h-dvh bg-secondary print:bg-white">
            <Suspense>
                <PrintView {...props} />
            </Suspense>
        </main>
    );
}
