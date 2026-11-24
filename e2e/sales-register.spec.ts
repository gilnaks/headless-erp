import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

/** A non-stock item needs Item Manager. The customer needs Sales User. The invoice needs Accounts User. */
async function grantSalesRegisterRoles(page: Page, org: string, email: string) {
    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Item Manager");
    await page.getByRole("option", { name: "Item Manager", exact: true }).click();
    await search.fill("");
    await search.pressSequentially("Sales User");
    await page.getByRole("option", { name: "Sales User", exact: true }).click();
    await search.fill("");
    await search.pressSequentially("Accounts User");
    await page.getByRole("option", { name: "Accounts User", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
}

test("the sales register shows a submitted invoice and its total", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Sales Register Org ${stamp}`;
    const code = `Bolt ${stamp}`;
    const customer = `Acme ${stamp}`;
    const { email } = credentials("E2E_SALES_REGISTER");

    await signIn(page, "E2E_SALES_REGISTER");
    const org = await createOrganization(page, orgName);
    await grantSalesRegisterRoles(page, org, email);

    await page.goto(`${org}/stock/item/new`);
    await page.getByRole("textbox", { name: label("Item Code") }).fill(code);
    await pick(page, "Item Group", "Products", /^Products/);
    await pick(page, "Default Unit of Measure", "Nos", /^Nos/);
    await page.getByRole("checkbox", { name: label("Maintain Stock") }).uncheck({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/selling/customer/new`);
    await page.getByRole("textbox", { name: label("Customer Name") }).fill(customer);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/customer/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/accounts/sales-invoice/new`);
    await expect(page.getByRole("heading", { name: "New Sales Invoice" })).toBeVisible();
    await pick(page, "Customer", customer, new RegExp(customer));
    await pick(page, "Company", orgName, new RegExp(orgName));
    await pick(page, "Selling Price List", "Standard Selling", /^Standard Selling/);
    await page.getByRole("button", { name: "Add row" }).first().click();
    const item = page.locator('[data-grid="items"][data-row="0"][data-col="item_id"] input:visible').first();
    await item.click();
    await item.pressSequentially(code);
    await page
        .getByRole("option", { name: new RegExp(code) })
        .first()
        .click();
    await expect(item).toHaveValue(new RegExp(code), { timeout: 15_000 });
    await page.locator('[data-grid="items"][data-row="0"][data-col="qty"] input:visible').fill("2");
    await page.locator('[data-grid="items"][data-row="0"][data-col="rate"] input:visible').fill("10");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/sales-invoice/[0-9a-f-]{36}$`), { timeout: 20_000 });
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });

    await page.goto(`${org}/selling/reports/sales-register`);
    await expect(page.getByRole("heading", { name: "Sales Register" })).toBeVisible();
    const invoice = page.getByRole("row", { name: /ACC-SINV-/ });
    await expect(invoice).toContainText(customer);
    await expect(invoice).toContainText("20.00");
});
