import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a saved customer is named from the customer name", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Acme ${stamp}`;
    const { email } = credentials("E2E_CUSTOMER");

    await signIn(page, "E2E_CUSTOMER");
    const org = await createOrganization(page, `Customer Org ${stamp}`);

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

    await page.goto(`${org}/selling/customer/new`);
    await page.getByRole("textbox", { name: label("Customer Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/customer/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(name);
});
