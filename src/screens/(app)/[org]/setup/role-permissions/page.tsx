import { PermissionMatrix } from "@/components/erp/access/permission-matrix";
import { FormAlert } from "@/components/erp/form-alert";
import { notFound } from "@/lib/navigate";
import { getOrgBySlug } from "@/lib/queries/doc";
import { getRoleOptions } from "@/lib/queries/reference";
import { getMyRoles, getPermissionDoctypes, getRolePermissions } from "@/lib/queries/role-permissions";

type RolePermissionsPageProps = { params: Promise<{ org: string }> };

/** Bespoke: Frappe's permission manager is a page over role_permissions, not a doctype (00-setup §8). */
async function RolePermissionsRoute({ params }: RolePermissionsPageProps) {
    const { org: slug } = await params;
    const org = await getOrgBySlug(slug);
    if (!org) notFound();

    const myRoles = await getMyRoles(org.id);
    if (!myRoles.includes("System Manager")) {
        return <FormAlert>Only a System Manager can manage role permissions.</FormAlert>;
    }

    const [doctypes, roles, rules] = await Promise.all([getPermissionDoctypes(), getRoleOptions(org.id), getRolePermissions(org.id)]);
    return <PermissionMatrix orgSlug={org.slug} doctypes={doctypes} roles={roles.map((r) => String(r.id))} rules={rules} />;
}

export default function RolePermissionsPage(props: RolePermissionsPageProps) {
    return RolePermissionsRoute(props);
}
