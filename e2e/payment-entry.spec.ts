import { expect, type Page, test } from "@playwright/test";
import { companyAbbr } from "../src/lib/schemas/organization";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

/** Payment Entry is granted to Accounts User, not to the System Manager who owns a new organization. */
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

test("a payment entry submits an internal transfer and cancels", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `PE Org ${stamp}`;
    const abbr = companyAbbr(orgName);
    const { email } = credentials("E2E_PE");

    await signIn(page, "E2E_PE");
    const org = await createOrganization(page, orgName);
    await grantAccountsUser(page, org, email);

    await page.goto(`${org}/accounts/payment-entry/new`);
    await expect(page.getByRole("heading", { name: "New Payment Entry" })).toBeVisible();
    await expect(page.getByText("Draft")).toBeVisible();

    const company = page.getByRole("combobox", { name: label("Company") });
    await company.click();
    await company.pressSequentially(orgName);
    await page
        .getByRole("option", { name: new RegExp(orgName) })
        .first()
        .click();

    await page.getByRole("button", { name: /Payment Type/ }).click();
    await page.getByRole("option", { name: "Internal Transfer" }).click();

    await pick(page, "Paid From", "Cash on Hand", new RegExp(`1101 - Cash on Hand - ${abbr}$`));
    await pick(page, "Paid To", "Cash in Bank", new RegExp(`1201 - Cash in Bank - Checking Account - ${abbr}$`));
    await page.getByRole("textbox", { name: label("Paid Amount") }).fill("100");
    await page.getByRole("textbox", { name: label("Reference No") }).fill("TR-1");
    await page.getByRole("textbox", { name: label("Reference Date") }).fill("2026-10-16");

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/payment-entry/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await expect(page.getByText("Not Saved")).toBeHidden();
    await expect(page.getByRole("button", { name: "Submit" })).toBeVisible();

    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByRole("button", { name: /^Save/ })).toHaveCount(0);

    await page.getByRole("button", { name: "Cancel" }).click();
    await expect(page.getByText("Cancelled", { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByRole("button", { name: /^Save/ })).toHaveCount(0);
});
