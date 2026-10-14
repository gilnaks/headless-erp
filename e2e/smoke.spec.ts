import { expect, type Page, test } from "@playwright/test";

/** Required labels render a trailing "*". */
const label = (text: string) => new RegExp(`^${text}\\s*\\*?$`, "i");

async function pick(page: Page, combobox: string, search: string, option: RegExp) {
    const input = page.getByRole("combobox", { name: label(combobox) });
    await input.click();
    await input.fill("");
    await input.pressSequentially(search);
    await page.getByRole("option", { name: option }).first().click();
}

test("sign in, create an organization and a company, see it in the list", async ({ page }) => {
    const email = process.env.E2E_EMAIL ?? "";
    const password = process.env.E2E_PASSWORD ?? "";
    const stamp = Date.now().toString(36);
    const orgName = `Smoke Org ${stamp}`;
    const companyName = `Smoke Company ${stamp}`;

    await page.goto("/login");
    await page.getByRole("textbox", { name: label("Email") }).fill(email);
    await page.getByRole("textbox", { name: label("Password") }).fill(password);
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page).toHaveURL(/\/setup$/);
    await page.getByRole("textbox", { name: label("Organization name") }).fill(orgName);
    await pick(page, "Country", "Philippines", /^Philippines/);
    await pick(page, "Default currency", "PHP", /^PHP/);
    await page.getByRole("button", { name: "Create organization" }).click();

    await expect(page).toHaveURL(new RegExp(`/smoke-org-${stamp}$`));
    const org = new URL(page.url()).pathname;

    await page.goto(`${org}/setup/company`);
    await page.getByRole("link", { name: "New Company" }).first().click();
    await expect(page.getByRole("heading", { name: "New Company" })).toBeVisible();

    await page.getByRole("textbox", { name: label("Company") }).fill(companyName);
    await page.getByRole("textbox", { name: label("Abbr") }).fill(`S${stamp.slice(-3).toUpperCase()}`);
    await pick(page, "Default Currency", "PHP", /^PHP/);
    await pick(page, "Country", "Philippines", /^Philippines/);
    await page.getByRole("button", { name: /^Save/ }).click();

    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`));

    await page.goto(`${org}/setup/company`);
    await expect(page.getByRole("row", { name: new RegExp(companyName) })).toBeVisible();
});
