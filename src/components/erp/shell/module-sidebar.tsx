"use client";

import { ChevronDown } from "@untitledui/icons";
import { Button as AriaButton } from "react-aria-components";
import { NavItemBase } from "@/components/application/app-navigation/base-components/nav-item";
import { type ModuleNav, type NavSection, orgHref } from "@/config/navigation";
import { useUiStore } from "@/stores/ui";
import { cx } from "@/utils/cx";
import { isLinkActive } from "./active";

type ModuleSidebarProps = {
    module: ModuleNav;
    orgSlug: string;
    path: string;
    className?: string;
};

export function ModuleSidebar({ module, orgSlug, path, className }: ModuleSidebarProps) {
    return (
        <nav
            aria-label={`${module.label} navigation`}
            className={cx("flex w-60 shrink-0 flex-col overflow-y-auto bg-primary px-3 py-4", className)}
        >
            <h2 className="px-2 pb-3 text-sm font-semibold text-primary">{module.label}</h2>
            <ul className="flex flex-col">
                {module.items.map((link) => (
                    <li key={link.path + link.label} className="py-px">
                        <NavItemBase type="link" href={orgHref(orgSlug, link.path)} icon={link.icon} current={isLinkActive(link, path)}>
                            {link.label}
                        </NavItemBase>
                    </li>
                ))}
            </ul>
            <div className="mt-3 flex flex-col gap-0.5 border-t border-secondary pt-3">
                {module.sections.map((section) => (
                    <SidebarSection key={section.label} moduleId={module.id} section={section} orgSlug={orgSlug} path={path} />
                ))}
            </div>
        </nav>
    );
}

function SidebarSection({ moduleId, section, orgSlug, path }: { moduleId: string; section: NavSection; orgSlug: string; path: string }) {
    const key = `${moduleId}:${section.label}`;
    const hasActive = section.items.some((link) => isLinkActive(link, path));
    const stored = useUiStore((s) => s.sectionOpen[key]);
    const setSectionOpen = useUiStore((s) => s.setSectionOpen);
    const open = stored ?? hasActive;
    const Icon = section.icon;
    const listId = `nav-section-${moduleId}-${section.label.replace(/\W+/g, "-").toLowerCase()}`;

    return (
        <div>
            <AriaButton
                aria-expanded={open}
                aria-controls={listId}
                onPress={() => setSectionOpen(key, !open)}
                className="group/item flex w-full cursor-pointer items-center rounded-md p-2 outline-focus-ring transition duration-100 ease-linear hover:bg-primary_hover focus-visible:outline-2 focus-visible:outline-offset-2"
            >
                <Icon aria-hidden="true" className="mr-2 size-5 shrink-0 text-fg-quaternary group-hover/item:text-fg-quaternary_hover" />
                <span className="flex-1 text-left text-sm font-semibold text-secondary group-hover/item:text-secondary_hover">
                    {section.label}
                </span>
                <ChevronDown
                    aria-hidden="true"
                    className={cx("size-4 shrink-0 stroke-[2.5px] text-fg-quaternary transition-transform", open && "-scale-y-100")}
                />
            </AriaButton>
            {open && (
                <ul id={listId} className="pb-1">
                    {section.items.map((link) => (
                        <li key={link.path + link.label} className="py-px">
                            <NavItemBase type="collapsible-child" href={orgHref(orgSlug, link.path)} current={isLinkActive(link, path)}>
                                {link.label}
                            </NavItemBase>
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
}
