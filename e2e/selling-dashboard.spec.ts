import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

/** Customer create belongs to Sales User, not the System Manager who owns a new organization. */
async function grantSalesUser(page: Page, org: string, email: string) {
    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Sales User");
    await page.getByRole("option", { name: "Sales User", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
}

test("the selling dashboard counts an active customer", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Acme ${stamp}`;
    const { email } = credentials("E2E_SELLING_DASHBOARD");

    await signIn(page, "E2E_SELLING_DASHBOARD");
    const org = await createOrganization(page, `Selling Dashboard Org ${stamp}`);
    await grantSalesUser(page, org, email);

    await page.goto(`${org}/selling/customer/new`);
    await page.getByRole("textbox", { name: label("Customer Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/customer/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/selling/dashboard`);
    await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
    await expect(page.getByRole("region", { name: "Active Customers" }).locator(".tabular-nums")).toHaveText("1");
    await expect(page.getByRole("region", { name: "Sales Order Trends" })).toContainText("not built yet");
});
