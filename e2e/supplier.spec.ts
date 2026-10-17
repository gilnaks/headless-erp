import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a saved supplier is named from the supplier name", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Acme ${stamp}`;
    const { email } = credentials("E2E_SUPPLIER");

    await signIn(page, "E2E_SUPPLIER");
    const org = await createOrganization(page, `Supplier Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Purchase Manager");
    await page.getByRole("option", { name: "Purchase Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/buying/supplier/new`);
    await page.getByRole("textbox", { name: label("Supplier Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/buying/supplier/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(name);
});
