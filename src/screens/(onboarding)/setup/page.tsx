import { SignOutButton } from "@/components/erp/sign-out-button";
import { getCountries, getCurrencies, getRoleProfileTemplates } from "@/lib/queries/reference";
import { SetupWizard } from "./setup-wizard";

async function SetupWizardWithOptions() {
    const [countries, currencies, roleProfiles] = await Promise.all([getCountries(), getCurrencies(), getRoleProfileTemplates()]);
    return <SetupWizard countries={countries} currencies={currencies} roleProfiles={roleProfiles} />;
}

export default async function SetupPage() {
    const wizard = await SetupWizardWithOptions();
    return (
        <main className="flex min-h-dvh flex-col items-center bg-secondary px-4 py-12 sm:justify-center">
            <div className="w-full max-w-xl">
                <p className="mb-6 text-center text-lg font-semibold text-primary">headless-erp</p>
                <div className="rounded-xl bg-primary p-6 shadow-sm ring-1 ring-secondary sm:p-8">{wizard}</div>
                <div className="mt-4 text-center">
                    <SignOutButton color="tertiary">Sign out</SignOutButton>
                </div>
            </div>
        </main>
    );
}
