import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("Cash is linked to the company and a new mode can be saved", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const orgName = `Mode Org ${stamp}`;
    const name = `Petty ${stamp}`;
    const { email } = credentials("E2E_MODE_OF_PAYMENT");

    await signIn(page, "E2E_MODE_OF_PAYMENT");
    const org = await createOrganization(page, orgName);

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

    await page.goto(`${org}/accounts/mode-of-payment`);
    await page.getByRole("textbox", { name: "Search Mode of Payment" }).fill("Cheque");
    await expect(page.getByRole("row", { name: /Cheque/ })).toBeVisible();
    await page.getByRole("textbox", { name: "Search Mode of Payment" }).fill("Cash");
    await page.getByRole("row", { name: /^Cash/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/mode-of-payment/[0-9a-f-]{36}$`));
    await expect(page.getByRole("combobox", { name: label("Company") })).toHaveValue(new RegExp(orgName));

    await page.goto(`${org}/accounts/mode-of-payment/new`);
    await page.getByRole("textbox", { name: label("Mode of Payment") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/mode-of-payment/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Mode of Payment") })).toHaveValue(name);
});
