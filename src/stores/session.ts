"use client";

import { create } from "zustand";
import { devtools } from "zustand/middleware";
import { COMPANY_COOKIE } from "./session-cookie";

type SessionState = {
    orgId: string | null;
    orgSlug: string | null;
    companyId: string | null;
    userRoles: string[];
    /** Called by the org layout with server-loaded values. */
    hydrate: (values: { orgId: string; orgSlug: string; companyId: string | null; userRoles: string[] }) => void;
    setCompany: (companyId: string) => void;
};

function writeCompany(companyId: string) {
    localStorage.setItem(COMPANY_COOKIE, companyId);
    // biome-ignore lint/suspicious/noDocumentCookie: kept so a tab that still reads the cookie stays in sync
    document.cookie = `${COMPANY_COOKIE}=${encodeURIComponent(companyId)}; path=/; max-age=31536000; samesite=lax`;
}

export const useSessionStore = create<SessionState>()(
    devtools(
        (set) => ({
            orgId: null,
            orgSlug: null,
            companyId: null,
            userRoles: [],
            hydrate: (values) => set(values, false, "session/hydrate"),
            setCompany: (companyId) => {
                writeCompany(companyId);
                set({ companyId }, false, "session/setCompany");
            },
        }),
        { name: "session" },
    ),
);
