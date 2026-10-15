"use client";

import { useEffect, useState, useTransition } from "react";
import { Heading as AriaHeading, type Key } from "react-aria-components";
import { Dialog, Modal, ModalOverlay } from "@/components/application/modals/modal";
import { Button } from "@/components/base/buttons/button";
import { Input } from "@/components/base/input/input";
import { Select } from "@/components/base/select/select";
import { TextArea } from "@/components/base/textarea/textarea";
import { FormAlert } from "@/components/erp/form-alert";
import { type EmailTemplateOption, getEmailDraft, sendDocumentEmail } from "@/lib/actions/email";

const SEND_DOCUMENT = "__send_document__";

type EmailDialogProps = {
    isOpen: boolean;
    onOpenChange: (open: boolean) => void;
    orgSlug: string;
    doctype: string;
    id: string;
    title: string;
    onSent: (message: string) => void;
};

/**
 * Compose an email about a saved record (Frappe `CommunicationComposer`): To / CC, a template (default "Send
 * Document"), subject and HTML message, prefilled from the record. The server re-reads the record and sanitizes.
 */
export function EmailDialog({ isOpen, onOpenChange, orgSlug, doctype, id, title, onSent }: EmailDialogProps) {
    return (
        <ModalOverlay isOpen={isOpen} onOpenChange={onOpenChange} isDismissable>
            <Modal className="max-w-2xl">
                <Dialog aria-label={`Email ${doctype}`}>
                    {isOpen && (
                        <Composer
                            orgSlug={orgSlug}
                            doctype={doctype}
                            id={id}
                            title={title}
                            onClose={() => onOpenChange(false)}
                            onSent={onSent}
                        />
                    )}
                </Dialog>
            </Modal>
        </ModalOverlay>
    );
}

type ComposerProps = Omit<EmailDialogProps, "isOpen" | "onOpenChange"> & { onClose: () => void };

function Composer({ orgSlug, doctype, id, title, onClose, onSent }: ComposerProps) {
    const [to, setTo] = useState("");
    const [cc, setCc] = useState("");
    const [template, setTemplate] = useState<string>(SEND_DOCUMENT);
    const [templates, setTemplates] = useState<EmailTemplateOption[]>([]);
    const [subject, setSubject] = useState("");
    const [html, setHtml] = useState("");
    const [error, setError] = useState<string | null>(null);
    const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
    const [loading, startLoading] = useTransition();
    const [sending, startSending] = useTransition();

    const loadDraft = (templateId: string, first: boolean) =>
        startLoading(async () => {
            setError(null);
            const result = await getEmailDraft({ orgSlug, doctype, id, templateId: templateId === SEND_DOCUMENT ? null : templateId });
            if (!result.ok || !result.data) return setError(result.ok ? "Could not prepare the email." : result.error);
            setSubject(result.data.subject);
            setHtml(result.data.html);
            setTemplates(result.data.templates);
            if (first) setTo(result.data.to);
        });

    // biome-ignore lint/correctness/useExhaustiveDependencies: load the default draft once when the dialog opens
    useEffect(() => loadDraft(SEND_DOCUMENT, true), []);

    const send = () =>
        startSending(async () => {
            setError(null);
            setFieldErrors({});
            const result = await sendDocumentEmail({ orgSlug, doctype, id, to, cc, subject, html });
            if (!result.ok || !result.data) {
                setError(result.ok ? "The email was not sent." : result.error);
                if (!result.ok) setFieldErrors(result.fieldErrors ?? {});
                return;
            }
            onSent(`Email sent to ${result.data.to.join(", ")}.`);
            onClose();
        });

    const items = [{ id: SEND_DOCUMENT, label: "Send Document (default)" }, ...templates.map((t) => ({ id: t.id, label: t.name }))];

    return (
        <form
            noValidate
            className="flex flex-col gap-4 p-6"
            onSubmit={(e) => {
                e.preventDefault();
                send();
            }}
        >
            <div className="flex flex-col gap-1">
                <AriaHeading slot="title" className="text-lg font-semibold text-primary">
                    Email {doctype}
                </AriaHeading>
                <p className="truncate text-sm text-tertiary">{title}</p>
            </div>
            {error && <FormAlert>{error}</FormAlert>}
            <div className="grid gap-4 sm:grid-cols-2">
                <Input
                    label="To"
                    size="sm"
                    isRequired
                    autoFocus
                    placeholder="name@example.com, …"
                    value={to}
                    onChange={setTo}
                    isInvalid={Boolean(fieldErrors.to)}
                    hint={fieldErrors.to}
                />
                <Input label="CC" size="sm" value={cc} onChange={setCc} isInvalid={Boolean(fieldErrors.cc)} hint={fieldErrors.cc} />
            </div>
            <Select
                label="Email Template"
                items={items}
                size="sm"
                isDisabled={loading}
                selectedKey={template}
                onSelectionChange={(key: Key | null) => {
                    const next = key == null ? SEND_DOCUMENT : String(key);
                    setTemplate(next);
                    loadDraft(next, false);
                }}
            >
                {(item) => <Select.Item id={item.id} label={item.label} />}
            </Select>
            <Input
                label="Subject"
                size="sm"
                isRequired
                isDisabled={loading}
                value={subject}
                onChange={setSubject}
                isInvalid={Boolean(fieldErrors.subject)}
                hint={fieldErrors.subject}
            />
            <TextArea
                label="Message"
                size="sm"
                rows={10}
                isRequired
                isDisabled={loading}
                textAreaClassName="font-mono text-xs"
                value={html}
                onChange={setHtml}
                isInvalid={Boolean(fieldErrors.html)}
                hint={fieldErrors.html ?? "HTML. The link opens the print view for members of this organization; no PDF is attached."}
            />
            <div className="flex justify-end gap-2">
                <Button size="sm" color="secondary" onPress={onClose} isDisabled={sending}>
                    Cancel
                </Button>
                <Button size="sm" type="submit" isLoading={sending} isDisabled={loading} showTextWhileLoading>
                    Send
                </Button>
            </div>
        </form>
    );
}
