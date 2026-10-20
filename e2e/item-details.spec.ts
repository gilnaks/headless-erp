import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

/** Item Manager creates the item. Stock Manager opens the receipt. */
async function grantStockManager(page: Page, org: string, email: string) {
    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Item Manager");
    await page.getByRole("option", { name: "Item Manager", exact: true }).click();
    await search.fill("");
    await search.pressSequentially("Stock Manager");
    await page.getByRole("option", { name: "Stock Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).evaluate((button: HTMLButtonElement) => button.click());
    await expect(page.getByText("Not Saved")).toBeHidden({ timeout: 20_000 });
}

test("a material receipt fills the target warehouse and the stock UOM from the item", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Item Details Org ${stamp}`;
    const code = `Widget ${stamp}`;
    const { email } = credentials("E2E_ITEM_DETAILS");

    await signIn(page, "E2E_ITEM_DETAILS");
    const org = await createOrganization(page, orgName);
    await grantStockManager(page, org, email);

    await page.goto(`${org}/stock/item/new`);
    await page.getByRole("textbox", { name: label("Item Code") }).fill(code);
    await pick(page, "Item Group", "Products", /^Products/);
    await pick(page, "Default Unit of Measure", "Nos", /^Nos/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/stock/stock-entry/new`);
    await pick(page, "Stock Entry Type", "Material Receipt", /^Material Receipt/);
    await pick(page, "Company", orgName, new RegExp(orgName));
    await page.getByRole("button", { name: "Add row" }).first().click();
    const item = page.locator('[data-grid="items"][data-row="0"][data-col="item_id"] input:visible').first();
    await item.click();
    await item.pressSequentially(code);
    await page
        .getByRole("option", { name: new RegExp(code) })
        .first()
        .click();

    const warehouse = page.locator('[data-grid="items"][data-row="0"][data-col="t_warehouse_id"] input:visible').first();
    const uom = page.locator('[data-grid="items"][data-row="0"][data-col="uom_id"] input:visible').first();
    await expect(warehouse).toHaveValue(/Stores/, { timeout: 15_000 });
    await expect(uom).toHaveValue(/Nos/, { timeout: 15_000 });
});
