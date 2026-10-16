import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("a saved category is named from its title", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_TAX_CATEGORY");
    const org = await createOrganization(page, `Tax Org ${stamp}`);

    await page.goto(`${org}/accounts/tax-category/new`);
    await page.getByRole("textbox", { name: label("Title") }).fill("VAT");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/tax-category/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue("VAT");
});
