"use client";

import { useEffect } from "react";
import { useRouter } from "@/lib/next-nav";
import { createClient } from "@/lib/supabase/client";

const STORAGE_KEY = "hx-claims-refresh";

/**
 * Rendered when the JWT's `app.orgs` roles differ from `org_members.roles`: refreshes the session once so the access
 * token hook re-reads the roles, then re-renders the server tree. The signature guard stops a refresh loop when the
 * new token still differs (e.g. the hook is not configured).
 */
export function ClaimsRefresher({ signature }: { signature: string }) {
    const router = useRouter();

    useEffect(() => {
        if (sessionStorage.getItem(STORAGE_KEY) === signature) return;
        sessionStorage.setItem(STORAGE_KEY, signature);
        let active = true;
        createClient()
            .auth.refreshSession()
            .then(({ error }) => {
                if (active && !error) router.refresh();
            });
        return () => {
            active = false;
        };
    }, [signature, router]);

    return null;
}
