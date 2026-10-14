"use client";

import { X as CloseIcon } from "@untitledui/icons";
import { usePathname } from "next/navigation";
import { type ReactNode, useEffect, useState } from "react";
import { Button as AriaButton, Dialog as AriaDialog, Modal as AriaModal, ModalOverlay as AriaModalOverlay } from "react-aria-components";
import { moduleForPath } from "@/config/navigation";
import { useSessionStore } from "@/stores/session";
import { useUiStore } from "@/stores/ui";
import { cx } from "@/utils/cx";
import { orgRelativePath } from "./active";
import { IconRail } from "./icon-rail";
import { ModuleSidebar } from "./module-sidebar";
import { TopBar } from "./top-bar";
import type { ShellCompany, ShellOrg, ShellUser } from "./types";

type AppShellProps = {
    org: ShellOrg;
    orgs: ShellOrg[];
    companies: ShellCompany[];
    companyId: string | null;
    roles: string[];
    user: ShellUser;
    children: ReactNode;
};

/** Icon rail (modules) + module sidebar (ERPNext sidebar sections) + top bar; see docs/architecture/05-ui-ux.md. */
export function AppShell({ org, orgs, companies, companyId, roles, user, children }: AppShellProps) {
    const pathname = usePathname();
    const path = orgRelativePath(pathname, org.slug);
    const module = moduleForPath(path);
    const sidebarCollapsed = useUiStore((s) => s.sidebarCollapsed);
    const hydrate = useSessionStore((s) => s.hydrate);
    const [mobileNavOpen, setMobileNavOpen] = useState(false);

    useEffect(() => {
        useUiStore.persist.rehydrate();
    }, []);

    useEffect(() => {
        hydrate({ orgId: org.id, orgSlug: org.slug, companyId, userRoles: roles });
    }, [hydrate, org.id, org.slug, companyId, roles]);

    // biome-ignore lint/correctness/useExhaustiveDependencies: close the drawer whenever the route changes
    useEffect(() => {
        setMobileNavOpen(false);
    }, [pathname]);

    return (
        <div className="flex h-dvh overflow-hidden bg-primary">
            <div className="flex max-lg:hidden">
                <IconRail org={org} orgs={orgs} activeModule={module?.id} />
                {module && !sidebarCollapsed && (
                    <ModuleSidebar module={module} orgSlug={org.slug} path={path} className="border-r border-secondary" />
                )}
            </div>

            <AriaModalOverlay
                isOpen={mobileNavOpen}
                onOpenChange={setMobileNavOpen}
                isDismissable
                className={({ isEntering, isExiting }) =>
                    cx(
                        "fixed inset-0 z-50 bg-overlay/70 backdrop-blur-md lg:hidden",
                        isEntering && "duration-300 ease-in-out animate-in fade-in",
                        isExiting && "duration-200 ease-in-out animate-out fade-out",
                    )
                }
            >
                <AriaModal className="h-dvh w-fit">
                    <AriaDialog aria-label="Navigation" className="flex h-dvh bg-primary outline-hidden">
                        <IconRail org={org} orgs={orgs} activeModule={module?.id} />
                        {module && <ModuleSidebar module={module} orgSlug={org.slug} path={path} />}
                        <AriaButton
                            aria-label="Close navigation"
                            onPress={() => setMobileNavOpen(false)}
                            className="absolute top-3 right-3 cursor-pointer rounded-lg p-2 text-fg-quaternary hover:bg-primary_hover"
                        >
                            <CloseIcon className="size-5" />
                        </AriaButton>
                    </AriaDialog>
                </AriaModal>
            </AriaModalOverlay>

            <div className="flex min-w-0 flex-1 flex-col">
                <TopBar
                    orgId={org.id}
                    orgSlug={org.slug}
                    companies={companies}
                    companyId={companyId}
                    user={user}
                    onOpenMobileNav={() => setMobileNavOpen(true)}
                />
                <main className="min-h-0 flex-1 overflow-y-auto px-4 py-5 lg:px-8 lg:py-6">{children}</main>
            </div>
        </div>
    );
}
