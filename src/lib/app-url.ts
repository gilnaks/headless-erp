/** Base URL for links in emails. Auth links must match the redirect allow-list. */
export async function appUrl(): Promise<string> {
    const origin = typeof window !== "undefined" ? window.location.origin : process.env.APP_URL;
    return (origin ?? "http://localhost:3000").replace(/\/+$/, "");
}
