"use client";

import { useState } from "react";
import type { FieldValues, FormPreview as FormPreviewKind } from "@/doctypes/define";
import { cx } from "@/utils/cx";
import { useSignedFileUrl } from "./attach-image-field";

type PreviewProps = { values: FieldValues; orgSlug: string };

/** Live panel below a form, picked by the descriptor's `preview`. */
export function FormPreview({ kind, ...props }: PreviewProps & { kind: FormPreviewKind }) {
    switch (kind) {
        case "LetterHead":
            return <LetterHeadPreview {...props} />;
    }
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
                {/* biome-ignore lint/performance/noImgElement: signed Storage URLs are short-lived; next/image would cache them */}
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
