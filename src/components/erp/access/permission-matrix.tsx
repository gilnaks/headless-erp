"use client";

import { Plus, RefreshCcw01, Trash01 } from "@untitledui/icons";
import { useQueryStates } from "nuqs";
import { type ReactNode, useMemo, useState, useTransition } from "react";
import { Heading as AriaHeading, type Key } from "react-aria-components";
import { Dialog, Modal, ModalOverlay } from "@/components/application/modals/modal";
import { Table } from "@/components/application/table/table";
import { Button } from "@/components/base/buttons/button";
import { ButtonUtility } from "@/components/base/buttons/button-utility";
import { Checkbox } from "@/components/base/checkbox/checkbox";
import { Select } from "@/components/base/select/select";
import { FormAlert } from "@/components/erp/form-alert";
import { addRule, removeRule, resetDoctype, setPermission } from "@/lib/actions/setup/role-permissions";
import type { ActionResult } from "@/lib/errors";
import type { PermissionDoctype } from "@/lib/queries/role-permissions";
import { permissionParsers } from "@/lib/role-permission-params";
import { PERM_FIELDS, PERM_LABELS, type PermField, type PermRule, permToggle, SUBMIT_FIELDS } from "@/lib/role-permissions";
import { cx } from "@/utils/cx";

type PermissionMatrixProps = {
    orgSlug: string;
    doctypes: PermissionDoctype[];
    roles: string[];
    rules: PermRule[];
};

const ANY = "__any__";

/**
 * Frappe Role Permissions Manager (permission-manager page): pick a document type or a role, then toggle each rule's
 * permissions, add or remove rules, or reset one document type to its defaults.
 */
export function PermissionMatrix({ orgSlug, doctypes, roles, rules }: PermissionMatrixProps) {
    const [filters, setFilters] = useQueryStates(permissionParsers);
    const [error, setError] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();
    const meta = useMemo(() => new Map(doctypes.map((d) => [d.doctype, d])), [doctypes]);
    const selected = filters.doctype ? meta.get(filters.doctype) : undefined;

    const rows = useMemo(
        () =>
            filters.doctype || filters.role
                ? rules
                      .filter((r) => (!filters.doctype || r.doctype === filters.doctype) && (!filters.role || r.role === filters.role))
                      .sort(
                          (a, b) =>
                              (meta.get(a.doctype)?.module ?? "").localeCompare(meta.get(b.doctype)?.module ?? "") ||
                              a.doctype.localeCompare(b.doctype) ||
                              a.role.localeCompare(b.role),
                      )
                : [],
        [rules, filters.doctype, filters.role, meta],
    );

    const run = (action: () => Promise<ActionResult>) =>
        startTransition(async () => {
            setError(null);
            const result = await action();
            if (!result.ok) setError(result.error);
        });

    const toggle = (rule: PermRule, field: PermField, value: boolean) =>
        run(() => setPermission({ orgSlug, role: rule.role, doctype: rule.doctype, patch: permToggle(rule, field, value) }));

    const doctypeItems = [{ id: ANY, label: "Any document type" }, ...doctypes.map((d) => ({ id: d.doctype, label: d.doctype }))];
    const roleItems = [{ id: ANY, label: "Any role" }, ...roles.map((r) => ({ id: r, label: r }))];
    const pick = (key: Key | null) => (key == null || key === ANY ? null : String(key));

    return (
        <div className="flex flex-col gap-4">
            <header className="flex flex-wrap items-center gap-3">
                <h1 className="flex-1 text-lg font-semibold text-primary">Role Permissions</h1>
                {selected && !selected.locked && (
                    <ResetDoctype doctype={selected.doctype} onConfirm={() => resetDoctype({ orgSlug, doctype: selected.doctype })} />
                )}
                <AddRule
                    doctypes={doctypes.filter((d) => !d.locked)}
                    roles={roles}
                    initial={{ doctype: selected && !selected.locked ? selected.doctype : "", role: filters.role }}
                    onAdd={(role, doctype) => addRule({ orgSlug, role, doctype })}
                />
            </header>

            <div className="flex flex-wrap gap-3">
                <Select
                    aria-label="Document type"
                    items={doctypeItems}
                    size="sm"
                    className="w-64"
                    selectedKey={filters.doctype || ANY}
                    onSelectionChange={(key) => void setFilters({ doctype: pick(key) })}
                >
                    {(item) => <Select.Item id={item.id} label={item.label} />}
                </Select>
                <Select
                    aria-label="Role"
                    items={roleItems}
                    size="sm"
                    className="w-64"
                    selectedKey={filters.role || ANY}
                    onSelectionChange={(key) => void setFilters({ role: pick(key) })}
                >
                    {(item) => <Select.Item id={item.id} label={item.label} />}
                </Select>
            </div>

            {error && <FormAlert>{error}</FormAlert>}
            {selected?.locked && (
                <FormAlert tone="info">
                    Permissions for {selected.doctype} are fixed to System Manager so the organization cannot lock itself out.
                </FormAlert>
            )}

            <div className={cx("overflow-hidden rounded-xl ring-1 ring-secondary transition-opacity", pending && "opacity-60")}>
                <Table aria-label="Role permissions" size="sm">
                    <Table.Header>
                        <Table.Head id="doctype" label="Document Type" isRowHeader className="px-4" />
                        <Table.Head id="role" label="Role" className="px-4" />
                        {PERM_FIELDS.map((f) => (
                            <Table.Head key={f} id={f} label={PERM_LABELS[f]} className="px-2" />
                        ))}
                        <Table.Head id="actions" label="" className="px-2" />
                    </Table.Header>
                    <Table.Body
                        items={rows.map((r) => ({ ...r, id: `${r.doctype}:${r.role}` }))}
                        renderEmptyState={() => (
                            <p className="px-4 py-10 text-center text-sm text-tertiary">
                                {filters.doctype || filters.role
                                    ? "No rules match these filters."
                                    : "Select a document type or a role to see its rules."}
                            </p>
                        )}
                    >
                        {(rule) => {
                            const doctype = meta.get(rule.doctype);
                            const locked = !doctype || doctype.locked;
                            return (
                                <Table.Row id={rule.id} className="h-11">
                                    <Table.Cell className="px-4 py-2 font-medium text-primary">{rule.doctype}</Table.Cell>
                                    <Table.Cell className="px-4 py-2 text-secondary">{rule.role}</Table.Cell>
                                    {PERM_FIELDS.map((f) => (
                                        <Table.Cell key={f} className="px-2 py-2">
                                            <Checkbox
                                                aria-label={`${PERM_LABELS[f]}: ${rule.role} on ${rule.doctype}`}
                                                isSelected={rule[f]}
                                                isDisabled={locked || pending || (SUBMIT_FIELDS.has(f) && !doctype?.isSubmittable)}
                                                onChange={(value) => toggle(rule, f, value)}
                                            />
                                        </Table.Cell>
                                    ))}
                                    <Table.Cell className="px-2 py-2">
                                        {!locked && (
                                            <ButtonUtility
                                                size="xs"
                                                color="tertiary"
                                                icon={Trash01}
                                                tooltip={`Remove ${rule.role} from ${rule.doctype}`}
                                                isDisabled={pending}
                                                onPress={() => run(() => removeRule({ orgSlug, role: rule.role, doctype: rule.doctype }))}
                                            />
                                        )}
                                    </Table.Cell>
                                </Table.Row>
                            );
                        }}
                    </Table.Body>
                </Table>
            </div>
            <p className="text-sm text-tertiary">
                Submit, Cancel and Amend apply to submittable document types only. Amend needs Cancel, Cancel needs Submit, and all three
                need Write.
            </p>
        </div>
    );
}

function ConfirmModal({
    isOpen,
    onOpenChange,
    title,
    children,
}: {
    isOpen: boolean;
    onOpenChange: (open: boolean) => void;
    title: string;
    children: ReactNode;
}) {
    return (
        <ModalOverlay isOpen={isOpen} onOpenChange={onOpenChange} isDismissable>
            <Modal className="max-w-md">
                <Dialog aria-label={title}>
                    <div className="flex w-full flex-col gap-4 p-6">
                        <AriaHeading slot="title" className="text-lg font-semibold text-primary">
                            {title}
                        </AriaHeading>
                        {children}
                    </div>
                </Dialog>
            </Modal>
        </ModalOverlay>
    );
}

function ResetDoctype({ doctype, onConfirm }: { doctype: string; onConfirm: () => Promise<ActionResult> }) {
    const [open, setOpen] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();
    const confirm = () =>
        startTransition(async () => {
            setError(null);
            const result = await onConfirm();
            if (result.ok) setOpen(false);
            else setError(result.error);
        });
    return (
        <>
            <Button size="sm" color="secondary" iconLeading={RefreshCcw01} onPress={() => setOpen(true)}>
                Reset to defaults
            </Button>
            <ConfirmModal isOpen={open} onOpenChange={setOpen} title={`Reset ${doctype} permissions?`}>
                <p className="text-sm text-tertiary">
                    Every rule for <span className="font-medium text-secondary">{doctype}</span> is replaced by the default rules. Other
                    document types are not changed.
                </p>
                {error && <FormAlert>{error}</FormAlert>}
                <div className="flex justify-end gap-2">
                    <Button size="sm" color="secondary" onPress={() => setOpen(false)} isDisabled={pending}>
                        Cancel
                    </Button>
                    <Button size="sm" color="primary-destructive" onPress={confirm} isLoading={pending} showTextWhileLoading>
                        Reset
                    </Button>
                </div>
            </ConfirmModal>
        </>
    );
}

function AddRule({
    doctypes,
    roles,
    initial,
    onAdd,
}: {
    doctypes: PermissionDoctype[];
    roles: string[];
    initial: { doctype: string; role: string };
    onAdd: (role: string, doctype: string) => Promise<ActionResult>;
}) {
    const [open, setOpen] = useState(false);
    const [doctype, setDoctype] = useState<string | null>(null);
    const [role, setRole] = useState<string | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [pending, startTransition] = useTransition();

    const show = () => {
        setDoctype(initial.doctype || null);
        setRole(initial.role || null);
        setError(null);
        setOpen(true);
    };
    const confirm = () =>
        startTransition(async () => {
            if (!doctype || !role) return setError("Select a document type and a role.");
            const result = await onAdd(role, doctype);
            if (result.ok) setOpen(false);
            else setError(result.error);
        });

    return (
        <>
            <Button size="sm" iconLeading={Plus} onPress={show}>
                Add a new rule
            </Button>
            <ConfirmModal isOpen={open} onOpenChange={setOpen} title="Add a new rule">
                <p className="text-sm text-tertiary">The role gets Read on the document type; tick more permissions afterwards.</p>
                <Select
                    label="Document Type"
                    items={doctypes.map((d) => ({ id: d.doctype, label: d.doctype }))}
                    size="sm"
                    placeholder="Select"
                    selectedKey={doctype}
                    onSelectionChange={(key) => setDoctype(key == null ? null : String(key))}
                >
                    {(item) => <Select.Item id={item.id} label={item.label} />}
                </Select>
                <Select
                    label="Role"
                    items={roles.map((r) => ({ id: r, label: r }))}
                    size="sm"
                    placeholder="Select"
                    selectedKey={role}
                    onSelectionChange={(key) => setRole(key == null ? null : String(key))}
                >
                    {(item) => <Select.Item id={item.id} label={item.label} />}
                </Select>
                {error && <FormAlert>{error}</FormAlert>}
                <div className="flex justify-end gap-2">
                    <Button size="sm" color="secondary" onPress={() => setOpen(false)} isDisabled={pending}>
                        Cancel
                    </Button>
                    <Button size="sm" onPress={confirm} isLoading={pending} showTextWhileLoading>
                        Add rule
                    </Button>
                </div>
            </ConfirmModal>
        </>
    );
}
