import type { NavLink } from "@/config/navigation";

/** Path below `/[org]` without leading/trailing slashes, e.g. `/acme/accounts/journal-entry/new` → `accounts/journal-entry/new`. */
export function orgRelativePath(pathname: string, orgSlug: string): string {
    const prefix = `/${orgSlug}`;
    const rest =
        pathname === prefix ? "" : pathname.startsWith(`${prefix}/`) ? pathname.slice(prefix.length + 1) : pathname.replace(/^\//, "");
    return rest.replace(/\/+$/, "");
}

/** Doctype links stay active on their `new` / `[id]` sub-pages; homes, dashboards and reports match exactly. */
export function isLinkActive(link: NavLink, path: string): boolean {
    if (link.path === path) return true;
    return link.target.kind === "doctype" && link.path !== "" && path.startsWith(`${link.path}/`);
}
