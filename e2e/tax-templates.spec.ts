import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

test("saved tax templates are named from the title and the company", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const orgName = `Tax Org ${stamp}`;
    const { email } = credentials("E2E_TAX_TEMPLATES");

    await signIn(page, "E2E_TAX_TEMPLATES");
    const org = await createOrganization(page, orgName);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Accounts Manager");
    await page.getByRole("option", { name: "Accounts Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/accounts/sales-taxes-and-charges-template/new`);
    await page.getByRole("textbox", { name: label("Title") }).fill("VAT");
    await pick(page, "Company", orgName, new RegExp(orgName));
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/sales-taxes-and-charges-template/[0-9a-f-]{36}$`), {
        timeout: 15_000,
    });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(/^VAT - /);

    await page.goto(`${org}/accounts/purchase-taxes-and-charges-template/new`);
    await page.getByRole("textbox", { name: label("Title") }).fill("GST");
    await pick(page, "Company", orgName, new RegExp(orgName));
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/purchase-taxes-and-charges-template/[0-9a-f-]{36}$`), {
        timeout: 15_000,
    });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(/^GST - /);
});
