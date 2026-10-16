import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a new brand is saved and listed", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Acme ${stamp}`;
    const { email } = credentials("E2E_BRAND");

    await signIn(page, "E2E_BRAND");
    const org = await createOrganization(page, `Brand Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Item Manager");
    await page.getByRole("option", { name: "Item Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/stock/brand/new`);
    await page.getByRole("textbox", { name: label("Brand") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/brand/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/stock/brand`);
    await page.getByRole("textbox", { name: "Search Brand" }).fill(name);
    await expect(page.getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
