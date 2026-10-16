import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a chart category is listed and a custom category is saved", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Headless Custom ${stamp}`;
    const { email } = credentials("E2E_ACCOUNT_CATEGORY");

    await signIn(page, "E2E_ACCOUNT_CATEGORY");
    const org = await createOrganization(page, `Account Category Org ${stamp}`);

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

    await page.goto(`${org}/accounts/account-category`);
    await page.getByRole("textbox", { name: "Search Account Category" }).fill("Cash and Cash Equivalents");
    await expect(page.getByRole("row", { name: /Cash and Cash Equivalents/ })).toBeVisible();

    await page.goto(`${org}/accounts/account-category/new`);
    await page.getByRole("textbox", { name: label("Account Category") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/account-category/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/accounts/account-category`);
    await page.getByRole("textbox", { name: "Search Account Category" }).fill(name);
    await expect(page.getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
