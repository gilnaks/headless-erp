"use client";

import { ChevronRight, File04, Folder, Plus } from "@untitledui/icons";
import { parseAsString, useQueryStates } from "nuqs";
import { useMemo, useState } from "react";
import { Button as AriaButton, Collection, type Key, Tree, TreeItem, TreeItemContent } from "react-aria-components";
import { Badge } from "@/components/base/badges/badges";
import { Button } from "@/components/base/buttons/button";
import { NativeSelect } from "@/components/base/select/select-native";
import { Toggle } from "@/components/base/toggle/toggle";
import { ViewToggle } from "@/components/erp/doc/view-toggle";
import { type Doctype, docPath, type FieldValues, type TreeOptions } from "@/doctypes/define";
import { getDoctypeByName } from "@/doctypes/registry";
import { buildTree, childQuery, groupIds, type TreeFilterValues, type TreeNode, visibleRows } from "@/doctypes/tree";
import { type LinkTitles, linkTarget, titleKey } from "@/lib/link-titles";
import { treeParsers } from "@/lib/list-params";
import { cx } from "@/utils/cx";

const NO_FILTERS: string[] = [];

export type TreeViewProps = {
    doctype: string;
    orgSlug: string;
    /** Every node (`listTreeNodes`); filtering and nesting happen here. */
    rows: FieldValues[];
    /** Titles of the filter fields' Link values. */
    titles: LinkTitles;
    canCreate: boolean;
};

/**
 * Generic ERPNext Tree view (`/view/tree`): filters (e.g. Company), "Include disabled", expand/collapse with the arrow
 * keys, Enter opens a node, and "Add child" on groups opens the new form with the parent (and filters) prefilled.
 */
export function TreeView({ doctype, orgSlug, rows, titles, canCreate }: TreeViewProps) {
    const d = getDoctypeByName(doctype) as Doctype;
    const tree = d.tree as TreeOptions;
    const filterFields = tree.filters ?? NO_FILTERS;
    const baseHref = `/${orgSlug}/${docPath(d)}`;

    const parsers = useMemo(
        () => ({ ...treeParsers, ...Object.fromEntries(filterFields.map((f) => [f, parseAsString.withDefault("")])) }),
        [filterFields],
    );
    const [params, setParams] = useQueryStates(parsers);
    const filters = useMemo<TreeFilterValues>(
        () => Object.fromEntries(filterFields.map((f) => [f, String((params as Record<string, unknown>)[f] ?? "")])),
        [filterFields, params],
    );
    const includeDisabled = Boolean(params.disabled);

    const nodes = useMemo(
        () => buildTree(visibleRows(rows, tree, filters, includeDisabled), tree, d.titleField),
        [rows, tree, d.titleField, filters, includeDisabled],
    );
    const [expanded, setExpanded] = useState<Set<Key>>(() => new Set(groupIds(buildTree(rows, tree, d.titleField))));

    const filterOptions = (field: string) => {
        const target = linkTarget(d.fields[field], {});
        const ids = [...new Set(rows.map((r) => r[field]).filter((v): v is string => typeof v === "string" && v !== ""))];
        const options = ids
            .map((id) => ({ value: id, label: (target && titles[titleKey(target, id)]) || id }))
            .sort((a, b) => a.label.localeCompare(b.label));
        return [{ value: "", label: `All ${d.fields[field]?.label ?? field}` }, ...options];
    };

    const renderNode = (node: TreeNode) => (
        <TreeItem
            id={node.id}
            textValue={node.title}
            href={`${baseHref}/${node.id}`}
            className={cx(
                "group/node cursor-pointer rounded-md outline-focus-ring focus-visible:outline-2 focus-visible:-outline-offset-2",
                "hover:bg-primary_hover",
            )}
        >
            <TreeItemContent>
                {({ hasChildItems, isExpanded, level }) => (
                    <div className="flex h-9 items-center gap-2 pr-2" style={{ paddingInlineStart: `${(level - 1) * 1.25 + 0.5}rem` }}>
                        {hasChildItems ? (
                            <AriaButton
                                slot="chevron"
                                aria-label={isExpanded ? `Collapse ${node.title}` : `Expand ${node.title}`}
                                className="flex size-5 shrink-0 cursor-pointer items-center justify-center rounded text-fg-quaternary outline-focus-ring hover:text-fg-quaternary_hover focus-visible:outline-2"
                            >
                                <ChevronRight className={cx("size-4 transition-transform duration-100", isExpanded && "rotate-90")} />
                            </AriaButton>
                        ) : (
                            <span className="size-5 shrink-0" />
                        )}
                        {node.isGroup ? (
                            <Folder className="size-4 shrink-0 text-fg-quaternary" aria-hidden />
                        ) : (
                            <File04 className="size-4 shrink-0 text-fg-quaternary" aria-hidden />
                        )}
                        <span className="min-w-0 flex-1 truncate text-sm font-medium text-primary">{node.title}</span>
                        {tree.disabledField && Boolean(node.row[tree.disabledField]) && (
                            <Badge size="sm" color="gray">
                                Disabled
                            </Badge>
                        )}
                        {canCreate && node.isGroup && (
                            <Button
                                size="sm"
                                color="link-gray"
                                iconLeading={Plus}
                                href={`${baseHref}/new?${childQuery(node, tree, filters)}`}
                                aria-label={`Add child to ${node.title}`}
                                className="opacity-0 group-hover/node:opacity-100 group-focus-within/node:opacity-100 focus-visible:opacity-100"
                            >
                                Add child
                            </Button>
                        )}
                    </div>
                )}
            </TreeItemContent>
            <Collection items={node.children}>{renderNode}</Collection>
        </TreeItem>
    );

    return (
        <div className="flex flex-col gap-4">
            <header className="flex flex-wrap items-center gap-3">
                <h1 className="flex-1 text-lg font-semibold text-primary">{d.doctype} Tree</h1>
                <ViewToggle view="tree" />
                {canCreate && (
                    <Button size="sm" iconLeading={Plus} href={`${baseHref}/new`}>
                        New {d.doctype}
                    </Button>
                )}
            </header>

            <div className="flex flex-wrap items-center gap-4">
                {filterFields.map((field) => (
                    <NativeSelect
                        key={field}
                        aria-label={d.fields[field]?.label ?? field}
                        size="sm"
                        className="w-max"
                        value={filters[field]}
                        onChange={(e) => void setParams({ [field]: e.target.value || null })}
                        options={filterOptions(field)}
                    />
                ))}
                {tree.disabledField && (
                    <Toggle
                        size="sm"
                        label="Include disabled"
                        isSelected={includeDisabled}
                        onChange={(on) => void setParams({ disabled: on || null })}
                    />
                )}
            </div>

            <div className="rounded-xl p-2 ring-1 ring-secondary">
                {nodes.length ? (
                    <Tree
                        aria-label={`${d.doctype} tree`}
                        items={nodes}
                        expandedKeys={expanded}
                        onExpandedChange={setExpanded}
                        className="flex flex-col outline-none"
                    >
                        {renderNode}
                    </Tree>
                ) : (
                    <div className="flex flex-col items-center gap-3 px-4 py-12 text-center">
                        <p className="text-sm font-semibold text-primary">No {d.doctype} yet</p>
                        {canCreate && (
                            <Button size="sm" iconLeading={Plus} href={`${baseHref}/new`}>
                                New {d.doctype}
                            </Button>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
}
