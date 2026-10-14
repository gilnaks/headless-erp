import { notFound } from "next/navigation";
import { Suspense } from "react";
import { DocForm } from "@/components/erp/doc/doc-form";
import { DocList } from "@/components/erp/doc/doc-list";
import { FormAlert } from "@/components/erp/form-alert";
import { PlaceholderPage } from "@/components/erp/placeholder-page";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { findLinkForPath, getModule, type NavLink } from "@/config/navigation";
import type { Doctype } from "@/doctypes/define";
import { getDoctype } from "@/doctypes/registry";
import { loadListParams } from "@/lib/list-params";
import { getDoc, getDocPermissions, getOrgBySlug, listDocs } from "@/lib/queries/doc";

type ItemPageProps = {
    params: Promise<{ org: string; module: string; slug: string[] }>;
    searchParams: Promise<Record<string, string | string[] | undefined>>;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function describe(link: NavLink, path: string): string {
    switch (link.target.kind) {
        case "doctype":
            return path === link.path
                ? `The ${link.target.doctype} list (filters, bulk actions, "+ New") is not built yet.`
                : `The ${link.target.doctype} form is not built yet.`;
        case "report":
            return `The ${link.target.report} report is not built yet.`;
        case "dashboard":
            return "Number cards and charts for this module are not built yet.";
        default:
            return "This page is not built yet.";
    }
}

function NotPermitted({ action, doctype }: { action: string; doctype: string }) {
    return (
        <FormAlert>
            You do not have permission to {action} {doctype}. Ask a System Manager for access.
        </FormAlert>
    );
}

async function ListRoute({ d, orgSlug, searchParams }: { d: Doctype; orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);
    if (!perms.read) return <NotPermitted action="view" doctype={d.doctype} />;

    const { q, sort, desc, page, size } = await loadListParams(searchParams);
    const list = await listDocs(d, org.id, { q, sort: sort ?? undefined, desc, page, pageSize: size });
    return <DocList doctype={d.doctype} orgSlug={org.slug} {...list} canCreate={perms.create} />;
}

async function FormRoute({ d, orgSlug, id }: { d: Doctype; orgSlug: string; id: string | null }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);

    if (id === null) {
        if (!perms.create) return <NotPermitted action="create" doctype={d.doctype} />;
        return <DocForm doctype={d.doctype} orgSlug={org.slug} id={null} row={null} canSave canDelete={false} />;
    }

    const row = await getDoc(d, org.id, id);
    if (!row) notFound();
    return <DocForm doctype={d.doctype} orgSlug={org.slug} id={id} row={row} canSave={perms.write} canDelete={perms.delete} />;
}

async function ItemRoute({ params, searchParams }: ItemPageProps) {
    const { org, module: moduleId, slug } = await params;
    if (!getModule(moduleId)) notFound();

    const d = slug.length <= 2 ? getDoctype(moduleId, slug[0]) : undefined;
    if (d && slug.length === 1) return <ListRoute d={d} orgSlug={org} searchParams={searchParams} />;
    if (d && slug[1] === "new") return <FormRoute d={d} orgSlug={org} id={null} />;
    if (d && UUID.test(slug[1])) return <FormRoute d={d} orgSlug={org} id={slug[1]} />;

    const path = [moduleId, ...slug].join("/");
    const link = findLinkForPath(path);
    if (!link) notFound();

    return <PlaceholderPage title={link.label} description={describe(link, path)} phase={link.phase} />;
}

export default function ItemPage(props: ItemPageProps) {
    return (
        <Suspense fallback={<PageSkeleton />}>
            <ItemRoute {...props} />
        </Suspense>
    );
}
