import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, signIn } from "./helpers";

/** Accounts Settings is written by Accounts Manager, not by the System Manager who owns a new organization. */
async function grantAccountsManager(page: Page, org: string, email: string) {
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
}

test("accounts settings are seeded and a flag stays off after save", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const { email } = credentials("E2E_AS");

    await signIn(page, "E2E_AS");
    const org = await createOrganization(page, `AS Org ${stamp}`);
    await grantAccountsManager(page, org, email);

    await page.goto(`${org}/accounts/settings`);
    const balance = page.getByRole("checkbox", { name: "Show balances in Chart of Accounts" });
    await expect(balance).toBeChecked();
    await balance.click({ force: true });
    await expect(balance).not.toBeChecked();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Saved.")).toBeVisible();

    await page.reload();
    await expect(page.getByRole("checkbox", { name: "Show balances in Chart of Accounts" })).not.toBeChecked();
});
