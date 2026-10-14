import { expect, type Page } from "@playwright/test";

/** Required labels render a trailing "*". */
export const label = (text: string) => new RegExp(`^${text}\\s*\\*?$`, "i");

export async function pick(page: Page, combobox: string, search: string, option: RegExp) {
    const input = page.getByRole("combobox", { name: label(combobox) });
    await input.click();
    await input.fill("");
    await input.pressSequentially(search);
    await page.getByRole("option", { name: option }).first().click();
}

/** Credentials created by `global-setup.ts` for `prefix` (e.g. `E2E_ACCESS`). */
export function credentials(prefix: string) {
    return { email: process.env[`${prefix}_EMAIL`] ?? "", password: process.env[`${prefix}_PASSWORD`] ?? "" };
}

export async function signIn(page: Page, prefix: string) {
    const { email, password } = credentials(prefix);
    await page.goto("/login");
    await page.getByRole("textbox", { name: label("Email") }).fill(email);
    await page.getByRole("textbox", { name: label("Password") }).fill(password);
    await page.getByRole("button", { name: "Sign in" }).click();
}

/**
 * From `/setup` (a signed-in user without an organization): runs the setup wizard with Philippine defaults and returns
 * the organization path (`/<slug>`). The wizard also creates a first company named like the organization, with the
 * Philippines chart and the current fiscal year.
 */
export async function createOrganization(page: Page, name: string): Promise<string> {
    await expect(page).toHaveURL(/\/setup$/);
    const slug = name.toLowerCase().replaceAll(" ", "-");
    // Retried: a value typed before the form hydrates is lost.
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Organization name") }).fill(name);
        await expect(page.getByRole("textbox", { name: label("URL") })).toHaveValue(slug, { timeout: 1_000 });
    }).toPass();
    await pick(page, "Country", "Philippines", /^Philippines/);
    await pick(page, "Default currency", "PHP", /^PHP/);
    await page.getByRole("button", { name: "Next" }).click();

    await expect(page.getByRole("textbox", { name: label("Company name") })).toHaveValue(name);
    await expect(page.getByRole("combobox", { name: label("Chart of accounts") })).toHaveValue("Philippines", { timeout: 15_000 });
    await page.getByRole("button", { name: "Next" }).click();

    await page.getByRole("button", { name: "Create organization" }).click();
    await expect(page).toHaveURL(new RegExp(`/${slug}$`), { timeout: 30_000 });
    return new URL(page.url()).pathname;
}

/** Creates a company in `org` (path from `createOrganization`) and returns its form URL. */
export async function createCompany(page: Page, org: string, name: string, abbr: string): Promise<string> {
    await page.goto(`${org}/setup/company/new`);
    await page.getByRole("textbox", { name: label("Company") }).fill(name);
    await page.getByRole("textbox", { name: label("Abbr") }).fill(abbr);
    await pick(page, "Default Currency", "PHP", /^PHP/);
    await pick(page, "Country", "Philippines", /^Philippines/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`), { timeout: 15_000 });
    return page.url();
}
