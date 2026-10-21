import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

/** Items need Item Manager. A lost reason needs Sales Manager. The quotation itself is Sales User. */
async function grantQuotationRoles(page: Page, org: string, email: string) {
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
    await search.pressSequentially("Sales Manager");
    await page.getByRole("option", { name: "Sales Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
}

test("a quotation submits open and can be marked lost", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Quotation Org ${stamp}`;
    const code = `Bolt ${stamp}`;
    const customer = `Acme ${stamp}`;
    const reason = `Price ${stamp}`;
    const { email } = credentials("E2E_QUOTATION");

    await signIn(page, "E2E_QUOTATION");
    const org = await createOrganization(page, orgName);
    await grantQuotationRoles(page, org, email);

    await page.goto(`${org}/stock/item/new`);
    await page.getByRole("textbox", { name: label("Item Code") }).fill(code);
    await pick(page, "Item Group", "Products", /^Products/);
    await pick(page, "Default Unit of Measure", "Nos", /^Nos/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/selling/customer/new`);
    await page.getByRole("textbox", { name: label("Customer Name") }).fill(customer);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/customer/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/selling/quotation/new`);
    await expect(page.getByRole("heading", { name: "New Quotation" })).toBeVisible();
    await pick(page, "Customer", customer, new RegExp(customer));
    await pick(page, "Company", orgName, new RegExp(orgName));
    await pick(page, "Selling Price List", "Standard Selling", /^Standard Selling/);
    await page.getByRole("button", { name: "Add row" }).click();
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
    await expect(page).toHaveURL(new RegExp(`${org}/selling/quotation/[0-9a-f-]{36}$`), { timeout: 20_000 });
    const quotationUrl = page.url();
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByRole("textbox", { name: label("Status") })).toHaveValue("Open");

    await page.goto(`${org}/selling/quotation-lost-reason/new`);
    await page.getByRole("textbox", { name: label("Quotation Lost Reason") }).fill(reason);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/quotation-lost-reason/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(quotationUrl);
    await expect(page.getByRole("textbox", { name: label("Status") })).toHaveValue("Open");
    await page.getByRole("button", { name: "Actions", exact: true }).click();
    await page.getByRole("menuitem", { name: "Set as Lost" }).click();
    const dialog = page.getByRole("dialog", { name: "Set as Lost" });
    await expect(dialog).toBeVisible();
    const reasonButton = dialog.getByRole("button", { name: /Quotation Lost Reason/ });
    await expect(reasonButton).toBeEnabled({ timeout: 15_000 });
    await reasonButton.click();
    await page.getByRole("option", { name: reason, exact: true }).click();
    await dialog.getByRole("button", { name: "Set as Lost" }).click();
    await expect(page.getByRole("textbox", { name: label("Status") })).toHaveValue("Lost", { timeout: 20_000 });
});
