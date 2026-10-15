import { useEffect, type ReactNode } from "react";

const STORAGE_KEY = "theme";

function resolvedTheme(): "light" | "dark" {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "light" || stored === "dark") return stored;
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function applyTheme(theme: "light" | "dark") {
    const root = document.documentElement;
    root.classList.remove("light-mode", "dark-mode");
    root.classList.add(theme === "dark" ? "dark-mode" : "light-mode");
    root.style.colorScheme = theme;
}

/** Applies the light or dark class from the saved theme, or the system preference. */
export function Theme({ children }: { children: ReactNode }) {
    useEffect(() => {
        applyTheme(resolvedTheme());
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored === "light" || stored === "dark") return;
        const media = window.matchMedia("(prefers-color-scheme: dark)");
        const onChange = () => applyTheme(resolvedTheme());
        media.addEventListener("change", onChange);
        return () => media.removeEventListener("change", onChange);
    }, []);

    return children;
}
