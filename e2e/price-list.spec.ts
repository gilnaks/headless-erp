import { expect, test } from "@playwright/test";
import { createOrganization, signIn } from "./helpers";

test("a company seeds Standard Selling and Standard Buying", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_PRICE_LIST");
    const org = await createOrganization(page, `Price List Org ${stamp}`);

    await page.goto(`${org}/stock/price-list`);
    await page.getByRole("textbox", { name: "Search Price List" }).fill("Standard Selling");
    await expect(page.getByRole("row", { name: /Standard Selling/ })).toBeVisible();

    await page.getByRole("textbox", { name: "Search Price List" }).fill("Standard Buying");
    await expect(page.getByRole("row", { name: /Standard Buying/ })).toBeVisible();
});
