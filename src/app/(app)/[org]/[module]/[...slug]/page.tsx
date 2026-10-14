import { notFound } from "next/navigation";
import { Suspense } from "react";
import { PlaceholderPage } from "@/components/erp/placeholder-page";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { findLinkForPath, getModule, type NavLink } from "@/config/navigation";

type ItemPageProps = { params: Promise<{ org: string; module: string; slug: string[] }> };

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

async function ItemPlaceholder({ params }: ItemPageProps) {
    const { module: moduleId, slug } = await params;
    if (!getModule(moduleId)) notFound();

    const path = [moduleId, ...slug].join("/");
    const link = findLinkForPath(path);
    if (!link) notFound();

    return <PlaceholderPage title={link.label} description={describe(link, path)} phase={link.phase} />;
}

export default function ItemPage(props: ItemPageProps) {
    return (
        <Suspense fallback={<PageSkeleton />}>
            <ItemPlaceholder {...props} />
        </Suspense>
    );
}
