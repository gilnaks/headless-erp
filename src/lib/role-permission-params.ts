import { createLoader, parseAsString } from "nuqs/server";

/** Role Permissions manager filters (`?doctype=&role=`), shared by the server page and the matrix client. */
export const permissionParsers = {
    doctype: parseAsString.withDefault(""),
    role: parseAsString.withDefault(""),
};

export const loadPermissionParams = createLoader(permissionParsers);
