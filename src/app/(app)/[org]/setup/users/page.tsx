import { notFound } from "next/navigation";
import { Suspense } from "react";
import { MemberList } from "@/components/erp/access/member-list";
import { NotPermitted } from "@/components/erp/not-permitted";
import { PageSkeleton } from "@/components/erp/shell/shell-skeleton";
import { getDocPermissions, getOrgBySlug } from "@/lib/queries/doc";
import { getMemberDirectory } from "@/lib/queries/users";

type UsersPageProps = { params: Promise<{ org: string }> };

/** Bespoke: members live in org_members joined with auth.users, not in a doctype table (00-setup §8). */
async function UsersRoute({ params }: UsersPageProps) {
    const { org: slug } = await params;
    const org = await getOrgBySlug(slug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, "User");
    if (!perms.read) return <NotPermitted action="view" doctype="User" />;

    const members = await getMemberDirectory(org.id);
    return <MemberList orgSlug={org.slug} members={members} />;
}

export default function UsersPage(props: UsersPageProps) {
    return (
        <Suspense fallback={<PageSkeleton />}>
            <UsersRoute {...props} />
        </Suspense>
    );
}
