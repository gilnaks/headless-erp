"use client";

import { Trash01 } from "@untitledui/icons";
import { useEffect, useState } from "react";
import { useController } from "react-hook-form";
import { FileUploadDropZone } from "@/components/application/file-upload/file-upload-base";
import { LoadingIndicator } from "@/components/application/loading-indicator/loading-indicator";
import { ButtonUtility } from "@/components/base/buttons/button-utility";
import { HintText } from "@/components/base/input/hint-text";
import { Label } from "@/components/base/input/label";
import { createImageUpload, signedFileUrls } from "@/lib/actions/files";
import { createClient } from "@/lib/supabase/client";
import type { FieldRendererProps } from "./field-renderer";

const ACCEPT = "image/png,image/jpeg,image/gif,image/webp";
const MAX_BYTES = 2 * 1024 * 1024;

/** A signed read URL for a private `org-files` object (null while loading or when the caller cannot read it). */
export function useSignedFileUrl(orgSlug: string, path: string | null | undefined): string | null {
    const [urls, setUrls] = useState<Record<string, string | null>>({});
    useEffect(() => {
        if (!path || path in urls) return;
        let cancelled = false;
        signedFileUrls({ orgSlug, paths: [path] }).then((found) => {
            if (!cancelled) setUrls((prev) => ({ ...prev, ...found }));
        });
        return () => {
            cancelled = true;
        };
    }, [orgSlug, path, urls]);
    return path ? (urls[path] ?? null) : null;
}

/**
 * Frappe "Attach Image": uploads to the private `org-files` bucket (`<org_id>/<field.folder>/<uuid>.<ext>`) through a
 * signed upload URL and stores the object path; the preview uses a short-lived signed URL.
 */
export function AttachImageField({ control, name, field, orgSlug, isDisabled }: FieldRendererProps) {
    const { field: f, fieldState } = useController({ control, name });
    const path = typeof f.value === "string" && f.value ? f.value : null;
    const url = useSignedFileUrl(orgSlug, path);
    const [uploading, setUploading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const upload = async (file: File) => {
        setError(null);
        setUploading(true);
        try {
            const result = await createImageUpload({ orgSlug, folder: field.folder ?? "", contentType: file.type, size: file.size });
            if (!result.ok || !result.data) {
                setError(result.ok ? "Upload failed." : result.error);
                return;
            }
            const { error: uploadError } = await createClient()
                .storage.from("org-files")
                .uploadToSignedUrl(result.data.path, result.data.token, file, { contentType: file.type });
            if (uploadError) {
                setError(uploadError.message);
                return;
            }
            f.onChange(result.data.path);
            f.onBlur();
        } finally {
            setUploading(false);
        }
    };

    const message = error ?? fieldState.error?.message;
    return (
        <div className="flex flex-col gap-1.5">
            <Label isRequired={field.required}>{field.label}</Label>
            {path && (
                <div className="flex items-start gap-2 rounded-lg p-2 ring-1 ring-secondary ring-inset">
                    <div className="flex h-20 min-w-0 flex-1 items-center justify-center">
                        {url ? (
                            // biome-ignore lint/performance/noImgElement: signed Storage URLs are short-lived; next/image would cache them
                            <img src={url} alt={field.label} className="max-h-20 max-w-full object-contain" />
                        ) : (
                            <LoadingIndicator type="line-simple" size="sm" />
                        )}
                    </div>
                    {!isDisabled && (
                        <ButtonUtility
                            size="xs"
                            color="tertiary"
                            icon={Trash01}
                            tooltip={`Remove ${field.label}`}
                            onPress={() => {
                                f.onChange("");
                                f.onBlur();
                            }}
                        />
                    )}
                </div>
            )}
            {!isDisabled && (
                <div className="relative">
                    <FileUploadDropZone
                        accept={ACCEPT}
                        allowsMultiple={false}
                        maxSize={MAX_BYTES}
                        isDisabled={uploading}
                        hint="PNG, JPG, GIF or WebP (max. 2 MB)"
                        onDropFiles={(files) => files[0] && void upload(files[0])}
                        onDropUnacceptedFiles={() => setError("Upload a PNG, JPEG, GIF or WebP image.")}
                        onSizeLimitExceed={() => setError("Images must be 2 MB or smaller.")}
                    />
                    {uploading && (
                        <div className="absolute inset-0 flex items-center justify-center rounded-xl bg-primary/70">
                            <LoadingIndicator type="line-simple" size="sm" />
                        </div>
                    )}
                </div>
            )}
            {message ? <HintText isInvalid>{message}</HintText> : field.description && <HintText>{field.description}</HintText>}
        </div>
    );
}
