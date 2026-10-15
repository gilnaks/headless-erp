import { requireUser } from "@/lib/auth/claims";
import { rolesDiffer } from "@/lib/auth/orgs";
import { notFound } from "@/lib/navigate";
import { createClient } from "@/lib/supabase/client";
import { COMPANY_COOKIE } from "@/stores/session-cookie";

function readCompanyChoice(): string | undefined {
    if (typeof document === "undefined") return undefined;
    const stored = localStorage.getItem(COMPANY_COOKIE);
    if (stored) return stored;
    const prefix = `${COMPANY_COOKIE}=`;
    const item = document.cookie.split("; ").find((part) => part.startsWith(prefix));
    return item ? decodeURIComponent(item.slice(prefix.length)) : undefined;
}

export async function loadOrgShell(slug: string) {
    const claims = await requireUser(`/${slug}`);
    const supabase = await createClient();

    // RLS only returns organizations the user is an active member of, so a foreign slug is a 404.
    const { data: orgs } = await supabase.from("organizations").select("id, slug, name").order("name");
    const org = orgs?.find((o) => o.slug === slug);
    if (!org) notFound();

    const [{ data: companies }, { data: profile }, { data: member }, { data: defaultCompany }] = await Promise.all([
        supabase.from("companies").select("id, company_name, abbr").eq("org_id", org.id).order("company_name"),
        supabase.from("user_profile").select("full_name, avatar_url").eq("user_id", claims.userId).maybeSingle(),
        supabase.from("org_members").select("roles").eq("org_id", org.id).eq("user_id", claims.userId).maybeSingle(),
        supabase
            .from("user_permissions")
            .select("record_id")
            .eq("org_id", org.id)
            .eq("user_id", claims.userId)
            .eq("doctype", "Company")
            .eq("is_default", true)
            .maybeSingle(),
    ]);

    // Chosen company, else the default Company User Permission (Frappe session default), else the first one.
    const cookieCompany = readCompanyChoice();
    const visible = (id: string | undefined) => companies?.find((c) => c.id === id)?.id;
    const companyId = visible(cookieCompany) ?? visible(defaultCompany?.record_id) ?? companies?.[0]?.id ?? null;
    // The token's roles are a snapshot from sign-in; the membership row is current.
    const roles = member?.roles ?? claims.orgs[org.id] ?? [];
    const stale = member ? rolesDiffer(claims.orgs[org.id], member.roles) : false;
    const { data: createPerms } = await supabase
        .from("role_permissions")
        .select("doctype")
        .eq("org_id", org.id)
        .eq("can_create", true)
        .in("role", roles);
    const creatable = [...new Set((createPerms ?? []).map((p) => p.doctype))];

    return {
        org,
        orgs: orgs ?? [],
        companies: companies ?? [],
        companyId,
        roles,
        creatable,
        stale,
        signature: `${org.id}:${[...roles].sort().join(",")}`,
        user: { email: claims.email, name: profile?.full_name ?? null, avatarUrl: profile?.avatar_url ?? null },
    };
}
