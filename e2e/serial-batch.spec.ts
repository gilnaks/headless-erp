import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

/** Items need Item Manager. Stock Entry and Serial No need Stock Manager. */
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

test("a serialized receipt puts the serial in Stores and an issue takes it back out", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Serial Batch Org ${stamp}`;
    const code = `Bolt ${stamp}`;
    const serial = `SN ${stamp}`;
    const { email } = credentials("E2E_SERIAL_BATCH");

    await signIn(page, "E2E_SERIAL_BATCH");
    const org = await createOrganization(page, orgName);
    await grantStockManager(page, org, email);

    await page.goto(`${org}/stock/item/new`);
    await page.getByRole("textbox", { name: label("Item Code") }).fill(code);
    await pick(page, "Item Group", "Products", /^Products/);
    await pick(page, "Default Unit of Measure", "Nos", /^Nos/);
    await page.getByRole("tab", { name: "Inventory" }).click();
    await page.getByRole("checkbox", { name: "Has Serial No" }).check({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/stock/stock-entry/new`);
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
    await page.locator('[data-grid="items"][data-row="0"][data-col="qty"] input:visible').fill("1");
    await page.locator('[data-grid="items"][data-row="0"][data-col="basic_rate"] input:visible').fill("5");
    await page.locator('[data-grid="items"][data-row="0"][data-col="serial_no"] input:visible').fill(serial);
    const receiptWarehouse = page.locator('[data-grid="items"][data-row="0"][data-col="t_warehouse_id"] input:visible').first();
    await receiptWarehouse.click();
    await receiptWarehouse.pressSequentially("Stores");
    await page
        .getByRole("option", { name: /Stores/ })
        .first()
        .click();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/stock-entry/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });

    await page.goto(`${org}/stock/serial-no`);
    await page.getByRole("row").filter({ hasText: serial }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/serial-no/[0-9a-f-]{36}$`));
    await expect(page.getByRole("combobox", { name: label("Warehouse") })).toHaveValue(/Stores/);
    const serialUrl = page.url();

    await page.goto(`${org}/stock/stock-entry/new`);
    await pick(page, "Stock Entry Type", "Material Issue", /^Material Issue/);
    await pick(page, "Company", orgName, new RegExp(orgName));
    await page.getByRole("button", { name: "Add row" }).first().click();
    const issueItem = page.locator('[data-grid="items"][data-row="0"][data-col="item_id"] input:visible').first();
    await issueItem.click();
    await issueItem.pressSequentially(code);
    await page
        .getByRole("option", { name: new RegExp(code) })
        .first()
        .click();
    await page.locator('[data-grid="items"][data-row="0"][data-col="qty"] input:visible').fill("1");
    const issueWarehouse = page.locator('[data-grid="items"][data-row="0"][data-col="s_warehouse_id"] input:visible').first();
    await issueWarehouse.click();
    await issueWarehouse.pressSequentially("Stores");
    await page
        .getByRole("option", { name: /Stores/ })
        .first()
        .click();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/stock-entry/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });

    await page.goto(serialUrl);
    await expect(page.getByRole("combobox", { name: label("Warehouse") })).toHaveValue("");
});
