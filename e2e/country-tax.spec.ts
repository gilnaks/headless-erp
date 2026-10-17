import { expect, test } from "@playwright/test";
import { createOrganization, signIn } from "./helpers";

test("a Philippines company seeds a sales tax template", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_COUNTRY_TAX");
    const org = await createOrganization(page, `Country Tax Org ${stamp}`);

    await page.goto(`${org}/accounts/sales-taxes-and-charges-template`);
    await page.getByRole("textbox", { name: "Search Sales Taxes and Charges Template" }).fill("Philippines Tax");
    await expect(page.getByRole("row", { name: /^Philippines Tax - / })).toBeVisible();
});
