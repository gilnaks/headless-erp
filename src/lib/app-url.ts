import "server-only";
import { headers } from "next/headers";

/** Base URL for links in emails: the request's origin, else `APP_URL`. Auth links must match the redirect allow-list. */
export async function appUrl(): Promise<string> {
    const origin = (await headers()).get("origin");
    return (origin ?? process.env.APP_URL ?? "http://localhost:3000").replace(/\/+$/, "");
}
