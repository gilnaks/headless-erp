import { notFound } from "next/navigation";
import { Suspense } from "react";
import { MemberPanel } from "@/components/erp/access/member-panel";
import { NotPermitted } from "@/components/erp/not-permitted";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { getDocPermissions, getOrgBySlug } from "@/lib/queries/doc";
import { getRoleOptions } from "@/lib/queries/reference";
import { getMemberDirectory, getRoleProfiles } from "@/lib/queries/users";

type MemberPageProps = { params: Promise<{ org: string; userId: string }> };

async function MemberRoute({ params }: MemberPageProps) {
    const { org: slug, userId } = await params;
    const org = await getOrgBySlug(slug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, "User");
    if (!perms.read) return <NotPermitted action="view" doctype="User" />;

    const [members, roles, profiles] = await Promise.all([getMemberDirectory(org.id), getRoleOptions(org.id), getRoleProfiles(org.id)]);
    const member = members.find((m) => m.userId === userId);
    if (!member) notFound();

    return (
        <MemberPanel
            // Server values after a save replace the local edits.
            key={`${member.roleProfile}:${member.roles.join(",")}:${member.status}`}
            orgSlug={org.slug}
            member={member}
            roleOptions={roles.map((r) => ({ id: String(r.id), label: r.label ?? String(r.id) }))}
            profiles={profiles}
            canEdit={perms.write}
        />
    );
}

export default function MemberPage(props: MemberPageProps) {
    return (
        <Suspense fallback={<PageSkeleton />}>
            <MemberRoute {...props} />
        </Suspense>
    );
}
