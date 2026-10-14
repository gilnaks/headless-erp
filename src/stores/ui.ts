"use client";

import { create } from "zustand";
import { createJSONStorage, devtools, persist } from "zustand/middleware";

type UiState = {
    sidebarCollapsed: boolean;
    /** Explicit open/closed state of module sidebar sections, keyed `<module>:<section>`; unset = open only when it holds the active page. */
    sectionOpen: Record<string, boolean>;
    toggleSidebar: () => void;
    setSectionOpen: (key: string, open: boolean) => void;
};

export const useUiStore = create<UiState>()(
    devtools(
        persist(
            (set) => ({
                sidebarCollapsed: false,
                sectionOpen: {},
                toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed }), false, "ui/toggleSidebar"),
                setSectionOpen: (key, open) => set((s) => ({ sectionOpen: { ...s.sectionOpen, [key]: open } }), false, "ui/setSectionOpen"),
            }),
            {
                name: "hx-ui",
                storage: createJSONStorage(() => localStorage),
                partialize: (s) => ({ sidebarCollapsed: s.sidebarCollapsed, sectionOpen: s.sectionOpen }),
                // Rehydrated in an effect (AppShell) so the server render and the first client render match.
                skipHydration: true,
            },
        ),
        { name: "ui" },
    ),
);
