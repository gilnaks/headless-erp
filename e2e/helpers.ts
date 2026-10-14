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

/** From `/setup` (a signed-in user without an organization): creates one and returns its path (`/<slug>`). */
export async function createOrganization(page: Page, name: string): Promise<string> {
    await expect(page).toHaveURL(/\/setup$/);
    await page.getByRole("textbox", { name: label("Organization name") }).fill(name);
    await pick(page, "Country", "Philippines", /^Philippines/);
    await pick(page, "Default currency", "PHP", /^PHP/);
    await page.getByRole("button", { name: "Create organization" }).click();
    const slug = name.toLowerCase().replaceAll(" ", "-");
    await expect(page).toHaveURL(new RegExp(`/${slug}$`));
    return new URL(page.url()).pathname;
}
