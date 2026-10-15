"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { ChevronDown, ChevronLeft, DotsVertical, Printer, Trash01 } from "@untitledui/icons";
import Link from "next/link";
import { useEffect, useMemo, useState, useTransition } from "react";
import { Heading as AriaHeading, type Key } from "react-aria-components";
import { type FieldErrors, type FieldValues, useForm, useWatch } from "react-hook-form";
import { Dialog, Modal, ModalOverlay } from "@/components/application/modals/modal";
import { Tabs } from "@/components/application/tabs/tabs";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import { Dropdown } from "@/components/base/dropdown/dropdown";
import { FormAlert } from "@/components/erp/form-alert";
import { getModule } from "@/config/navigation";
import { type Doctype, docPath, type FormTab } from "@/doctypes/define";
import { getDoctypeByName } from "@/doctypes/registry";
import { formValuesFor, schemaFor } from "@/doctypes/schema";
import { deleteDoc, saveDoc } from "@/lib/actions/doc";
import { applyFieldErrors } from "@/lib/forms";
import type { ReferenceOptions } from "@/lib/reference-options";
import { AddressContactRail } from "./address-contact-rail";
import { ChildTable } from "./child-table";
import { FieldRenderer, ReferenceOptionsContext } from "./field-renderer";
import { FormPreview } from "./form-preview";

export type DocFormProps = {
    /** Doctype name; the descriptor is resolved client-side because it holds functions (`dependsOn`). */
    doctype: string;
    orgSlug: string;
    id: string | null;
    /** Stored row (with child rows), or null for a new document. */
    row: FieldValues | null;
    canSave: boolean;
    canDelete: boolean;
    /** Options for reference-backed Select fields (`optionSourcesOf(descriptor)`), loaded on the server. */
    referenceOptions?: ReferenceOptions;
};

const NO_OPTIONS: ReferenceOptions = {};

/**
 * Generic ERPNext form view: header (title, "Not Saved", Save with Ctrl/Cmd+S, Delete), tabs -> sections -> columns
 * of fields, `depends_on` visibility, server errors mapped back onto fields.
 */
export function DocForm({ doctype, orgSlug, id, row, canSave, canDelete, referenceOptions = NO_OPTIONS }: DocFormProps) {
    const d = getDoctypeByName(doctype) as Doctype;
    const isNew = id === null;
    const editable = canSave && Number(row?.docstatus ?? 0) === 0;
    const resolver = useMemo(() => zodResolver(schemaFor(d)), [d]);
    const form = useForm<FieldValues>({ resolver, defaultValues: formValuesFor(d, row ?? undefined) });
    const { isDirty, isSubmitting, errors } = form.formState;
    const values = useWatch({ control: form.control });
    const [error, setError] = useState<string | null>(null);
    const [saved, setSaved] = useState(false);
    const [notice, setNotice] = useState<string | null>(null);
    const [tab, setTab] = useState<Key>(d.tabs[0]?.label ?? "");

    // A server refresh after saving brings normalised values (e.g. upper-cased abbr); never clobber unsaved edits.
    // biome-ignore lint/correctness/useExhaustiveDependencies: reset only when the stored row changes
    useEffect(() => {
        if (!form.formState.isDirty) form.reset(formValuesFor(d, row ?? undefined));
    }, [row]);

    const visible = (name: string) => {
        const field = d.fields[name];
        return Boolean(field) && (!field.dependsOn || field.dependsOn(values));
    };

    const tabs = d.tabs.filter((t) => t.sections.some((s) => s.columns.flat().some(visible)));
    const tabErrors = (t: FormTab) => t.sections.flatMap((s) => s.columns.flat()).filter((n) => n in errors).length;

    const showFirstErrorTab = (errs: FieldErrors) => {
        const first = tabs.find((t) => t.sections.some((s) => s.columns.flat().some((n) => n in errs)));
        if (first) setTab(first.label);
    };

    const onSubmit = form.handleSubmit(async (input) => {
        setError(null);
        setSaved(false);
        setNotice(null);
        const result = await saveDoc({ orgSlug, doctype, id, values: input });
        if (!result.ok) {
            setError(result.error);
            applyFieldErrors(form.setError, result.fieldErrors);
            if (result.fieldErrors) showFirstErrorTab(result.fieldErrors as unknown as FieldErrors);
            return;
        }
        form.reset(input);
        setSaved(true);
    }, showFirstErrorTab);

    const [running, setRunning] = useState(false);
    const runAction = async (actionId: string) => {
        const action = d.actions.find((a) => a.id === actionId);
        if (!action) return;
        setError(null);
        setSaved(false);
        setNotice(null);
        setRunning(true);
        try {
            const changes = await action.run(form.getValues(), { orgSlug, id, notify: setNotice });
            for (const [name, value] of Object.entries(changes)) form.setValue(name, value, { shouldDirty: true });
        } catch (e) {
            setError(e instanceof Error ? e.message : `${action.label} failed.`);
        } finally {
            setRunning(false);
        }
    };

    // Field triggers react to user edits only; values they set do not re-trigger.
    useEffect(() => {
        const subscription = form.watch((all, { name, type }) => {
            const trigger = type === "change" && name ? d.triggers[name] : undefined;
            if (!trigger) return;
            for (const [field, value] of Object.entries(trigger(all))) {
                if (form.getValues(field) !== value) form.setValue(field, value, { shouldDirty: true });
            }
        });
        return () => subscription.unsubscribe();
    }, [form, d]);

    useEffect(() => {
        const onKeyDown = (event: KeyboardEvent) => {
            if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
                event.preventDefault();
                if (editable && !form.formState.isSubmitting) void onSubmit();
            }
        };
        window.addEventListener("keydown", onKeyDown);
        return () => window.removeEventListener("keydown", onKeyDown);
    }, [editable, form, onSubmit]);

    useEffect(() => {
        if (!isDirty) return;
        const onBeforeUnload = (event: BeforeUnloadEvent) => event.preventDefault();
        window.addEventListener("beforeunload", onBeforeUnload);
        return () => window.removeEventListener("beforeunload", onBeforeUnload);
    }, [isDirty]);

    const title = isNew ? `New ${d.doctype}` : d.single ? d.doctype : String(row?.[d.titleField] || d.doctype);
    const listHref = d.single ? `/${orgSlug}/${d.module}` : `/${orgSlug}/${docPath(d)}`;
    const backLabel = d.single ? (getModule(d.module)?.label ?? d.module) : d.doctype;
    const rail = d.addressContact && id ? <AddressContactRail orgSlug={orgSlug} doctype={d.doctype} id={id} /> : null;

    const renderTab = (t: FormTab) =>
        t.sections.map((section, si) => {
            const columns = section.columns.map((c) => c.filter(visible)).filter((c) => c.length);
            if (!columns.length) return null;
            return (
                <section key={section.label ?? si} className="flex flex-col gap-3 border-b border-secondary py-5 last:border-b-0">
                    {section.label && <h2 className="text-sm font-semibold text-primary">{section.label}</h2>}
                    <div className={columns.length > 1 ? "grid gap-x-8 gap-y-4 lg:grid-cols-2" : "grid gap-y-4"}>
                        {columns.map((column) => (
                            <div key={column.join()} className="flex min-w-0 flex-col gap-4">
                                {column.map((name) => {
                                    const field = d.fields[name];
                                    const isDisabled = !editable || field.readOnly || (field.setOnlyOnce && !isNew);
                                    const child = field.type === "Table" ? d.children[name] : undefined;
                                    return child ? (
                                        <ChildTable
                                            key={name}
                                            control={form.control}
                                            name={name}
                                            field={field}
                                            child={child}
                                            orgSlug={orgSlug}
                                            isDisabled={isDisabled}
                                        />
                                    ) : (
                                        <FieldRenderer
                                            key={name}
                                            control={form.control}
                                            name={name}
                                            field={field}
                                            orgSlug={orgSlug}
                                            isDisabled={isDisabled}
                                        />
                                    );
                                })}
                            </div>
                        ))}
                    </div>
                </section>
            );
        });

    return (
        <ReferenceOptionsContext value={referenceOptions}>
            <form onSubmit={onSubmit} noValidate className="flex flex-col">
                <header className="sticky -top-5 z-10 -mx-4 -mt-5 flex flex-wrap items-center gap-3 border-b border-secondary bg-primary px-4 py-3 lg:-top-6 lg:-mx-8 lg:-mt-6 lg:px-8">
                    <div className="flex min-w-0 flex-1 flex-col">
                        <Link
                            href={listHref}
                            className="flex w-max items-center gap-1 text-xs font-medium text-tertiary hover:text-secondary"
                        >
                            <ChevronLeft aria-hidden="true" className="size-3.5" />
                            {backLabel}
                        </Link>
                        <div className="flex min-w-0 items-center gap-2">
                            <h1 className="truncate text-lg font-semibold text-primary">{title}</h1>
                            {(isNew || isDirty) && (
                                <Badge size="sm" color="warning">
                                    Not Saved
                                </Badge>
                            )}
                        </div>
                    </div>
                    <div className="flex items-center gap-2">
                        {editable && d.actions.length > 0 && (
                            <Dropdown.Root>
                                <Button size="sm" color="secondary" iconTrailing={ChevronDown} isLoading={running} showTextWhileLoading>
                                    Actions
                                </Button>
                                <Dropdown.Popover placement="bottom right">
                                    <Dropdown.Menu aria-label={`${d.doctype} actions`} onAction={(key) => void runAction(String(key))}>
                                        {d.actions.map((a) => (
                                            <Dropdown.Item key={a.id} id={a.id} label={a.label} />
                                        ))}
                                    </Dropdown.Menu>
                                </Dropdown.Popover>
                            </Dropdown.Root>
                        )}
                        {!isNew && (canDelete || !d.single) && (
                            <MoreMenu
                                doctype={d.doctype}
                                title={title}
                                orgSlug={orgSlug}
                                id={id}
                                printHref={d.single ? null : `/print/${d.slug}/${id}`}
                                canDelete={canDelete}
                            />
                        )}
                        {editable && (
                            <Button type="submit" size="sm" isLoading={isSubmitting} showTextWhileLoading>
                                Save
                                <kbd className="ml-1 text-xs font-medium opacity-70 max-md:hidden">Ctrl+S</kbd>
                            </Button>
                        )}
                    </div>
                </header>

                <div className="flex flex-col gap-3 pt-4">
                    {error && <FormAlert>{error}</FormAlert>}
                    {saved && !isDirty && <FormAlert tone="success">Saved.</FormAlert>}
                    {notice && <FormAlert tone="success">{notice}</FormAlert>}
                    {!editable && <FormAlert tone="info">You can view this {d.doctype} but not change it.</FormAlert>}
                </div>

                <div className={rail ? "grid gap-x-8 xl:grid-cols-[minmax(0,1fr)_20rem]" : undefined}>
                    <div className="min-w-0">
                        {tabs.length > 1 ? (
                            <Tabs selectedKey={tab} onSelectionChange={setTab} className="pt-2">
                                <Tabs.List type="underline" size="sm" aria-label={`${d.doctype} sections`}>
                                    {tabs.map((t) => (
                                        <Tabs.Item key={t.label} id={t.label} badge={tabErrors(t) || undefined}>
                                            {t.label}
                                        </Tabs.Item>
                                    ))}
                                </Tabs.List>
                                {tabs.map((t) => (
                                    <Tabs.Panel key={t.label} id={t.label} shouldForceMount className="[&[inert]]:hidden">
                                        {renderTab(t)}
                                    </Tabs.Panel>
                                ))}
                            </Tabs>
                        ) : (
                            tabs.map((t) => <div key={t.label}>{renderTab(t)}</div>)
                        )}
                        {d.preview && <FormPreview kind={d.preview} values={values} orgSlug={orgSlug} />}
                    </div>
                    {rail && <div className="border-t border-secondary py-5 xl:border-t-0 xl:pt-4">{rail}</div>}
                </div>
            </form>
        </ReferenceOptionsContext>
    );
}

type MoreMenuProps = { doctype: string; title: string; orgSlug: string; id: string; printHref: string | null; canDelete: boolean };

/** Overflow menu: Print (new tab, `/print/<slug>/<id>`) and Delete with a confirm dialog. */
function MoreMenu({ doctype, title, orgSlug, id, printHref, canDelete }: MoreMenuProps) {
    const [open, setOpen] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();

    const confirm = () =>
        startTransition(async () => {
            setError(null);
            const result = await deleteDoc({ orgSlug, doctype, id });
            if (result && !result.ok) setError(result.error);
        });

    return (
        <>
            <Dropdown.Root>
                <Button size="sm" color="secondary" iconLeading={DotsVertical} aria-label="More actions" />
                <Dropdown.Popover placement="bottom right">
                    <Dropdown.Menu
                        aria-label="More actions"
                        onAction={(key) => {
                            if (key === "print" && printHref) window.open(printHref, "_blank", "noopener");
                            if (key === "delete") setOpen(true);
                        }}
                    >
                        {printHref ? <Dropdown.Item id="print" icon={Printer} label="Print" /> : null}
                        {canDelete ? <Dropdown.Item id="delete" icon={Trash01} label="Delete" /> : null}
                    </Dropdown.Menu>
                </Dropdown.Popover>
            </Dropdown.Root>
            <ModalOverlay isOpen={open} onOpenChange={setOpen} isDismissable={!pending}>
                <Modal className="max-w-md">
                    <Dialog aria-label={`Delete ${doctype}`}>
                        <div className="flex flex-col gap-4 p-6">
                            <AriaHeading slot="title" className="text-lg font-semibold text-primary">
                                Delete {doctype}?
                            </AriaHeading>
                            <p className="text-sm text-tertiary">
                                <span className="font-medium text-secondary">{title}</span> will be permanently deleted. This cannot be
                                undone.
                            </p>
                            {error && <FormAlert>{error}</FormAlert>}
                            <div className="flex justify-end gap-2">
                                <Button size="sm" color="secondary" onPress={() => setOpen(false)} isDisabled={pending}>
                                    Cancel
                                </Button>
                                <Button size="sm" color="primary-destructive" onPress={confirm} isLoading={pending} showTextWhileLoading>
                                    Delete
                                </Button>
                            </div>
                        </div>
                    </Dialog>
                </Modal>
            </ModalOverlay>
        </>
    );
}
