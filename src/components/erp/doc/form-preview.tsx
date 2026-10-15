"use client";

import { useState } from "react";
import type { FieldValues, FormPreview as FormPreviewKind } from "@/doctypes/define";
import { renderTemplate, type TemplateContext } from "@/lib/email/render";
import { cx } from "@/utils/cx";
import { useSignedFileUrl } from "./attach-image-field";

type PreviewProps = { values: FieldValues; orgSlug: string };

/** Live panel below a form, picked by the descriptor's `preview`. */
export function FormPreview({ kind, ...props }: PreviewProps & { kind: FormPreviewKind }) {
    switch (kind) {
        case "LetterHead":
            return <LetterHeadPreview {...props} />;
        case "EmailTemplate":
            return <EmailTemplatePreview {...props} />;
    }
}

const SAMPLE_CONTEXT: TemplateContext = {
    doc: {
        doctype: "Sales Invoice",
        name: "ACC-SINV-2026-00001",
        customer_name: "Sample Customer",
        posting_date: "2026-01-15",
        due_date: "2026-02-14",
        grand_total: 1250,
        currency: "USD",
        items: [{ item_code: "SAMPLE-ITEM", item_name: "Sample Item", qty: 5, rate: 250 }],
    },
    company: { company_name: "Your Company", default_currency: "USD" },
    user: { full_name: "Your Name" },
};

/** The template rendered against a sample Sales Invoice; compile errors are shown instead. */
function EmailTemplatePreview({ values }: PreviewProps) {
    const str = (name: string) => (typeof values[name] === "string" ? (values[name] as string) : "");
    const html = Boolean(values.use_html);
    const render = (source: string, asHtml: boolean) => {
        try {
            return { text: renderTemplate(source, SAMPLE_CONTEXT, { html: asHtml }), error: null };
        } catch (e) {
            return { text: "", error: e instanceof Error ? e.message : "Invalid template" };
        }
    };
    const subject = render(str("subject"), false);
    const body = render(html ? str("response_html") : str("response"), html);
    return (
        <section className="flex flex-col gap-3 border-t border-secondary py-5">
            <h2 className="text-sm font-semibold text-primary">Preview</h2>
            <p className="text-xs text-tertiary">Rendered with a sample Sales Invoice.</p>
            <div data-testid="email-template-preview" className="flex flex-col gap-3 rounded-lg bg-secondary p-4">
                <p className="text-sm text-primary">
                    <span className="font-medium text-secondary">Subject: </span>
                    {subject.error ? <span className="text-error-primary">{subject.error}</span> : subject.text}
                </p>
                <div className="rounded-md bg-white p-4 text-black shadow-xs">
                    {body.error ? (
                        <p className="text-sm text-error-primary">{body.error}</p>
                    ) : html ? (
                        body.text.trim() && <HtmlFrame title="Email body preview" html={body.text} />
                    ) : (
                        <p className="text-sm whitespace-pre-wrap">{body.text}</p>
                    )}
                </div>
            </div>
        </section>
    );
}

const ALIGN: Record<string, string> = { Left: "text-left", Center: "text-center", Right: "text-right" };

/** Letter head on an A4-width page: header (HTML or image), placeholder body, footer. */
function LetterHeadPreview({ values, orgSlug }: PreviewProps) {
    const str = (name: string) => (typeof values[name] === "string" ? (values[name] as string) : "");
    return (
        <section className="flex flex-col gap-3 border-t border-secondary py-5">
            <h2 className="text-sm font-semibold text-primary">Preview</h2>
            <div className="overflow-x-auto rounded-lg bg-secondary p-4">
                <div
                    data-testid="letter-head-preview"
                    className="mx-auto flex aspect-[210/297] w-[794px] max-w-none flex-col gap-6 bg-white p-10 text-black shadow-md"
                >
                    <Block
                        label="Header"
                        orgSlug={orgSlug}
                        source={str("source")}
                        html={str("content")}
                        image={str("image")}
                        height={str("image_height")}
                        width={str("image_width")}
                        align={str("align")}
                    />
                    <div className="flex flex-1 flex-col gap-2" aria-hidden="true">
                        {[80, 95, 60, 90, 70].map((w) => (
                            <div key={w} className="h-2 rounded bg-gray-100" style={{ width: `${w}%` }} />
                        ))}
                    </div>
                    <Block
                        label="Footer"
                        orgSlug={orgSlug}
                        source={str("footer_source")}
                        html={str("footer")}
                        image={str("footer_image")}
                        height={str("footer_image_height")}
                        width={str("footer_image_width")}
                        align={str("footer_align")}
                    />
                </div>
            </div>
        </section>
    );
}

type BlockProps = {
    label: string;
    orgSlug: string;
    source: string;
    html: string;
    image: string;
    height: string;
    width: string;
    align: string;
};

function Block({ label, orgSlug, source, html, image, height, width, align }: BlockProps) {
    const url = useSignedFileUrl(orgSlug, source === "Image" ? image : null);
    if (source === "Image") {
        if (!url) return null;
        return (
            <div className={ALIGN[align] ?? "text-left"}>
                <img
                    src={url}
                    alt={`Letter head ${label.toLowerCase()}`}
                    className="inline-block max-w-full"
                    style={{ height: Number(height) > 0 ? `${height}px` : undefined, width: Number(width) > 0 ? `${width}px` : undefined }}
                />
            </div>
        );
    }
    return html.trim() ? <HtmlFrame title={`${label} preview`} html={html} /> : null;
}

/**
 * Unsaved HTML rendered in a sandboxed frame: `allow-same-origin` without `allow-scripts` lets the form size the
 * frame to its content while scripts and handlers never run (the saved value is sanitized server-side).
 */
function HtmlFrame({ title, html }: { title: string; html: string }) {
    const [height, setHeight] = useState(0);
    return (
        <iframe
            title={title}
            sandbox="allow-same-origin"
            srcDoc={`<!doctype html><html><head><style>body{margin:0;font:13px/1.4 system-ui,sans-serif}</style></head><body>${html}</body></html>`}
            className={cx("w-full border-0", !height && "h-24")}
            style={height ? { height } : undefined}
            onLoad={(e) => setHeight(e.currentTarget.contentDocument?.documentElement.scrollHeight ?? 0)}
        />
    );
}
