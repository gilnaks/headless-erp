import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

/** Stock Reconciliation is granted to Stock Manager, not to the System Manager who owns a new organization. */
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
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
}

test("a stock reconciliation submits and cancels", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Stock Reconciliation Org ${stamp}`;
    const code = `Bolt ${stamp}`;
    const { email } = credentials("E2E_STOCK_RECONCILIATION");

    await signIn(page, "E2E_STOCK_RECONCILIATION");
    const org = await createOrganization(page, orgName);
    await grantStockManager(page, org, email);

    await page.goto(`${org}/stock/item/new`);
    await page.getByRole("textbox", { name: label("Item Code") }).fill(code);
    await pick(page, "Item Group", "Products", /^Products/);
    await pick(page, "Default Unit of Measure", "Nos", /^Nos/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/stock/stock-entry/new`);
    await expect(page.getByRole("heading", { name: "New Stock Entry" })).toBeVisible();
    await pick(page, "Stock Entry Type", "Material Receipt", /^Material Receipt/);
    await pick(page, "Company", orgName, new RegExp(orgName));
    await page.getByRole("button", { name: "Add row" }).first().click();
    const receiptItem = page.locator('[data-grid="items"][data-row="0"][data-col="item_id"] input:visible').first();
    await receiptItem.click();
    await receiptItem.pressSequentially(code);
    await page
        .getByRole("option", { name: new RegExp(code) })
        .first()
        .click();
    await page.locator('[data-grid="items"][data-row="0"][data-col="qty"] input:visible').fill("10");
    await page.locator('[data-grid="items"][data-row="0"][data-col="basic_rate"] input:visible').fill("5");
    const receiptWarehouse = page.locator('[data-grid="items"][data-row="0"][data-col="t_warehouse_id"] input:visible').first();
    await expect(receiptWarehouse).toHaveValue(/Stores/, { timeout: 15_000 });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/stock-entry/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });

    await page.goto(`${org}/stock/stock-reconciliation/new`);
    await expect(page.getByRole("heading", { name: "New Stock Reconciliation" })).toBeVisible();
    await expect(page.getByText("Draft")).toBeVisible();
    await page.getByRole("button", { name: /Select Purpose/ }).click();
    await page.getByRole("option", { name: "Stock Reconciliation", exact: true }).click();
    await pick(page, "Company", orgName, new RegExp(orgName));

    await page.getByRole("button", { name: "Add row" }).click();
    const item = page.locator('[data-grid="items"][data-row="0"][data-col="item_id"] input:visible').first();
    await item.click();
    await item.pressSequentially(code);
    await page
        .getByRole("option", { name: new RegExp(code) })
        .first()
        .click();
    await page.locator('[data-grid="items"][data-row="0"][data-col="qty"] input:visible').fill("12");
    await page.locator('[data-grid="items"][data-row="0"][data-col="valuation_rate"] input:visible').fill("5");
    const warehouse = page.locator('[data-grid="items"][data-row="0"][data-col="warehouse_id"] input:visible').first();
    await warehouse.click();
    await warehouse.pressSequentially("Stores");
    await page
        .getByRole("option", { name: /Stores/ })
        .first()
        .click();

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/stock-reconciliation/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await expect(page.getByText("Not Saved")).toBeHidden();
    await expect(page.getByRole("button", { name: "Submit" })).toBeVisible();

    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByRole("button", { name: /^Save/ })).toHaveCount(0);

    await page.getByRole("button", { name: "Cancel" }).click();
    await expect(page.getByText("Cancelled", { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByRole("button", { name: /^Save/ })).toHaveCount(0);
});
