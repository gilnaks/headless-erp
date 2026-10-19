import { expect, type Page, test } from "@playwright/test";
import { companyAbbr } from "../src/lib/schemas/organization";
import { createOrganization, credentials, label, signIn } from "./helpers";

/** Journal Entry is granted to Accounts User, not to the System Manager who owns a new organization. */
async function grantAccountsUser(page: Page, org: string, email: string) {
    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Accounts User");
    await page.getByRole("option", { name: "Accounts User", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
}

async function fillAccount(page: Page, row: number, search: string, option: RegExp) {
    const input = page.locator(`[data-grid="accounts"][data-row="${row}"][data-col="account_id"] input:visible`).first();
    await input.click();
    await input.pressSequentially(search);
    await page.getByRole("option", { name: option }).first().click();
}

test("an opening entry of 100 submits", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Open Org ${stamp}`;
    const abbr = companyAbbr(orgName);
    const { email } = credentials("E2E_OPEN");

    await signIn(page, "E2E_OPEN");
    const org = await createOrganization(page, orgName);
    await grantAccountsUser(page, org, email);

    await page.goto(`${org}/accounts/journal-entry/new`);
    await expect(page.getByRole("heading", { name: "New Journal Entry" })).toBeVisible();
    await page.getByRole("button", { name: /Voucher Type/ }).click();
    await page.getByRole("option", { name: "Opening Entry", exact: true }).click();

    const company = page.getByRole("combobox", { name: label("Company") });
    await company.click();
    await company.pressSequentially(orgName);
    await page
        .getByRole("option", { name: new RegExp(orgName) })
        .first()
        .click();

    await page.getByRole("button", { name: "Add row" }).click();
    await fillAccount(page, 0, "Cash on Hand", new RegExp(`1101 - Cash on Hand - ${abbr}$`));
    await page.locator('[data-grid="accounts"][data-row="0"][data-col="debit"] input:visible').fill("100");
    await page.getByRole("button", { name: "Add row" }).click();
    await fillAccount(page, 1, "3101", new RegExp(`3101 - Capital Stocks - ${abbr}$`));
    await page.locator('[data-grid="accounts"][data-row="1"][data-col="credit"] input:visible').fill("100");

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/journal-entry/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await expect(page.getByText("Not Saved")).toBeHidden();
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });
});
