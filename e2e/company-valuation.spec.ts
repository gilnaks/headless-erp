import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

/** Stock Entry is granted to Stock User, not to the System Manager who owns a new organization. */
async function grantStockUser(page: Page, org: string, email: string) {
    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Item Manager");
    await page.getByRole("option", { name: "Item Manager", exact: true }).click();
    await search.fill("");
    await search.pressSequentially("Stock User");
    await page.getByRole("option", { name: "Stock User", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
}

test("the company form blocks a valuation change after a receipt", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Company Valuation Org ${stamp}`;
    const code = `Bolt ${stamp}`;
    const { email } = credentials("E2E_COMPANY_VALUATION");

    await signIn(page, "E2E_COMPANY_VALUATION");
    const org = await createOrganization(page, orgName);
    await grantStockUser(page, org, email);

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
    await page.locator('[data-grid="items"][data-row="0"][data-col="qty"] input:visible').fill("10");
    await page.locator('[data-grid="items"][data-row="0"][data-col="basic_rate"] input:visible').fill("5");
    const warehouse = page.locator('[data-grid="items"][data-row="0"][data-col="t_warehouse_id"] input:visible').first();
    await expect(warehouse).toHaveValue(/Stores/, { timeout: 15_000 });

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/stock-entry/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await expect(page.getByText("Not Saved")).toBeHidden();
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });

    await page.goto(`${org}/setup/company`);
    await page
        .getByRole("row", { name: new RegExp(`^${orgName}`) })
        .first()
        .click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`));
    await page.getByRole("tab", { name: "Stock" }).click();
    await page.getByRole("button", { name: "Default Stock Valuation Method" }).click();
    await page.getByRole("option", { name: "Moving Average", exact: true }).click();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByRole("alert")).toContainText(
        "Can't change the valuation method, as there are transactions against some items which do not have its own valuation method",
    );
});
