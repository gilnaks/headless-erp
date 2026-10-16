import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("a stock entry type is seeded and a custom type is saved", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Scrap ${stamp}`;

    await signIn(page, "E2E_STOCK_ENTRY_TYPE");
    const org = await createOrganization(page, `Stock Entry Type Org ${stamp}`);

    await page.goto(`${org}/stock/stock-entry-type`);
    await page.getByRole("textbox", { name: "Search Stock Entry Type" }).fill("Material Issue");
    await expect(page.getByRole("row", { name: /Material Issue/ })).toBeVisible();

    await page.goto(`${org}/stock/stock-entry-type/new`);
    await page.getByRole("textbox", { name: label("Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/stock-entry-type/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/stock/stock-entry-type`);
    await page.getByRole("textbox", { name: "Search Stock Entry Type" }).fill(name);
    await expect(page.getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
