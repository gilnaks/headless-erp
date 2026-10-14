import type { ReactNode } from "react";

export function AuthHeader({ title, children }: { title: string; children?: ReactNode }) {
    return (
        <div className="mb-6 flex flex-col gap-1">
            <h1 className="text-display-xs font-semibold text-primary">{title}</h1>
            {children && <p className="text-sm text-tertiary">{children}</p>}
        </div>
    );
}
