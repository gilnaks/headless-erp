import { InvitationList, InviteUser } from "@/components/erp/access/invitations";
import { MemberList } from "@/components/erp/access/member-list";
import { NotPermitted } from "@/components/erp/not-permitted";
import { notFound } from "@/lib/navigate";
import { getDocPermissions, getOrgBySlug } from "@/lib/queries/doc";
import { getRoleOptions } from "@/lib/queries/reference";
import { getInvitations, getMemberDirectory, getRoleProfiles } from "@/lib/queries/users";

type UsersPageProps = { params: Promise<{ org: string }> };

/** Bespoke: members live in org_members joined with auth.users, not in a doctype table (00-setup §8). */
async function UsersRoute({ params }: UsersPageProps) {
    const { org: slug } = await params;
    const org = await getOrgBySlug(slug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, "User");
    if (!perms.read) return <NotPermitted action="view" doctype="User" />;

    if (!perms.create) return <MemberList orgSlug={org.slug} members={await getMemberDirectory(org.id)} />;

    const [members, invitations, roles, profiles] = await Promise.all([
        getMemberDirectory(org.id),
        getInvitations(org.id),
        getRoleOptions(org.id),
        getRoleProfiles(org.id),
    ]);
    const roleOptions = roles.map((r) => ({ id: String(r.id), label: r.label ?? String(r.id) }));
    return (
        <div className="flex flex-col gap-8">
            <MemberList
                orgSlug={org.slug}
                members={members}
                actions={<InviteUser orgSlug={org.slug} roleOptions={roleOptions} profiles={profiles} />}
            />
            <InvitationList orgSlug={org.slug} invitations={invitations} />
        </div>
    );
}

export default function UsersPage(props: UsersPageProps) {
    return UsersRoute(props);
}
