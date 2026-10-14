import type { Metadata } from "next";
import { Suspense } from "react";
import { getCountries, getCurrencies, getRoleProfileTemplates } from "@/lib/queries/reference";
import { SetupWizard } from "./setup-wizard";

export const metadata: Metadata = { title: "Set up your organization" };

async function SetupWizardWithOptions() {
    const [countries, currencies, roleProfiles] = await Promise.all([getCountries(), getCurrencies(), getRoleProfileTemplates()]);
    return <SetupWizard countries={countries} currencies={currencies} roleProfiles={roleProfiles} />;
}

export default function SetupPage() {
    return (
        <main className="flex min-h-dvh flex-col items-center bg-secondary px-4 py-12 sm:justify-center">
            <div className="w-full max-w-xl">
                <p className="mb-6 text-center text-lg font-semibold text-primary">headless-erp</p>
                <div className="rounded-xl bg-primary p-6 shadow-sm ring-1 ring-secondary sm:p-8">
                    <Suspense fallback={<SetupWizardSkeleton />}>
                        <SetupWizardWithOptions />
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

function SetupWizardSkeleton() {
    return (
        <div className="flex flex-col gap-4" aria-hidden="true">
            <div className="h-5 w-48 animate-pulse rounded bg-tertiary" />
            {["name", "slug", "country", "currency", "time-zone"].map((key) => (
                <div key={key} className="flex flex-col gap-1.5">
                    <div className="h-4 w-28 animate-pulse rounded bg-tertiary" />
                    <div className="h-9 animate-pulse rounded-lg bg-secondary" />
                </div>
            ))}
        </div>
    );
}
