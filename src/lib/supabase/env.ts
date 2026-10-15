function readEnv(viteName: string, nextName: string): string | undefined {
    const fromVite = (import.meta.env?.[viteName] ?? import.meta.env?.[nextName]) as string | undefined;
    if (fromVite) return fromVite;
    if (typeof process !== "undefined" && process.env) return process.env[viteName] ?? process.env[nextName];
    return undefined;
}

export function supabaseUrl(): string {
    const url = readEnv("VITE_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_URL");
    if (!url) throw new Error("VITE_SUPABASE_URL is not set");
    return url;
}

export function supabasePublishableKey(): string {
    const key = readEnv("VITE_SUPABASE_PUBLISHABLE_KEY", "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY");
    if (!key) throw new Error("VITE_SUPABASE_PUBLISHABLE_KEY is not set");
    return key;
}
