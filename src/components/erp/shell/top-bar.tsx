"use client";

import { Building07, ChevronSelectorVertical, LayoutLeft, LogOut01, Menu02, Plus, SearchLg, User01 } from "@untitledui/icons";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import type { Key } from "react-aria-components";
import { Button as AriaButton } from "react-aria-components";
import { Avatar } from "@/components/base/avatar/avatar";
import { ButtonUtility } from "@/components/base/buttons/button-utility";
import { Dropdown } from "@/components/base/dropdown/dropdown";
import { orgHref } from "@/config/navigation";
import { useSessionStore } from "@/stores/session";
import { useUiStore } from "@/stores/ui";
import type { ShellCompany, ShellUser } from "./types";

type TopBarProps = {
    orgId: string;
    orgSlug: string;
    companies: ShellCompany[];
    companyId: string | null;
    user: ShellUser;
    onOpenMobileNav: () => void;
};

export function TopBar({ orgId, orgSlug, companies, companyId, user, onOpenMobileNav }: TopBarProps) {
    const toggleSidebar = useUiStore((s) => s.toggleSidebar);

    return (
        <header className="sticky top-0 z-20 flex h-14 shrink-0 items-center gap-3 border-b border-secondary bg-primary px-3 lg:px-4">
            <ButtonUtility className="lg:hidden" size="sm" color="tertiary" icon={Menu02} tooltip="Menu" onPress={onOpenMobileNav} />
            <ButtonUtility
                className="max-lg:hidden"
                size="sm"
                color="tertiary"
                icon={LayoutLeft}
                tooltip="Toggle sidebar"
                onPress={toggleSidebar}
            />
            <CompanySwitcher orgId={orgId} orgSlug={orgSlug} companies={companies} initialCompanyId={companyId} />
            <div className="ml-auto flex items-center gap-3">
                <button
                    type="button"
                    disabled
                    title="Command palette arrives with the first doctypes"
                    className="flex h-9 w-56 cursor-not-allowed items-center gap-2 rounded-lg bg-primary px-3 text-sm text-placeholder shadow-xs ring-1 ring-primary ring-inset max-md:hidden"
                >
                    <SearchLg aria-hidden="true" className="size-4 text-fg-quaternary" />
                    <span className="flex-1 text-left">Search</span>
                    <kbd className="rounded px-1 py-px text-xs font-medium text-quaternary ring-1 ring-secondary ring-inset">⌘K</kbd>
                </button>
                <UserMenu user={user} />
            </div>
        </header>
    );
}

function CompanySwitcher({
    orgId,
    orgSlug,
    companies,
    initialCompanyId,
}: {
    orgId: string;
    orgSlug: string;
    companies: ShellCompany[];
    initialCompanyId: string | null;
}) {
    const router = useRouter();
    const [pending, startTransition] = useTransition();
    const storedCompanyId = useSessionStore((s) => (s.orgId === orgId ? s.companyId : null));
    const companyId = storedCompanyId ?? initialCompanyId;
    const setCompany = useSessionStore((s) => s.setCompany);
    const current = companies.find((c) => c.id === companyId);

    const onAction = (key: Key) => {
        if (key === "new-company") return;
        setCompany(String(key));
        startTransition(() => router.refresh());
    };

    return (
        <Dropdown.Root>
            <AriaButton
                aria-label="Switch company"
                className="flex min-w-0 cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 outline-focus-ring hover:bg-primary_hover focus-visible:outline-2 focus-visible:outline-offset-2 data-pending:opacity-60"
                data-pending={pending || undefined}
            >
                <Building07 aria-hidden="true" className="size-5 shrink-0 text-fg-quaternary" />
                <span className="truncate text-sm font-semibold text-secondary">{current ? current.company_name : "No company yet"}</span>
                {current && <span className="text-xs font-medium text-quaternary">{current.abbr}</span>}
                <ChevronSelectorVertical aria-hidden="true" className="size-4 shrink-0 text-fg-quaternary" />
            </AriaButton>
            <Dropdown.Popover placement="bottom left" className="w-72">
                <Dropdown.Menu
                    aria-label="Companies"
                    selectionMode="single"
                    selectedKeys={companyId ? [companyId] : []}
                    onAction={onAction}
                    disallowEmptySelection
                >
                    <Dropdown.Section>
                        <Dropdown.SectionHeader className="px-4 pt-1.5 pb-1 text-xs font-semibold text-tertiary">
                            Companies
                        </Dropdown.SectionHeader>
                        {companies.map((c) => (
                            <Dropdown.Item key={c.id} id={c.id} label={c.company_name} addon={c.abbr} />
                        ))}
                    </Dropdown.Section>
                    {companies.length > 0 && <Dropdown.Separator />}
                    <Dropdown.Item
                        id="new-company"
                        href={orgHref(orgSlug, "setup/company/new")}
                        icon={Plus}
                        label="New company"
                        selectionIndicator="none"
                    />
                </Dropdown.Menu>
            </Dropdown.Popover>
        </Dropdown.Root>
    );
}

function UserMenu({ user }: { user: ShellUser }) {
    const label = user.name || user.email || "Account";
    const initials = label
        .split(/[\s@.]+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((w) => w[0]?.toUpperCase())
        .join("");

    const signOut = async () => {
        await fetch("/auth/signout", { method: "POST" });
        window.location.assign("/login");
    };

    return (
        <Dropdown.Root>
            <AriaButton
                aria-label="Account menu"
                className="cursor-pointer rounded-full outline-focus-ring focus-visible:outline-2 focus-visible:outline-offset-2"
            >
                <Avatar size="sm" src={user.avatarUrl} initials={initials} alt={label} />
            </AriaButton>
            <Dropdown.Popover placement="bottom right">
                <div className="flex flex-col border-b border-secondary px-4 py-3">
                    <span className="truncate text-sm font-semibold text-primary">{user.name || "Unnamed user"}</span>
                    <span className="truncate text-sm text-tertiary">{user.email}</span>
                </div>
                <Dropdown.Menu aria-label="Account" onAction={(key) => key === "sign-out" && signOut()}>
                    <Dropdown.Item id="profile" icon={User01} label="Profile" isDisabled />
                    <Dropdown.Item id="sign-out" icon={LogOut01} label="Sign out" />
                </Dropdown.Menu>
            </Dropdown.Popover>
        </Dropdown.Root>
    );
}
