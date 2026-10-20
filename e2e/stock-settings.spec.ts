import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, signIn } from "./helpers";

/** Stock Settings is written by Stock Manager, not by the System Manager who owns a new organization. */
async function grantStockManager(page: Page, org: string, email: string) {
    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Stock Manager");
    await page.getByRole("option", { name: "Stock Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
}

test("stock settings keep allow negative stock after save", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const { email } = credentials("E2E_STOCK_SETTINGS");

    await signIn(page, "E2E_STOCK_SETTINGS");
    const org = await createOrganization(page, `SS Org ${stamp}`);
    await grantStockManager(page, org, email);

    await page.getByRole("link", { name: "Stock" }).click();
    const nav = page.getByRole("navigation", { name: "Stock navigation" });
    await nav.getByRole("button", { name: "Setup" }).click();
    await nav.getByRole("link", { name: "Settings" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/settings$`));

    const negative = page.getByRole("checkbox", { name: "Allow negative stock" });
    await expect(negative).not.toBeChecked();
    await negative.click({ force: true });
    await expect(negative).toBeChecked();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Saved.")).toBeVisible();

    await page.reload();
    await expect(page.getByRole("checkbox", { name: "Allow negative stock" })).toBeChecked();
});
