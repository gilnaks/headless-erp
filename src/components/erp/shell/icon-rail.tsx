"use client";

import { Check, Plus } from "@untitledui/icons";
import { Button as AriaButton, Link as AriaLink } from "react-aria-components";
import { Dropdown } from "@/components/base/dropdown/dropdown";
import { Tooltip } from "@/components/base/tooltip/tooltip";
import { MODULES, type ModuleId, orgHref } from "@/config/navigation";
import { cx } from "@/utils/cx";
import type { ShellOrg } from "./types";

type IconRailProps = {
    org: ShellOrg;
    orgs: ShellOrg[];
    activeModule: ModuleId | undefined;
};

const mainModules = MODULES.filter((m) => m.id !== "setup");
const setupModule = MODULES.find((m) => m.id === "setup");

function initials(name: string): string {
    return (
        name
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map((w) => w[0]?.toUpperCase())
            .join("") || "?"
    );
}

function RailLink({
    href,
    label,
    icon: Icon,
    current,
}: {
    href: string;
    label: string;
    icon: React.FC<{ className?: string }>;
    current: boolean;
}) {
    return (
        <Tooltip title={label} placement="right">
            <AriaLink
                href={href}
                aria-label={label}
                aria-current={current ? "page" : undefined}
                className={cx(
                    "group/item flex size-10 items-center justify-center rounded-md outline-focus-ring transition duration-100 ease-linear hover:bg-primary_hover focus-visible:outline-2 focus-visible:outline-offset-2",
                    current && "bg-secondary hover:bg-secondary_hover",
                )}
            >
                <Icon
                    aria-hidden="true"
                    className={cx(
                        "size-5 text-fg-quaternary group-hover/item:text-fg-quaternary_hover",
                        current && "text-fg-brand-primary group-hover/item:text-fg-brand-primary",
                    )}
                />
            </AriaLink>
        </Tooltip>
    );
}

export function IconRail({ org, orgs, activeModule }: IconRailProps) {
    return (
        <nav
            aria-label="Modules"
            className="flex h-full w-16 shrink-0 flex-col items-center gap-1 border-r border-secondary bg-primary py-3"
        >
            <Dropdown.Root>
                <Tooltip title={org.name} placement="right">
                    <AriaButton
                        aria-label={`Organization: ${org.name}`}
                        className="mb-3 flex size-9 cursor-pointer items-center justify-center rounded-lg bg-brand-solid text-sm font-semibold text-primary_on-brand outline-focus-ring focus-visible:outline-2 focus-visible:outline-offset-2"
                    >
                        {initials(org.name)}
                    </AriaButton>
                </Tooltip>
                <Dropdown.Popover placement="right top">
                    <Dropdown.Menu aria-label="Switch organization">
                        <Dropdown.Section>
                            <Dropdown.SectionHeader className="px-4 pt-1.5 pb-1 text-xs font-semibold text-tertiary">
                                Organizations
                            </Dropdown.SectionHeader>
                            {orgs.map((o) => (
                                <Dropdown.Item
                                    key={o.id}
                                    id={o.id}
                                    href={orgHref(o.slug, "")}
                                    icon={o.id === org.id ? Check : undefined}
                                    label={o.name}
                                />
                            ))}
                        </Dropdown.Section>
                        <Dropdown.Separator />
                        <Dropdown.Item id="new-org" href="/setup" icon={Plus} label="New organization" />
                    </Dropdown.Menu>
                </Dropdown.Popover>
            </Dropdown.Root>

            <ul className="flex flex-col gap-1">
                {mainModules.map((m) => (
                    <li key={m.id}>
                        <RailLink href={orgHref(org.slug, m.id)} label={m.label} icon={m.icon} current={activeModule === m.id} />
                    </li>
                ))}
            </ul>

            {setupModule && (
                <div className="mt-auto">
                    <RailLink
                        href={orgHref(org.slug, "setup")}
                        label={setupModule.label}
                        icon={setupModule.icon}
                        current={activeModule === "setup"}
                    />
                </div>
            )}
        </nav>
    );
}
