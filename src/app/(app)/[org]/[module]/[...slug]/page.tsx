import { notFound } from "next/navigation";
import { Suspense } from "react";
import { DocForm } from "@/components/erp/doc/doc-form";
import { DocList } from "@/components/erp/doc/doc-list";
import { NotPermitted } from "@/components/erp/not-permitted";
import { PlaceholderPage } from "@/components/erp/placeholder-page";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { findLinkForPath, getModule, type NavLink } from "@/config/navigation";
import type { Doctype } from "@/doctypes/define";
import { getDoctype } from "@/doctypes/registry";
import { prefillValues } from "@/doctypes/schema";
import { loadListParams } from "@/lib/list-params";
import { getDoc, getDocPermissions, getOrgBySlug, getSingleDoc, listDocs } from "@/lib/queries/doc";
import { getListLinkTitles } from "@/lib/queries/links";
import { getReferenceOptions } from "@/lib/queries/reference";
import { optionSourcesOf } from "@/lib/reference-options";

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

async function ListRoute({ d, orgSlug, searchParams }: { d: Doctype; orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);
    if (!perms.read) return <NotPermitted action="view" doctype={d.doctype} />;

    const { q, sort, desc, page, size } = await loadListParams(searchParams);
    const list = await listDocs(d, org.id, { q, sort: sort ?? undefined, desc, page, pageSize: size });
    const titles = await getListLinkTitles(d, org.id, list.rows);
    return <DocList doctype={d.doctype} orgSlug={org.slug} {...list} titles={titles} canCreate={perms.create} />;
}

type FormRouteProps = { d: Doctype; orgSlug: string; id: string | null; searchParams?: ItemPageProps["searchParams"] };

async function FormRoute({ d, orgSlug, id, searchParams }: FormRouteProps) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);

    if (id === null) {
        if (!perms.create) return <NotPermitted action="create" doctype={d.doctype} />;
        const [referenceOptions, prefill] = await Promise.all([
            getReferenceOptions(optionSourcesOf(d), org.id),
            searchParams ? searchParams.then((sp) => prefillValues(d, sp)) : null,
        ]);
        return (
            <DocForm
                doctype={d.doctype}
                orgSlug={org.slug}
                id={null}
                row={prefill}
                canSave
                canDelete={false}
                referenceOptions={referenceOptions}
            />
        );
    }

    const [row, referenceOptions] = await Promise.all([getDoc(d, org.id, id), getReferenceOptions(optionSourcesOf(d), org.id)]);
    if (!row) notFound();
    return (
        <DocForm
            doctype={d.doctype}
            orgSlug={org.slug}
            id={id}
            row={row}
            canSave={perms.write}
            canDelete={perms.delete}
            referenceOptions={referenceOptions}
        />
    );
}

async function SingleRoute({ d, orgSlug }: { d: Doctype; orgSlug: string }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);
    if (!perms.read) return <NotPermitted action="view" doctype={d.doctype} />;

    const [row, referenceOptions] = await Promise.all([getSingleDoc(d, org.id), getReferenceOptions(optionSourcesOf(d), org.id)]);
    if (!row) notFound();
    return (
        <DocForm
            doctype={d.doctype}
            orgSlug={org.slug}
            id={String(row.id)}
            row={row}
            canSave={perms.write}
            canDelete={false}
            referenceOptions={referenceOptions}
        />
    );
}

async function ItemRoute({ params, searchParams }: ItemPageProps) {
    const { org, module: moduleId, slug } = await params;
    if (!getModule(moduleId)) notFound();

    const d = slug.length <= 2 ? getDoctype(moduleId, slug[0]) : undefined;
    if (d?.single) {
        if (slug.length === 1) return <SingleRoute d={d} orgSlug={org} />;
        notFound();
    }
    if (d && slug.length === 1) return <ListRoute d={d} orgSlug={org} searchParams={searchParams} />;
    if (d && slug[1] === "new") return <FormRoute d={d} orgSlug={org} id={null} searchParams={searchParams} />;
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
