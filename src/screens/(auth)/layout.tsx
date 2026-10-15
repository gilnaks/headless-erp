import type { ReactNode } from "react";

export default function AuthLayout({ children }: { children: ReactNode }) {
    return (
        <main className="flex min-h-dvh flex-col items-center bg-secondary px-4 py-12 sm:justify-center">
            <div className="w-full max-w-sm">
                <p className="mb-6 text-center text-lg font-semibold text-primary">headless-erp</p>
                <div className="rounded-xl bg-primary p-6 shadow-sm ring-1 ring-secondary sm:p-8">{children}</div>
            </div>
        </main>
    );
}
