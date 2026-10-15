import { MemberPanel } from "@/components/erp/access/member-panel";
import { MemberPermissions } from "@/components/erp/access/member-permissions";
import { NotPermitted } from "@/components/erp/not-permitted";
import { notFound } from "@/lib/navigate";
import { getDocPermissions, getOrgBySlug } from "@/lib/queries/doc";
import { getRoleOptions } from "@/lib/queries/reference";
import { getMemberPermissions } from "@/lib/queries/user-permissions";
import { getMemberDirectory, getRoleProfiles } from "@/lib/queries/users";

type MemberPageProps = { params: Promise<{ org: string; userId: string }> };

async function MemberRoute({ params }: MemberPageProps) {
    const { org: slug, userId } = await params;
    const org = await getOrgBySlug(slug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, "User");
    if (!perms.read) return <NotPermitted action="view" doctype="User" />;

    const [members, roles, profiles, permPerms] = await Promise.all([
        getMemberDirectory(org.id),
        getRoleOptions(org.id),
        getRoleProfiles(org.id),
        getDocPermissions(org.id, "User Permission"),
    ]);
    const member = members.find((m) => m.userId === userId);
    if (!member) notFound();
    const permissions = permPerms.read ? await getMemberPermissions(org.id, member.userId) : null;

    return (
        <MemberPanel
            // Server values after a save replace the local edits.
            key={`${member.roleProfile}:${member.roles.join(",")}:${member.status}`}
            orgSlug={org.slug}
            member={member}
            roleOptions={roles.map((r) => ({ id: String(r.id), label: r.label ?? String(r.id) }))}
            profiles={profiles}
            canEdit={perms.write}
        >
            {permissions && (
                <MemberPermissions orgSlug={org.slug} userId={member.userId} permissions={permissions} canEdit={permPerms.create} />
            )}
        </MemberPanel>
    );
}

export default function MemberPage(props: MemberPageProps) {
    return MemberRoute(props);
}
