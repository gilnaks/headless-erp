"use client";

import { File06, Plus, SearchLg } from "@untitledui/icons";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import type { Key } from "react-aria-components";
import { Autocomplete, Header, Menu, MenuItem, MenuSection, SearchField } from "react-aria-components";
import { Dialog, Modal, ModalOverlay } from "@/components/application/modals/modal";
import { Badge } from "@/components/base/badges/badges";
import { InputBase } from "@/components/base/input/input";
import { BUILT_PAGES, MODULES, moduleLinks, orgHref } from "@/config/navigation";
import { docPath } from "@/doctypes/define";
import { DOCTYPES, getDoctypeByName } from "@/doctypes/registry";
import { type SearchHit, searchDocs } from "@/lib/actions/search";
import { cx } from "@/utils/cx";

type Entry = { id: string; label: string; detail?: string; badge?: string; path: string };

/** Every nav link once (Settings pointers repeat across modules); unbuilt pages carry their phase. */
const GO_TO: Entry[] = (() => {
    const seen = new Set<string>();
    const entries: Entry[] = [];
    for (const module of MODULES) {
        for (const link of moduleLinks(module)) {
            if (seen.has(link.path)) continue;
            seen.add(link.path);
            const built = BUILT_PAGES.has(link.path) || (link.target.kind === "doctype" && Boolean(getDoctypeByName(link.target.doctype)));
            const label = link.label === "Home" || link.label === "Dashboard" ? `${module.label} ${link.label}` : link.label;
            entries.push({ id: `go:${link.path}`, label, detail: module.label, badge: built ? undefined : link.phase, path: link.path });
        }
    }
    return entries;
})();

const matches = (e: Entry, term: string) => `${e.label} ${e.detail ?? ""}`.toLowerCase().includes(term);

type RecordState = { status: "idle" | "loading" | "error" | "done"; hits: SearchHit[] };

function useRecordSearch(orgSlug: string, query: string): RecordState {
    const [state, setState] = useState<RecordState>({ status: "idle", hits: [] });
    useEffect(() => {
        const term = query.trim();
        if (term.length < 2) {
            setState({ status: "idle", hits: [] });
            return;
        }
        let active = true;
        setState((s) => ({ status: "loading", hits: s.hits }));
        const timer = setTimeout(() => {
            searchDocs(orgSlug, term)
                .then((hits) => active && setState({ status: "done", hits }))
                .catch(() => active && setState({ status: "error", hits: [] }));
        }, 200);
        return () => {
            active = false;
            clearTimeout(timer);
        };
    }, [orgSlug, query]);
    return state;
}

type CommandPaletteProps = {
    orgSlug: string;
    creatable: string[];
    isOpen: boolean;
    onOpenChange: (open: boolean) => void;
};

/** Ctrl/Cmd+K: go to any page, create a document, or jump to a record (docs/architecture/05-ui-ux.md). */
export function CommandPalette({ orgSlug, creatable, isOpen, onOpenChange }: CommandPaletteProps) {
    const router = useRouter();
    const [query, setQuery] = useState("");
    const records = useRecordSearch(orgSlug, query);

    useEffect(() => {
        if (!isOpen) setQuery("");
    }, [isOpen]);

    const create = useMemo<Entry[]>(
        () =>
            DOCTYPES.filter((d) => !d.single && creatable.includes(d.doctype)).map((d) => ({
                id: `new:${d.doctype}`,
                label: `New ${d.doctype}`,
                path: `${docPath(d)}/new`,
            })),
        [creatable],
    );

    const term = query.trim().toLowerCase();
    const goTo = (term ? GO_TO.filter((e) => matches(e, term)) : GO_TO).slice(0, term ? 8 : 6);
    const createHits = term ? create.filter((e) => matches(e, term)) : create;
    const recordHits: Entry[] = records.hits.map((h) => ({
        id: `rec:${h.doctype}:${h.id}`,
        label: h.label,
        detail: h.doctype,
        path: h.path,
    }));
    const paths = new Map([...goTo, ...createHits, ...recordHits].map((e) => [e.id, e.path]));

    const onAction = (key: Key) => {
        const path = paths.get(String(key));
        if (path === undefined) return;
        onOpenChange(false);
        router.push(orgHref(orgSlug, path));
    };

    return (
        <ModalOverlay isOpen={isOpen} onOpenChange={onOpenChange} isDismissable className="sm:items-start sm:pt-[12vh]">
            <Modal className="max-w-xl overflow-hidden">
                <Dialog aria-label="Command palette" className="flex max-h-[min(32rem,70vh)] flex-col overflow-hidden">
                    <Autocomplete inputValue={query} onInputChange={setQuery}>
                        <SearchField aria-label="Search pages, actions and records" autoFocus className="border-b border-secondary p-3">
                            <InputBase size="md" placeholder="Search pages, actions and records…" icon={SearchLg} />
                        </SearchField>
                        <p aria-live="polite" className="sr-only">
                            {records.status === "loading" ? "Searching records" : records.status === "error" ? "Record search failed" : ""}
                        </p>
                        <Menu
                            aria-label="Results"
                            onAction={onAction}
                            className="min-h-0 flex-1 overflow-y-auto py-1 outline-hidden select-none"
                            renderEmptyState={() => (
                                <p className="px-4 py-6 text-center text-sm text-tertiary">
                                    {records.status === "loading" ? "Searching…" : `No results for “${query.trim()}”`}
                                </p>
                            )}
                        >
                            {goTo.length > 0 && (
                                <MenuSection>
                                    <SectionHeader>Go to</SectionHeader>
                                    {goTo.map((e) => (
                                        <PaletteItem key={e.id} entry={e} />
                                    ))}
                                </MenuSection>
                            )}
                            {createHits.length > 0 && (
                                <MenuSection>
                                    <SectionHeader>Create</SectionHeader>
                                    {createHits.map((e) => (
                                        <PaletteItem key={e.id} entry={e} icon={Plus} />
                                    ))}
                                </MenuSection>
                            )}
                            {recordHits.length > 0 && (
                                <MenuSection>
                                    <SectionHeader>Records</SectionHeader>
                                    {recordHits.map((e) => (
                                        <PaletteItem key={e.id} entry={e} icon={File06} />
                                    ))}
                                </MenuSection>
                            )}
                        </Menu>
                        <div className="flex items-center gap-3 border-t border-secondary px-4 py-2 text-xs text-quaternary">
                            <span>↑↓ to move</span>
                            <span>Enter to open</span>
                            <span>Esc to close</span>
                            <span className="ml-auto">
                                {records.status === "loading" && "Searching records…"}
                                {records.status === "error" && <span className="text-error-primary">Record search failed</span>}
                            </span>
                        </div>
                    </Autocomplete>
                </Dialog>
            </Modal>
        </ModalOverlay>
    );
}

function SectionHeader({ children }: { children: string }) {
    return <Header className="px-4 pt-2 pb-1 text-xs font-semibold text-tertiary">{children}</Header>;
}

function PaletteItem({ entry, icon: Icon }: { entry: Entry; icon?: typeof Plus }) {
    return (
        <MenuItem id={entry.id} textValue={entry.label} className="group block cursor-pointer px-1.5 py-px outline-hidden">
            {({ isFocused, isFocusVisible }) => (
                <div
                    className={cx(
                        "flex items-center gap-2 rounded-md px-2.5 py-2 outline-focus-ring",
                        (isFocused || isFocusVisible) && "bg-primary_hover",
                        isFocusVisible && "outline-2 -outline-offset-2",
                    )}
                >
                    {Icon && <Icon aria-hidden="true" className="size-4 shrink-0 text-fg-quaternary" />}
                    <span className="truncate text-sm font-semibold text-secondary">{entry.label}</span>
                    {entry.detail && <span className="truncate text-sm text-tertiary">{entry.detail}</span>}
                    {entry.badge && (
                        <Badge size="sm" color="gray" className="ml-auto shrink-0">
                            {entry.badge}
                        </Badge>
                    )}
                </div>
            )}
        </MenuItem>
    );
}
