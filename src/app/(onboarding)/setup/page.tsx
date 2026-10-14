import type { Metadata } from "next";
import { Suspense } from "react";
import { getCountries, getCurrencies } from "@/lib/queries/reference";
import { SetupForm } from "./setup-form";

export const metadata: Metadata = { title: "Create your organization" };

async function SetupFormWithOptions() {
    const [countries, currencies] = await Promise.all([getCountries(), getCurrencies()]);
    return <SetupForm countries={countries} currencies={currencies} />;
}

export default function SetupPage() {
    return (
        <main className="flex min-h-dvh flex-col items-center bg-secondary px-4 py-12 sm:justify-center">
            <div className="w-full max-w-md">
                <p className="mb-6 text-center text-lg font-semibold text-primary">headless-erp</p>
                <div className="rounded-xl bg-primary p-6 shadow-sm ring-1 ring-secondary sm:p-8">
                    <div className="mb-6 flex flex-col gap-1">
                        <h1 className="text-display-xs font-semibold text-primary">Create your organization</h1>
                        <p className="text-sm text-tertiary">
                            An organization holds your companies, users and data. You can add the first company and chart of accounts next.
                        </p>
                    </div>
                    <Suspense fallback={<SetupFormSkeleton />}>
                        <SetupFormWithOptions />
                    </Suspense>
                </div>
                <form action="/auth/signout" method="post" className="mt-4 text-center">
                    <button type="submit" className="cursor-pointer text-sm font-semibold text-tertiary hover:text-secondary">
                        Sign out
                    </button>
                </form>
            </div>
        </main>
    );
}

function SetupFormSkeleton() {
    return (
        <div className="flex flex-col gap-4" aria-hidden="true">
            {["name", "slug", "country", "currency", "time-zone"].map((key) => (
                <div key={key} className="flex flex-col gap-1.5">
                    <div className="h-4 w-28 animate-pulse rounded bg-tertiary" />
                    <div className="h-9 animate-pulse rounded-lg bg-secondary" />
                </div>
            ))}
        </div>
    );
}
