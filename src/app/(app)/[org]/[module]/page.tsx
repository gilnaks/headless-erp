import { notFound } from "next/navigation";
import { Suspense } from "react";
import { PlaceholderPage } from "@/components/erp/placeholder-page";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { getModule } from "@/config/navigation";

type ModulePageProps = { params: Promise<{ org: string; module: string }> };

async function ModuleHome({ params }: ModulePageProps) {
    const { module: moduleId } = await params;
    const module = getModule(moduleId);
    if (!module) notFound();

    const home = module.items.find((l) => l.target.kind === "workspace" && l.path === module.id);
    return (
        <PlaceholderPage
            title={module.label}
            description={`The ${module.label} home (workspace shortcuts, number cards and charts) is not built yet. Pick an item from the sidebar to see when it lands.`}
            phase={home?.phase}
        />
    );
}

export default function ModulePage(props: ModulePageProps) {
    return (
        <Suspense fallback={<PageSkeleton />}>
            <ModuleHome {...props} />
        </Suspense>
    );
}
